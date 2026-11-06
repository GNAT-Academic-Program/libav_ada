--  Libav: root of the binding.
--
--  Tiers, from unsafe to safe:
--
--    Libav.Raw       direct imports of libav functions, opaque pointers
--    Libav.Shim      struct fields and macros, via src/c/libav_shim.c
--    Libav.Errors    error codes to exceptions
--    Libav.Rationals time bases
--    Libav.Frames    Frame, a limited controlled wrapper over AVFrame
--    Libav.Decoding  Decoder, opens a file and produces Frames
--    Libav.Scaling   Scaler, converts a Frame to an RGBA buffer
--
--  Application code withs Decoding, Frames and Scaling only.
--  Only the bodies of those three packages with Raw and Shim.

with Interfaces;
with Interfaces.C;

package Libav is

   --  A libav pixel format. Opaque: obtained from a Decoder, consumed by
   --  a Scaler. Never compared or constructed by application code.
   type Pixel_Format is private;

   function Name (Format : Pixel_Format) return String;
   --  libav's own name for the format, for example "yuv420p".

   --  Packed 8-bit RGBA, row-major, no padding between rows.
   --  Length must be Width * Height * 4.
   type RGBA_Buffer is array (Natural range <>) of Interfaces.Unsigned_8
     with Component_Size => 8;

   --  Versions of the libav libraries actually linked, which are not
   --  necessarily those of the headers used at build time.

   type Library is (Avutil, Avcodec, Avformat, Swscale);

   type Version is record
      Major : Natural;
      Minor : Natural;
      Micro : Natural;
   end record;

   function Linked_Version (Of_Library : Library) return Version;
   --  For example Linked_Version (Avcodec).Major >= 61 is FFmpeg 7 or later.

   function Image (V : Version) return String;
   --  "60.31.102"

   function Library_Versions return String;
   --  "avutil 58.29.100, avcodec 60.31.102, ..." for all four libraries.
   --  Print it at startup; a mismatch with the headers used at build time
   --  is the first thing to rule out on a crash.

   Bytes_Per_Pixel : constant := 4;

   subtype Int64 is Interfaces.Integer_64;
   --  libav's int64_t: timestamps, durations, frame counts.

private

   type Pixel_Format is new Interfaces.C.int;

end Libav;
