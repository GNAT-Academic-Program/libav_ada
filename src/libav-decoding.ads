--  Libav.Decoding: open a media file, pull video frames out of it.
--
--  Decoder owns the format context, the codec context, a packet and a
--  working frame. All four are freed by Finalize, so a Decoder going out
--  of scope, on any path, closes the file.
--
--  Usage:
--
--     D : Decoder;
--     F : Frames.Frame;
--  begin
--     Open (D, "clip.mp4");
--     while Next (D, F) loop
--        ... F.Width, F.Height, F.Timestamp, or Scaling.Convert (.., F, ..)
--     end loop;
--
--  Only the first video stream is decoded. Audio is not handled by this
--  crate version.

private with Ada.Finalization;
private with Interfaces.C;
private with Libav.Raw;
with Libav.Frames;
with Libav.Rationals;

package Libav.Decoding is

   type Decoder is limited private;

   procedure Open (D : in out Decoder; File_Name : String)
     with Post => Is_Open (D);
   --  Opens the file, finds the first video stream, opens its decoder.
   --  Raises Libav.Errors.Libav_Error with the reason on any failure
   --  (file not found, no video stream, unsupported codec, ...).
   --  Opening an already open Decoder closes it first.

   procedure Close (D : in out Decoder)
     with Post => not Is_Open (D);
   --  Idempotent. Also done by finalization.

   function Is_Open (D : Decoder) return Boolean;

   ---------------------------------------------------------------------
   --  Stream properties, valid while Is_Open
   ---------------------------------------------------------------------

   function Width  (D : Decoder) return Positive with Pre => Is_Open (D);
   function Height (D : Decoder) return Positive with Pre => Is_Open (D);

   function Native_Format (D : Decoder) return Pixel_Format
     with Pre => Is_Open (D);
   --  What Next produces. Hand it to Scaling.Create.

   function Frame_Rate (D : Decoder) return Rationals.Rational
     with Pre => Is_Open (D);
   --  Average frame rate as the container reports it, for example
   --  30000/1001. Use Rationals.Value for frames per second. Zero
   --  numerator when unknown.

   function Length (D : Decoder) return Duration
     with Pre => Is_Open (D);
   --  Total duration in seconds. 0.0 when the container does not say.

   function Frame_Count (D : Decoder) return Natural
     with Pre => Is_Open (D);
   --  Frames in the stream when the container knows (MP4 does, MKV and
   --  MPEG-TS usually do not, then 0). For a progress bar prefer
   --  Timestamp / Length, which always works.

   ---------------------------------------------------------------------
   --  Decoding
   ---------------------------------------------------------------------

   function Next (D : in out Decoder; Into : in out Frames.Frame) return Boolean
     with Pre => Is_Open (D);
   --  Decodes the next frame into Into (releasing whatever Into held).
   --  Returns False at end of stream, in which case Into is left empty.
   --  Frames come out in presentation order, timestamps increasing.
   --  Raises Libav_Error on a decode error other than end of stream.

   function At_End (D : Decoder) return Boolean
     with Pre => Is_Open (D);
   --  True once Next has returned False. Seek clears it.

   procedure Seek (D : in out Decoder; To : Duration; Exact : Boolean := True)
     with Pre => Is_Open (D);
   --  Positions the decoder so that the next frame from Next is:
   --    Exact = True   the first frame with Timestamp >= To
   --                   (decodes forward from the preceding keyframe,
   --                   costs up to one GOP of decoding, exact).
   --    Exact = False  the keyframe at or before To
   --                   (cheap, what scrubbing wants).
   --  Seeking past the end leaves the decoder At_End.

private

   use type Interfaces.C.int;

   type Decoder is limited new Ada.Finalization.Limited_Controlled with record
      Fmt          : Raw.Format_Context_Ptr := null;
      Codec_Ctx    : Raw.Codec_Context_Ptr  := null;
      Packet       : Raw.Packet_Ptr         := null;
      Work         : Frames.Frame;
      --  The frame avcodec_receive_frame decodes into. Moved to the
      --  caller's frame by Next, so one decode never copies pixels.
      Stream_Index : Interfaces.C.int := -1;
      Time_Base    : Rationals.Rational;
      Rate         : Rationals.Rational;
      W, H         : Natural := 0;
      Fmt_Native   : Pixel_Format;
      Total        : Duration := 0.0;
      N_Frames     : Natural := 0;
      Draining     : Boolean := False;
      --  End of file reached, decoder told to flush its last frames.
      Finished     : Boolean := False;
      --  Flush done, nothing more will come out.
      Pending      : Boolean := False;
      --  Work holds a decoded frame not yet handed out (after an exact
      --  Seek). Next returns it before decoding anything new.
      Opened       : Boolean := False;
   end record;

   overriding procedure Finalize (D : in out Decoder);

end Libav.Decoding;
