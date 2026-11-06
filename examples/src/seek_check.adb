--  seek_check FILE
--
--  Exercises the seek paths and checks the results against the rules
--  stated in Libav.Decoding. Exits non-zero on the first broken rule.
--
--    1. Exact seek lands on the first frame with Timestamp >= To,
--       and that frame is less than one frame period after To.
--    2. Keyframe seek (Exact => False) lands at or before To.
--    3. Seeking works after the stream has been decoded to the end.
--    4. Seeking backwards works.
--    5. Seeking past the end leaves the decoder At_End.

with Ada.Command_Line; use Ada.Command_Line;
with Ada.Text_IO;      use Ada.Text_IO;
with Libav.Decoding;   use Libav.Decoding;
with Libav.Frames;     use Libav.Frames;
with Libav.Rationals;  use Libav.Rationals;

procedure Seek_Check is
   D : Decoder;
   F : Frame;
   Failures : Natural := 0;

   procedure Expect (Condition : Boolean; What : String) is
   begin
      if Condition then
         Put_Line ("ok    " & What);
      else
         Put_Line ("FAIL  " & What);
         Failures := Failures + 1;
      end if;
   end Expect;

   Period : Duration;
begin
   if Argument_Count /= 1 then
      Put_Line ("usage: seek_check FILE");
      Set_Exit_Status (Failure);
      return;
   end if;

   Open (D, Argument (1));
   Period := Duration (1.0 / Value (Frame_Rate (D)));
   Put_Line ("length " & Length (D)'Image & " s, period " & Period'Image & " s");

   --  Rule 1, from a fresh decoder, into the middle of a GOP
   declare
      Target : constant Duration := Length (D) / 2 + Period / 3;
   begin
      Seek (D, Target, Exact => True);
      Expect (Next (D, F), "exact seek to middle yields a frame");
      Expect (Timestamp (F) >= Target, "  timestamp >= target");
      Expect (Timestamp (F) < Target + Period, "  timestamp < target + one period");
   end;

   --  Rule 2
   declare
      Target : constant Duration := Length (D) / 2;
   begin
      Seek (D, Target, Exact => False);
      Expect (Next (D, F), "keyframe seek yields a frame");
      Expect (Timestamp (F) <= Target, "  timestamp <= target");
   end;

   --  Rule 3: run to the end first
   declare
      N : Natural := 0;
   begin
      while Next (D, F) loop
         N := N + 1;
      end loop;
      Expect (At_End (D), "decoded to the end, At_End is True");
      Seek (D, 0.0, Exact => True);
      Expect (not At_End (D), "seek after end clears At_End");
      Expect (Next (D, F), "seek to 0.0 after end yields a frame");
      Expect (Timestamp (F) < Period, "  it is the first frame");
   end;

   --  Rule 4: forward then backward, exact both times
   declare
      A : constant Duration := Length (D) * 3 / 4;
      B : constant Duration := Length (D) / 4;
      TA, TB : Duration;
   begin
      Seek (D, A);
      Expect (Next (D, F), "seek to 3/4 yields a frame");
      TA := Timestamp (F);
      Seek (D, B);
      Expect (Next (D, F), "seek back to 1/4 yields a frame");
      TB := Timestamp (F);
      Expect (TB < TA, "  backward seek went backward");
      Expect (TB >= B and TB < B + Period, "  and landed exactly");
   end;

   --  Rule 5
   Seek (D, Length (D) + 10.0, Exact => True);
   Expect (At_End (D), "exact seek past the end leaves At_End");
   Expect (not Next (D, F), "  and Next returns False");
   Expect (Is_Empty (F), "  and the frame is left empty");

   --  Frame hygiene: Next releases the previous picture
   Seek (D, 0.0);
   Expect (Next (D, F), "fresh frame after everything");
   Reset (F);
   Expect (Is_Empty (F), "Reset empties the frame");

   New_Line;
   if Failures = 0 then
      Put_Line ("all checks passed");
   else
      Put_Line (Failures'Image & " check(s) failed");
      Set_Exit_Status (Failure);
   end if;
end Seek_Check;
