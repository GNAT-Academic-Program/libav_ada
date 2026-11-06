--  dump_frame FILE SECONDS OUT.ppm [WIDTH]
--
--  Seeks to SECONDS (exact), decodes one frame, converts it to RGBA,
--  writes it as a binary PPM (P6). WIDTH scales the output, keeping the
--  aspect ratio; default is the source width.
--
--  This is the preview path of a video editor in 40 lines: seek, one
--  Next, one Convert, bytes to the screen (here, to a file).

with Ada.Command_Line;        use Ada.Command_Line;
with Ada.Streams.Stream_IO;
with Ada.Text_IO;             use Ada.Text_IO;
with Libav;                   use Libav;
with Libav.Decoding;          use Libav.Decoding;
with Libav.Frames;            use Libav.Frames;
with Libav.Scaling;           use Libav.Scaling;

procedure Dump_Frame is
   D : Decoder;
   F : Frame;
   S : Scaler;
begin
   if Argument_Count < 3 then
      Put_Line ("usage: dump_frame FILE SECONDS OUT.ppm [WIDTH]");
      Set_Exit_Status (Failure);
      return;
   end if;

   Open (D, Argument (1));

   declare
      At_Time : constant Duration := Duration'Value (Argument (2));
      Out_W   : constant Positive :=
        (if Argument_Count >= 4 then Positive'Value (Argument (4)) else Width (D));
      Out_H   : constant Positive :=
        Positive'Max (1, (Out_W * Height (D)) / Width (D));
   begin
      Create (S, From => D, Width => Out_W, Height => Out_H, Filter => Smooth);

      Seek (D, At_Time, Exact => True);

      if not Next (D, F) then
         Put_Line ("no frame at " & At_Time'Image & " s (past the end?)");
         Set_Exit_Status (Failure);
         return;
      end if;

      Put_Line ("got frame at " & Timestamp (F)'Image & " s, "
                & Frames.Width (F)'Image & "x" & Frames.Height (F)'Image
                & " " & Name (Format (F)));

      declare
         Pixels : RGBA_Buffer (0 .. Output_Length (S) - 1);
         package SIO renames Ada.Streams.Stream_IO;
         use type Ada.Streams.Stream_Element_Offset;
         Out_File : SIO.File_Type;
         Header   : constant String :=
           "P6" & ASCII.LF & Out_W'Image & Out_H'Image & ASCII.LF & "255" & ASCII.LF;
         Row      : Ada.Streams.Stream_Element_Array (1 .. Ada.Streams.Stream_Element_Offset (Out_W * 3));
      begin
         Convert (S, F, Pixels);

         SIO.Create (Out_File, SIO.Out_File, Argument (3));
         String'Write (SIO.Stream (Out_File), Header);

         --  PPM is RGB, our buffer is RGBA: drop every fourth byte.
         for Y in 0 .. Out_H - 1 loop
            for X in 0 .. Out_W - 1 loop
               declare
                  Src : constant Natural := (Y * Out_W + X) * Bytes_Per_Pixel;
                  Dst : constant Ada.Streams.Stream_Element_Offset :=
                    Ada.Streams.Stream_Element_Offset (X * 3) + 1;
               begin
                  Row (Dst)     := Ada.Streams.Stream_Element (Pixels (Src));
                  Row (Dst + 1) := Ada.Streams.Stream_Element (Pixels (Src + 1));
                  Row (Dst + 2) := Ada.Streams.Stream_Element (Pixels (Src + 2));
               end;
            end loop;
            SIO.Write (Out_File, Row);
         end loop;

         SIO.Close (Out_File);
         Put_Line ("wrote " & Argument (3) & " (" & Out_W'Image & "x" & Out_H'Image & ")");
      end;
   end;
end Dump_Frame;
