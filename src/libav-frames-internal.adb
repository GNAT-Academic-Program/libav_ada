package body Libav.Frames.Internal is

   function Handle (F : Frame) return Raw.Frame_Ptr is (F.Ptr);

   procedure Set_Time_Base (F : in out Frame; Base : Rationals.Rational) is
   begin
      F.Time_Base := Base;
   end Set_Time_Base;

end Libav.Frames.Internal;
