--  Libav.Frames: one decoded picture.
--
--  Frame owns an AVFrame. It is limited, so it cannot be copied, so the
--  AVFrame cannot be freed twice. It is controlled, so the AVFrame is
--  freed when the Frame goes out of scope, exception or not.
--
--  Lifetime rule, which is the whole point of this type:
--
--    A Frame is either Empty or holds exactly one picture. Decoder.Next
--    puts a picture in (releasing whatever was there). Reset takes it out.
--    Nothing else changes what a Frame holds.
--
--  The picture is in the decoder's native pixel format (usually yuv420p).
--  To get RGBA bytes use Libav.Scaling.

private with Ada.Finalization;
private with Libav.Raw;
with Libav.Rationals;

package Libav.Frames is

   type Frame is limited private;

   function Is_Empty (F : Frame) return Boolean;

   function Width  (F : Frame) return Natural
     with Post => (if Is_Empty (F) then Width'Result = 0);
   function Height (F : Frame) return Natural
     with Post => (if Is_Empty (F) then Height'Result = 0);

   function Format (F : Frame) return Pixel_Format
     with Pre => not Is_Empty (F);

   function Timestamp (F : Frame) return Duration
     with Pre => not Is_Empty (F);
   --  Presentation time from the start of the stream, in seconds.
   --  Uses libav's best-effort timestamp, which is what players use.

   function Has_Timestamp (F : Frame) return Boolean
     with Pre => not Is_Empty (F);
   --  False for the rare frame libav could not timestamp. Timestamp then
   --  returns 0.0.

   procedure Reset (F : in out Frame)
     with Post => Is_Empty (F);
   --  Release the picture. Idempotent.

   --  The raw AVFrame pointer is reachable through the child package
   --  Libav.Frames.Internal, for the crate's own Decoding and Scaling
   --  bodies. Application code has no reason to with it.

private

   type Frame is limited new Ada.Finalization.Limited_Controlled with record
      Ptr       : Raw.Frame_Ptr := null;
      Time_Base : Rationals.Rational;
   end record;

   overriding procedure Initialize (F : in out Frame);
   --  av_frame_alloc. Raises Storage_Error if libav is out of memory.

   overriding procedure Finalize (F : in out Frame);
   --  av_frame_free, which also unrefs the picture.

end Libav.Frames;
