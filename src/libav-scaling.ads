--  Libav.Scaling: convert a decoded Frame to packed RGBA bytes, with an
--  optional resize, using libswscale.
--
--  A Scaler is built once for a given (source size, source format,
--  destination size) and reused for every frame. Building one is not
--  free (filter tables), converting with one is fast.
--
--  Usage:
--
--     S : Scaler;
--     Pixels : RGBA_Buffer (0 .. 640 * 360 * 4 - 1);
--  begin
--     Create (S, From => D, Width => 640, Height => 360);
--     while Next (D, F) loop
--        Convert (S, F, Pixels);
--        ... upload Pixels to a texture
--     end loop;

private with Ada.Finalization;
private with Libav.Raw;
with Libav.Decoding;
with Libav.Frames;

package Libav.Scaling is

   type Scaler is limited private;

   type Quality is (Fast, Smooth);
   --  Fast = bilinear, fine for preview. Smooth = bicubic, for export.

   procedure Create
     (S      : in out Scaler;
      From   : Decoding.Decoder;
      Width  : Positive;
      Height : Positive;
      Filter : Quality := Fast)
     with Pre  => Decoding.Is_Open (From),
          Post => Is_Ready (S);
   --  Source size and format are taken from the decoder. Destination is
   --  Width x Height RGBA. Pass the decoder's own Width/Height for a
   --  pure format conversion with no resize.

   function Is_Ready (S : Scaler) return Boolean;

   function Output_Width  (S : Scaler) return Positive with Pre => Is_Ready (S);
   function Output_Height (S : Scaler) return Positive with Pre => Is_Ready (S);

   function Output_Length (S : Scaler) return Positive
     with Pre => Is_Ready (S),
          Post => Output_Length'Result
                  = Output_Width (S) * Output_Height (S) * Bytes_Per_Pixel;
   --  How long the RGBA_Buffer handed to Convert must be.

   procedure Convert
     (S      : in out Scaler;
      Source : Frames.Frame;
      Into   : out RGBA_Buffer)
     with Pre => Is_Ready (S)
                 and then not Frames.Is_Empty (Source)
                 and then Into'Length = Output_Length (S);
   --  Raises Libav.Errors.Libav_Error if Source does not have the size
   --  and format the Scaler was created for (a frame from a different
   --  decoder, or a stream that changed resolution mid-way).

   procedure Release (S : in out Scaler)
     with Post => not Is_Ready (S);
   --  Also done by finalization.

private

   type Scaler is limited new Ada.Finalization.Limited_Controlled with record
      Ctx    : Raw.Sws_Context_Ptr := null;
      Src_W  : Natural := 0;
      Src_H  : Natural := 0;
      Src_F  : Pixel_Format;
      Dst_W  : Natural := 0;
      Dst_H  : Natural := 0;
   end record;

   overriding procedure Finalize (S : in out Scaler);

end Libav.Scaling;
