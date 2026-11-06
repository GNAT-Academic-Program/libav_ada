/*
 * libav_shim.c
 *
 * The only C in the crate. It exists for two reasons a binding cannot solve:
 *
 *   1. Struct field access. libav public structs change layout at every
 *      major release (for example AVFrame lost key_frame in 7.0, which
 *      shifts every field after it). Reading a field here means the
 *      offset is resolved by the C compiler against the headers actually
 *      installed, not frozen into an Ada record.
 *
 *   2. Macros. AVERROR(EAGAIN), AVERROR_EOF, AV_NOPTS_VALUE, AV_TIME_BASE
 *      and the enum constants are preprocessor or enum values with no
 *      symbol to import.
 *
 * Rule: no logic in this file. Every function is a field read, a field
 * write, or a constant. Logic lives in Ada.
 */

#include <errno.h>
#include <stdint.h>

#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/avutil.h>
#include <libavutil/frame.h>
#include <libavutil/pixfmt.h>
#include <libswscale/swscale.h>

/* ---- Constants ------------------------------------------------------- */

int     fw_averror_eof (void)          { return AVERROR_EOF; }
int     fw_averror_eagain (void)       { return AVERROR (EAGAIN); }
int     fw_averror_invaliddata (void)  { return AVERROR_INVALIDDATA; }
int64_t fw_av_nopts_value (void)       { return AV_NOPTS_VALUE; }
int     fw_av_time_base (void)         { return AV_TIME_BASE; }
int     fw_avmedia_type_video (void)   { return AVMEDIA_TYPE_VIDEO; }
int     fw_avmedia_type_audio (void)   { return AVMEDIA_TYPE_AUDIO; }
int     fw_pix_fmt_rgba (void)         { return AV_PIX_FMT_RGBA; }
int     fw_pix_fmt_rgb24 (void)        { return AV_PIX_FMT_RGB24; }
int     fw_sws_bilinear (void)         { return SWS_BILINEAR; }
int     fw_sws_bicubic (void)          { return SWS_BICUBIC; }
int     fw_avseek_flag_backward (void) { return AVSEEK_FLAG_BACKWARD; }

/* ---- AVFormatContext ------------------------------------------------- */

unsigned fw_format_nb_streams (const AVFormatContext *f) { return f->nb_streams; }
int64_t  fw_format_duration   (const AVFormatContext *f) { return f->duration; }

/* ---- AVStream, addressed by index ------------------------------------ */

AVCodecParameters *fw_stream_codecpar (const AVFormatContext *f, int i)
{
   return f->streams[i]->codecpar;
}

void fw_stream_time_base (const AVFormatContext *f, int i, int *num, int *den)
{
   *num = f->streams[i]->time_base.num;
   *den = f->streams[i]->time_base.den;
}

void fw_stream_avg_frame_rate (const AVFormatContext *f, int i, int *num, int *den)
{
   *num = f->streams[i]->avg_frame_rate.num;
   *den = f->streams[i]->avg_frame_rate.den;
}

int64_t fw_stream_duration  (const AVFormatContext *f, int i) { return f->streams[i]->duration; }
int64_t fw_stream_nb_frames (const AVFormatContext *f, int i) { return f->streams[i]->nb_frames; }

/* ---- AVCodecContext -------------------------------------------------- */

int  fw_codec_ctx_width   (const AVCodecContext *c) { return c->width; }
int  fw_codec_ctx_height  (const AVCodecContext *c) { return c->height; }
int  fw_codec_ctx_pix_fmt (const AVCodecContext *c) { return c->pix_fmt; }
void fw_codec_ctx_set_thread_count (AVCodecContext *c, int n) { c->thread_count = n; }

/* ---- AVPacket -------------------------------------------------------- */

int fw_packet_stream_index (const AVPacket *p) { return p->stream_index; }

/* ---- AVFrame --------------------------------------------------------- */

uint8_t **fw_frame_data     (AVFrame *fr) { return fr->data; }
int      *fw_frame_linesize (AVFrame *fr) { return fr->linesize; }
int       fw_frame_width    (const AVFrame *fr) { return fr->width; }
int       fw_frame_height   (const AVFrame *fr) { return fr->height; }
int       fw_frame_format   (const AVFrame *fr) { return fr->format; }
int64_t   fw_frame_pts      (const AVFrame *fr) { return fr->pts; }
int64_t   fw_frame_best_effort_timestamp (const AVFrame *fr)
{
   return fr->best_effort_timestamp;
}
