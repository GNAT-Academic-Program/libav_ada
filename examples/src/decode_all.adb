--  decode_all FILE [WIDTH HEIGHT]
--
--  Decodes every frame, optionally converting each to RGBA at
--  WIDTH x HEIGHT, and reports frames, wall time and frames per second.
--  Compare the number against Frame_Rate: if decode fps is well above
--  playback fps, real-time playback has headroom.
--
--  Also exercises the end-of-stream drain: the last frames of a file
--  only come out after the decoder is flushed. If the count here is
--  lower than the container's frame count, the drain is broken.

with Ada.Command_Line; use Ada.Command_Line;
with Ada.Real_Time;    use Ada.Real_Time;
with Ada.Text_IO;      use Ada.Text_IO;
with Libav;            use Libav;
with Libav.Decoding;   use Libav.Decoding;
with Libav.Frames;     use Libav.Frames;
with Libav.Scaling;    use Libav.Scaling;

procedure Decode_All is
   D : Decoder;
   F : Frame;
   S : Scaler;
begin
   if Argument_Count /= 1 and Argument_Count /= 3 then
      Put_Line ("usage: decode_all FILE [WIDTH HEIGHT]");
      Set_Exit_Status (Failure);
      return;
   end if;

   Open (D, Argument (1));

   declare
      Scale  : constant Boolean := Argument_Count = 3;
      Out_W  : constant Positive :=
        (if Scale then Positive'Value (Argument (2)) else 1);
      Out_H  : constant Positive :=
        (if Scale then Positive'Value (Argument (3)) else 1);
      Count  : Natural := 0;
      First  : Duration := 0.0;
      Last   : Duration := 0.0;
      T0     : constant Time := Clock;
   begin
      if Scale then
         Create (S, From => D, Width => Out_W, Height => Out_H);
      end if;

      declare
         Pixels : RGBA_Buffer (0 .. (if Scale then Output_Length (S) - 1 else 0));
      begin
         while Next (D, F) loop
            if Count = 0 then
               First := Timestamp (F);
            end if;
            Last := Timestamp (F);
            Count := Count + 1;
            if Scale then
               Convert (S, F, Pixels);
            end if;
         end loop;
      end;

      declare
         Elapsed : constant Duration := To_Duration (Clock - T0);
      begin
         Put_Line ("frames decoded:   " & Count'Image);
         Put_Line ("container says:   " & Frame_Count (D)'Image);
         Put_Line ("first timestamp:  " & First'Image & " s");
         Put_Line ("last timestamp:   " & Last'Image & " s");
         Put_Line ("stream length:    " & Length (D)'Image & " s");
         Put_Line ("wall time:        " & Elapsed'Image & " s");
         if Elapsed > 0.0 then
            Put_Line ("decode rate:      "
                      & Integer (Duration (Count) / Elapsed)'Image & " fps"
                      & (if Scale then " including RGBA conversion" else ""));
         end if;
         Put_Line ("at end:           " & At_End (D)'Image);
      end;
   end;
end Decode_All;
