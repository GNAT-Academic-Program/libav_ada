with Ada.Strings.Fixed;

package body Libav.Rationals is

   function Value (R : Rational) return Long_Float is
     (Long_Float (R.Num) / Long_Float (R.Den));

   function To_Duration (Ticks : Int64; Base : Rational) return Duration is
   begin
      return Duration (Long_Float (Ticks) * Value (Base));
   end To_Duration;

   function To_Ticks (T : Duration; Base : Rational) return Int64 is
      Seconds : constant Long_Float := Long_Float (T);
   begin
      return Int64 (Seconds * Long_Float (Base.Den) / Long_Float (Base.Num));
   end To_Ticks;

   function Image (R : Rational) return String is
      use Ada.Strings.Fixed;
   begin
      return Trim (R.Num'Image, Ada.Strings.Left)
        & "/" & Trim (R.Den'Image, Ada.Strings.Left);
   end Image;

end Libav.Rationals;
