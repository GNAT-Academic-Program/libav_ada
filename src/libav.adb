with Interfaces.C;         use Interfaces.C;
with Interfaces.C.Strings; use Interfaces.C.Strings;
with Ada.Strings.Fixed;
with Libav.Raw;

package body Libav is

   function Name (Format : Pixel_Format) return String is
      P : constant chars_ptr := Raw.av_get_pix_fmt_name (int (Format));
   begin
      if P = Null_Ptr then
         return "unknown(" & Ada.Strings.Fixed.Trim (Format'Image, Ada.Strings.Left) & ")";
      end if;
      return Value (P);
   end Name;

   function Linked_Version (Of_Library : Library) return Version is
      --  libav packs a version as major * 2**16 + minor * 2**8 + micro.
      V : constant unsigned :=
        (case Of_Library is
            when Avutil   => Raw.avutil_version,
            when Avcodec  => Raw.avcodec_version,
            when Avformat => Raw.avformat_version,
            when Swscale  => Raw.swscale_version);
   begin
      return (Major => Natural (V / 2**16),
              Minor => Natural ((V / 2**8) mod 2**8),
              Micro => Natural (V mod 2**8));
   end Linked_Version;

   function Image (V : Version) return String is
      use Ada.Strings.Fixed;
      use Ada.Strings;
   begin
      return Trim (V.Major'Image, Left) & "." & Trim (V.Minor'Image, Left)
        & "." & Trim (V.Micro'Image, Left);
   end Image;

   function Library_Versions return String is
   begin
      return "avutil " & Image (Linked_Version (Avutil))
        & ", avcodec " & Image (Linked_Version (Avcodec))
        & ", avformat " & Image (Linked_Version (Avformat))
        & ", swscale " & Image (Linked_Version (Swscale));
   end Library_Versions;

end Libav;
