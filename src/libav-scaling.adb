with Interfaces.C;
with System;               use System;
with Libav.Errors;         use Libav.Errors;
with Libav.Frames.Internal;
with Libav.Shim;           use Libav.Shim;

package body Libav.Scaling is

   use Interfaces.C;
   use Raw;

   procedure Release (S : in out Scaler) is
   begin
      if S.Ctx /= null then
         sws_freeContext (S.Ctx);
         S.Ctx := null;
      end if;
      S.Src_W := 0;
      S.Src_H := 0;
      S.Dst_W := 0;
      S.Dst_H := 0;
   end Release;

   overriding procedure Finalize (S : in out Scaler) is
   begin
      Release (S);
   end Finalize;

   procedure Create
     (S      : in out Scaler;
      From   : Decoding.Decoder;
      Width  : Positive;
      Height : Positive;
      Filter : Quality := Fast)
   is
      Flags : constant int := (case Filter is
                                 when Fast   => SWS_BILINEAR,
                                 when Smooth => SWS_BICUBIC);
   begin
      Release (S);
      S.Src_W := Decoding.Width (From);
      S.Src_H := Decoding.Height (From);
      S.Src_F := Decoding.Native_Format (From);
      S.Dst_W := Width;
      S.Dst_H := Height;

      S.Ctx := sws_getContext
        (srcW => int (S.Src_W), srcH => int (S.Src_H), srcFormat => int (S.Src_F),
         dstW => int (S.Dst_W), dstH => int (S.Dst_H), dstFormat => AV_PIX_FMT_RGBA,
         flags => Flags,
         srcFilter => Null_Address, dstFilter => Null_Address, param => Null_Address);

      if S.Ctx = null then
         Release (S);
         raise Libav_Error with
           "sws_getContext failed for " & Name (S.Src_F)
           & " " & S.Src_W'Image & "x" & S.Src_H'Image
           & " to rgba " & Width'Image & "x" & Height'Image;
      end if;
   end Create;

   function Is_Ready (S : Scaler) return Boolean is (S.Ctx /= null);
   function Output_Width  (S : Scaler) return Positive is (S.Dst_W);
   function Output_Height (S : Scaler) return Positive is (S.Dst_H);
   function Output_Length (S : Scaler) return Positive is
     (S.Dst_W * S.Dst_H * Bytes_Per_Pixel);

   procedure Convert
     (S      : in out Scaler;
      Source : Frames.Frame;
      Into   : out RGBA_Buffer)
   is
      Src : constant Frame_Ptr := Frames.Internal.Handle (Source);

      --  sws_scale takes plane arrays: up to 8 planes for the source
      --  (yuv420p uses 3), and the same shape for the destination.
      --  Packed RGBA is one plane, so slot 0 is the buffer and the
      --  rest are null. Convention C so the layout is what C expects.
      type Plane_Pointers is array (0 .. 7) of Address with Convention => C;
      type Plane_Strides  is array (0 .. 7) of int     with Convention => C;

      Dst_Planes  : aliased Plane_Pointers :=
        [0 => Into (Into'First)'Address, others => Null_Address];
      Dst_Strides : aliased Plane_Strides :=
        [0 => int (S.Dst_W * Bytes_Per_Pixel), others => 0];

      Rows : int;
   begin
      if Frames.Width (Source) /= S.Src_W
        or else Frames.Height (Source) /= S.Src_H
        or else Frames.Format (Source) /= S.Src_F
      then
         raise Libav_Error with
           "frame is " & Name (Frames.Format (Source))
           & Frames.Width (Source)'Image & "x" & Frames.Height (Source)'Image
           & " but the scaler was created for " & Name (S.Src_F)
           & S.Src_W'Image & "x" & S.Src_H'Image;
      end if;

      Rows := sws_scale
        (c         => S.Ctx,
         srcSlice  => fw_frame_data (Src),
         srcStride => fw_frame_linesize (Src),
         srcSliceY => 0,
         srcSliceH => int (S.Src_H),
         dst       => Dst_Planes'Address,
         dstStride => Dst_Strides'Address);

      Check (Rows, "sws_scale");
      if Natural (Rows) /= S.Dst_H then
         raise Libav_Error with
           "sws_scale produced" & Rows'Image & " rows, expected" & S.Dst_H'Image;
      end if;
   end Convert;

end Libav.Scaling;
