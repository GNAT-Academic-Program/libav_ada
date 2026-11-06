with Interfaces.C; use Interfaces.C;
with Libav.Shim;

package body Libav.Frames is

   use Raw;
   use type Int64;

   overriding procedure Initialize (F : in out Frame) is
   begin
      F.Ptr := av_frame_alloc;
      if F.Ptr = null then
         raise Storage_Error with "av_frame_alloc returned null";
      end if;
   end Initialize;

   overriding procedure Finalize (F : in out Frame) is
      P : aliased Frame_Ptr := F.Ptr;
   begin
      if P /= null then
         av_frame_free (P'Access);
         F.Ptr := null;
      end if;
   end Finalize;

   function Is_Empty (F : Frame) return Boolean is
     (F.Ptr = null or else Shim.fw_frame_width (F.Ptr) = 0);
   --  av_frame_unref zeroes width/height, which is how libav itself
   --  marks an unreferenced frame.

   function Width (F : Frame) return Natural is
     (if F.Ptr = null then 0 else Natural (Shim.fw_frame_width (F.Ptr)));

   function Height (F : Frame) return Natural is
     (if F.Ptr = null then 0 else Natural (Shim.fw_frame_height (F.Ptr)));

   function Format (F : Frame) return Pixel_Format is
     (Pixel_Format (Shim.fw_frame_format (F.Ptr)));

   function Has_Timestamp (F : Frame) return Boolean is
     (Shim.fw_frame_best_effort_timestamp (F.Ptr) /= Shim.AV_NOPTS_VALUE);

   function Timestamp (F : Frame) return Duration is
   begin
      if not Has_Timestamp (F) then
         return 0.0;
      end if;
      return Rationals.To_Duration
        (Shim.fw_frame_best_effort_timestamp (F.Ptr), F.Time_Base);
   end Timestamp;

   procedure Reset (F : in out Frame) is
   begin
      if F.Ptr /= null then
         av_frame_unref (F.Ptr);
      end if;
   end Reset;

end Libav.Frames;
