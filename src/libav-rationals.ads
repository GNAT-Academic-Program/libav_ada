--  Libav.Rationals: libav expresses time as integer ticks in a rational
--  time base (for example 1/90000 for MPEG-TS, 1/30000 for a 29.97 fps
--  MP4). This package is the only place ticks and seconds meet.
--
--  Rule for the rest of the crate: ticks never leave the Decoding body.
--  Application code sees Duration.

package Libav.Rationals is

   type Rational is record
      Num : Integer := 0;
      Den : Integer := 1;
   end record;

   function Is_Valid (R : Rational) return Boolean is (R.Den /= 0);

   function Value (R : Rational) return Long_Float
     with Pre => Is_Valid (R);
   --  Num / Den as a float. For a frame rate that is frames per second.

   function To_Duration (Ticks : Int64; Base : Rational) return Duration
     with Pre => Is_Valid (Base);
   --  Ticks * Base, in seconds.

   function To_Ticks (T : Duration; Base : Rational) return Int64
     with Pre => Is_Valid (Base) and then Base.Num /= 0;
   --  T / Base, rounded to nearest tick.

   function Image (R : Rational) return String;
   --  "30000/1001"

end Libav.Rationals;
