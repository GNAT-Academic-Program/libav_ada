--  Libav.Shim: imports from src/c/libav_shim.c.
--
--  Struct fields and macro constants. Each entry here is one line of C
--  in the shim, compiled against the installed headers, which is what
--  makes the crate independent of struct layout changes between majors.

with Interfaces.C; use Interfaces.C;
with System;
with Libav.Raw;    use Libav.Raw;

package Libav.Shim is

   ---------------------------------------------------------------------
   --  Constants (macros and enums in C)
   ---------------------------------------------------------------------

   function fw_averror_eof          return int   with Import, Convention => C;
   function fw_averror_eagain       return int   with Import, Convention => C;
   function fw_averror_invaliddata  return int   with Import, Convention => C;
   function fw_av_nopts_value       return Int64 with Import, Convention => C;
   function fw_av_time_base         return int   with Import, Convention => C;
   function fw_avmedia_type_video   return int   with Import, Convention => C;
   function fw_avmedia_type_audio   return int   with Import, Convention => C;
   function fw_pix_fmt_rgba         return int   with Import, Convention => C;
   function fw_pix_fmt_rgb24        return int   with Import, Convention => C;
   function fw_sws_bilinear         return int   with Import, Convention => C;
   function fw_sws_bicubic          return int   with Import, Convention => C;
   function fw_avseek_flag_backward return int   with Import, Convention => C;

   --  Resolved once at elaboration so the rest of the crate reads them
   --  as plain constants.
   AVERROR_EOF          : constant int   := fw_averror_eof;
   AVERROR_EAGAIN       : constant int   := fw_averror_eagain;
   AVERROR_INVALIDDATA  : constant int   := fw_averror_invaliddata;
   AV_NOPTS_VALUE       : constant Int64 := fw_av_nopts_value;
   AV_TIME_BASE         : constant int   := fw_av_time_base;
   AVMEDIA_TYPE_VIDEO   : constant int   := fw_avmedia_type_video;
   AVMEDIA_TYPE_AUDIO   : constant int   := fw_avmedia_type_audio;
   AV_PIX_FMT_RGBA      : constant int   := fw_pix_fmt_rgba;
   AV_PIX_FMT_RGB24     : constant int   := fw_pix_fmt_rgb24;
   SWS_BILINEAR         : constant int   := fw_sws_bilinear;
   SWS_BICUBIC          : constant int   := fw_sws_bicubic;
   AVSEEK_FLAG_BACKWARD : constant int   := fw_avseek_flag_backward;

   ---------------------------------------------------------------------
   --  AVFormatContext
   ---------------------------------------------------------------------

   function fw_format_nb_streams (f : Format_Context_Ptr) return unsigned
     with Import, Convention => C;
   function fw_format_duration (f : Format_Context_Ptr) return Int64
     with Import, Convention => C;
   --  In AV_TIME_BASE units, or AV_NOPTS_VALUE.

   ---------------------------------------------------------------------
   --  AVStream by index
   ---------------------------------------------------------------------

   function fw_stream_codecpar (f : Format_Context_Ptr; i : int) return Codec_Parameters_Ptr
     with Import, Convention => C;
   procedure fw_stream_time_base (f : Format_Context_Ptr; i : int; num, den : out int)
     with Import, Convention => C;
   procedure fw_stream_avg_frame_rate (f : Format_Context_Ptr; i : int; num, den : out int)
     with Import, Convention => C;
   function fw_stream_duration (f : Format_Context_Ptr; i : int) return Int64
     with Import, Convention => C;
   --  In the stream's time base, or AV_NOPTS_VALUE.
   function fw_stream_nb_frames (f : Format_Context_Ptr; i : int) return Int64
     with Import, Convention => C;
   --  0 when the container does not know.

   ---------------------------------------------------------------------
   --  AVCodecContext
   ---------------------------------------------------------------------

   function fw_codec_ctx_width   (c : Codec_Context_Ptr) return int with Import, Convention => C;
   function fw_codec_ctx_height  (c : Codec_Context_Ptr) return int with Import, Convention => C;
   function fw_codec_ctx_pix_fmt (c : Codec_Context_Ptr) return int with Import, Convention => C;
   procedure fw_codec_ctx_set_thread_count (c : Codec_Context_Ptr; n : int)
     with Import, Convention => C;
   --  0 means "let libav pick", usually one thread per core.

   ---------------------------------------------------------------------
   --  AVPacket
   ---------------------------------------------------------------------

   function fw_packet_stream_index (p : Packet_Ptr) return int
     with Import, Convention => C;

   ---------------------------------------------------------------------
   --  AVFrame
   ---------------------------------------------------------------------

   function fw_frame_data (fr : Frame_Ptr) return System.Address
     with Import, Convention => C;
   --  Address of the uint8_t *data[8] array inside the frame.
   function fw_frame_linesize (fr : Frame_Ptr) return System.Address
     with Import, Convention => C;
   --  Address of the int linesize[8] array inside the frame.
   function fw_frame_width  (fr : Frame_Ptr) return int with Import, Convention => C;
   function fw_frame_height (fr : Frame_Ptr) return int with Import, Convention => C;
   function fw_frame_format (fr : Frame_Ptr) return int with Import, Convention => C;
   function fw_frame_pts    (fr : Frame_Ptr) return Int64 with Import, Convention => C;
   function fw_frame_best_effort_timestamp (fr : Frame_Ptr) return Int64
     with Import, Convention => C;

end Libav.Shim;
