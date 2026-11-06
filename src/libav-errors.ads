--  Libav.Errors: libav returns negative ints; this turns them into one
--  exception carrying libav's own message plus what we were doing.

with Interfaces.C;

package Libav.Errors is

   Libav_Error : exception;

   function Message (Code : Interfaces.C.int) return String;
   --  libav's text for an error code, via av_strerror.

   procedure Check (Code : Interfaces.C.int; Doing : String);
   --  Raises Libav_Error with "Doing: message" when Code < 0.
   --  Does nothing otherwise. Use on every libav call whose result is
   --  not itself a value you need to branch on.

end Libav.Errors;
