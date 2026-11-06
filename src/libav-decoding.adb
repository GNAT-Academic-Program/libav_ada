with Interfaces.C.Strings; use Interfaces.C.Strings;
with Libav.Errors;         use Libav.Errors;
with Libav.Frames.Internal;
with Libav.Shim;           use Libav.Shim;

package body Libav.Decoding is

   use Interfaces.C;
   use Raw;
   use Rationals;
   use type Int64;

   ---------------------------------------------------------------------
   --  Open / Close
   ---------------------------------------------------------------------

   procedure Close (D : in out Decoder) is
   begin
      Frames.Reset (D.Work);

      if D.Packet /= null then
         declare
            P : aliased Packet_Ptr := D.Packet;
         begin
            av_packet_free (P'Access);
            D.Packet := null;
         end;
      end if;

      if D.Codec_Ctx /= null then
         declare
            C : aliased Codec_Context_Ptr := D.Codec_Ctx;
         begin
            avcodec_free_context (C'Access);
            D.Codec_Ctx := null;
         end;
      end if;

      if D.Fmt /= null then
         declare
            F : aliased Format_Context_Ptr := D.Fmt;
         begin
            avformat_close_input (F'Access);
            D.Fmt := null;
         end;
      end if;

      D.Stream_Index := -1;
      D.W := 0;
      D.H := 0;
      D.Total := 0.0;
      D.N_Frames := 0;
      D.Draining := False;
      D.Finished := False;
      D.Pending := False;
      D.Opened := False;
   end Close;

   procedure Open (D : in out Decoder; File_Name : String) is
      Codec    : aliased Codec_Ptr := null;
      Index    : int;
      Num, Den : int;
   begin
      Close (D);

      --  Container
      declare
         C_Name : chars_ptr := New_String (File_Name);
         Fmt    : aliased Format_Context_Ptr := null;
         RC     : int;
      begin
         RC := avformat_open_input (Fmt'Access, C_Name, null, null);
         Free (C_Name);
         Check (RC, "opening " & File_Name);
         D.Fmt := Fmt;
      end;

      Check (avformat_find_stream_info (D.Fmt, null),
             "reading stream info of " & File_Name);

      --  Stream and its decoder
      Index := av_find_best_stream
        (D.Fmt, AVMEDIA_TYPE_VIDEO, -1, -1, Codec'Access, 0);
      Check (Index, "finding a video stream in " & File_Name);
      D.Stream_Index := Index;

      D.Codec_Ctx := avcodec_alloc_context3 (Codec);
      if D.Codec_Ctx = null then
         raise Storage_Error with "avcodec_alloc_context3 returned null";
      end if;

      Check (avcodec_parameters_to_context
               (D.Codec_Ctx, fw_stream_codecpar (D.Fmt, Index)),
             "copying codec parameters");

      fw_codec_ctx_set_thread_count (D.Codec_Ctx, 0);

      Check (avcodec_open2 (D.Codec_Ctx, Codec, null), "opening decoder");

      D.Packet := av_packet_alloc;
      if D.Packet = null then
         raise Storage_Error with "av_packet_alloc returned null";
      end if;

      --  Properties
      fw_stream_time_base (D.Fmt, Index, Num, Den);
      D.Time_Base := (Integer (Num), Integer (Den));
      if not Is_Valid (D.Time_Base) then
         raise Libav_Error with "stream has an invalid time base";
      end if;

      fw_stream_avg_frame_rate (D.Fmt, Index, Num, Den);
      if Den = 0 then
         D.Rate := (0, 1);
      else
         D.Rate := (Integer (Num), Integer (Den));
      end if;

      D.W := Natural (fw_codec_ctx_width (D.Codec_Ctx));
      D.H := Natural (fw_codec_ctx_height (D.Codec_Ctx));
      D.Fmt_Native := Pixel_Format (fw_codec_ctx_pix_fmt (D.Codec_Ctx));
      if D.W = 0 or D.H = 0 then
         raise Libav_Error with "decoder reports a zero-sized picture";
      end if;

      declare
         Container_Ticks : constant Int64 := fw_format_duration (D.Fmt);
         Stream_Ticks    : constant Int64 := fw_stream_duration (D.Fmt, Index);
      begin
         if Container_Ticks /= AV_NOPTS_VALUE and then Container_Ticks > 0 then
            D.Total := To_Duration (Container_Ticks, (1, Integer (AV_TIME_BASE)));
         elsif Stream_Ticks /= AV_NOPTS_VALUE and then Stream_Ticks > 0 then
            D.Total := To_Duration (Stream_Ticks, D.Time_Base);
         else
            D.Total := 0.0;
         end if;
      end;

      declare
         N : constant Int64 := fw_stream_nb_frames (D.Fmt, Index);
      begin
         D.N_Frames := (if N > 0 then Natural (N) else 0);
      end;

      Frames.Internal.Set_Time_Base (D.Work, D.Time_Base);
      D.Opened := True;

   exception
      when others =>
         Close (D);
         raise;
   end Open;

   overriding procedure Finalize (D : in out Decoder) is
   begin
      Close (D);
   end Finalize;

   function Is_Open (D : Decoder) return Boolean is (D.Opened);

   ---------------------------------------------------------------------
   --  Properties
   ---------------------------------------------------------------------

   function Width  (D : Decoder) return Positive is (D.W);
   function Height (D : Decoder) return Positive is (D.H);
   function Native_Format (D : Decoder) return Pixel_Format is (D.Fmt_Native);
   function Frame_Rate (D : Decoder) return Rational is (D.Rate);
   function Length (D : Decoder) return Duration is (D.Total);
   function Frame_Count (D : Decoder) return Natural is (D.N_Frames);
   function At_End (D : Decoder) return Boolean is (D.Finished);

   ---------------------------------------------------------------------
   --  The decode loop
   ---------------------------------------------------------------------

   --  libav's decode API is a pump with two ends: packets go in with
   --  avcodec_send_packet, frames come out with avcodec_receive_frame.
   --  One packet may yield zero, one or several frames. The protocol:
   --
   --    receive  -> 0        a frame came out, take it
   --    receive  -> EAGAIN   the decoder wants more input, send a packet
   --    receive  -> EOF      drained, nothing more will come
   --
   --  At end of file we send a null packet once (draining mode), after
   --  which receive hands out the frames still buffered, then EOF.

   procedure Feed (D : in out Decoder) is
      RC : int;
   begin
      loop
         RC := av_read_frame (D.Fmt, D.Packet);

         if RC < 0 then
            if RC /= AVERROR_EOF then
               Check (RC, "reading packet");
            end if;
            Check (avcodec_send_packet (D.Codec_Ctx, null), "flushing decoder");
            D.Draining := True;
            return;
         end if;

         if fw_packet_stream_index (D.Packet) = D.Stream_Index then
            RC := avcodec_send_packet (D.Codec_Ctx, D.Packet);
            av_packet_unref (D.Packet);
            Check (RC, "sending packet to decoder");
            return;
         end if;

         --  Audio, subtitles, data: not ours. Release and read on.
         av_packet_unref (D.Packet);
      end loop;
   end Feed;

   function Decode_One (D : in out Decoder) return Boolean is
      Work : constant Frame_Ptr := Frames.Internal.Handle (D.Work);
      RC   : int;
   begin
      if D.Finished then
         return False;
      end if;

      loop
         RC := avcodec_receive_frame (D.Codec_Ctx, Work);

         if RC = 0 then
            return True;

         elsif RC = AVERROR_EOF then
            D.Finished := True;
            return False;

         elsif RC = AVERROR_EAGAIN then
            if D.Draining then
               --  Not supposed to happen after a flush; treat as done
               --  rather than spin.
               D.Finished := True;
               return False;
            end if;
            Feed (D);

         else
            Check (RC, "decoding frame");
         end if;
      end loop;
   end Decode_One;

   function Next (D : in out Decoder; Into : in out Frames.Frame) return Boolean is
   begin
      Frames.Reset (Into);

      if D.Pending then
         D.Pending := False;
      elsif not Decode_One (D) then
         return False;
      end if;

      --  Hand the picture over without copying pixels: the buffers move
      --  from Work to Into, Work is left empty.
      av_frame_move_ref (Frames.Internal.Handle (Into),
                         Frames.Internal.Handle (D.Work));
      Frames.Internal.Set_Time_Base (Into, D.Time_Base);
      return True;
   end Next;

   ---------------------------------------------------------------------
   --  Seek
   ---------------------------------------------------------------------

   procedure Seek (D : in out Decoder; To : Duration; Exact : Boolean := True) is
      Ticks : constant Int64 := To_Ticks (To, D.Time_Base);
   begin
      --  Demuxer to the last keyframe at or before To. The decoder's
      --  internal buffers still hold pictures from the old position, so
      --  flush them or they come out first.
      Check (av_seek_frame (D.Fmt, D.Stream_Index, Ticks, AVSEEK_FLAG_BACKWARD),
             "seeking");
      avcodec_flush_buffers (D.Codec_Ctx);
      D.Draining := False;
      D.Finished := False;
      D.Pending := False;
      Frames.Reset (D.Work);

      if not Exact then
         return;
      end if;

      --  Decode forward from the keyframe until we reach To. The frame
      --  that satisfies it is kept in Work and handed out by the next
      --  call to Next.
      loop
         if not Decode_One (D) then
            return;   --  Past the end: At_End is now True.
         end if;
         if not Frames.Has_Timestamp (D.Work)
           or else Frames.Timestamp (D.Work) >= To
         then
            D.Pending := True;
            return;
         end if;
      end loop;
   end Seek;

end Libav.Decoding;
