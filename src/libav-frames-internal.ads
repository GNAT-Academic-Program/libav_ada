--  Libav.Frames.Internal: the raw pointer behind a Frame.
--
--  Used by the bodies of Libav.Decoding and Libav.Scaling only.
--  If application code withs this package, the lifetime guarantees of
--  Frame no longer hold for that code.

with Libav.Raw;
with Libav.Rationals;

package Libav.Frames.Internal is

   function Handle (F : Frame) return Raw.Frame_Ptr;

   procedure Set_Time_Base (F : in out Frame; Base : Rationals.Rational);
   --  The decoder records which time base the picture's timestamps are
   --  in, so Timestamp can convert without asking the decoder.

end Libav.Frames.Internal;
