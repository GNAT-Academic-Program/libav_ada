--  probe FILE
--
--  Prints what the decoder knows about the first video stream.
--  Week-one check: if this runs on your machine, the crate is linked
--  against a working libav.

with Ada.Command_Line; use Ada.Command_Line;
with Ada.Text_IO;      use Ada.Text_IO;
with Libav;
with Libav.Decoding;   use Libav.Decoding;
with Libav.Rationals;  use Libav.Rationals;

procedure Probe is
   D : Decoder;
begin
   if Argument_Count /= 1 then
      Put_Line ("usage: probe FILE");
      Set_Exit_Status (Failure);
      return;
   end if;

   Put_Line ("libraries: " & Libav.Library_Versions);

   Open (D, Argument (1));

   Put_Line ("file:        " & Argument (1));
   Put_Line ("size:        " & Width (D)'Image & " x" & Height (D)'Image);
   Put_Line ("format:      " & Libav.Name (Native_Format (D)));
   Put_Line ("frame rate:  " & Image (Frame_Rate (D))
             & " (" & Value (Frame_Rate (D))'Image & " fps)");
   Put_Line ("length:      " & Length (D)'Image & " s");
   Put_Line ("frame count: " & Frame_Count (D)'Image
             & (if Frame_Count (D) = 0 then " (container does not say)" else ""));
end Probe;
