with Interfaces.C;         use Interfaces.C;
with Interfaces.C.Strings; use Interfaces.C.Strings;
with Libav.Raw;

package body Libav.Errors is

   function Message (Code : int) return String is
      Buf : chars_ptr := New_String ([1 .. 128 => ' ']);
      R   : int;
   begin
      R := Raw.av_strerror (Code, Buf, 128);
      if R < 0 then
         Free (Buf);
         return "libav error" & Code'Image;
      end if;
      declare
         S : constant String := Value (Buf);
      begin
         Free (Buf);
         return S;
      end;
   end Message;

   procedure Check (Code : int; Doing : String) is
   begin
      if Code < 0 then
         raise Libav_Error with Doing & ": " & Message (Code);
      end if;
   end Check;

end Libav.Errors;
