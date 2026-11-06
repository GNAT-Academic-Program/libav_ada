--  Libav.Raw: direct imports of the libav C functions this crate uses.
--
--  Every libav object is an opaque pointer here. Ada never sees inside
--  a struct (that is Libav.Shim's job), so these declarations are valid
--  for any libav major whose function signatures match, which for this
--  subset is 5.x, 6.x and 7.x.
--
--  Nothing above Libav.Decoding / Frames / Scaling may with this package.

with Interfaces.C;         use Interfaces.C;
with Interfaces.C.Strings; use Interfaces.C.Strings;
with System;

package Libav.Raw is

   ---------------------------------------------------------------------
   --  Opaque handles
   ---------------------------------------------------------------------

   type AVFormatContext   is limited null record with Convention => C;
   type AVCodecContext    is limited null record with Convention => C;
   type AVCodec           is limited null record with Convention => C;
   type AVCodecParameters is limited null record with Convention => C;
   type AVFrame           is limited null record with Convention => C;
   type AVPacket          is limited null record with Convention => C;
   type SwsContext        is limited null record with Convention => C;
   type AVDictionary      is limited null record with Convention => C;
   type AVInputFormat     is limited null record with Convention => C;

   type Format_Context_Ptr   is access all AVFormatContext   with Convention => C;
   type Codec_Context_Ptr    is access all AVCodecContext    with Convention => C;
   type Codec_Ptr            is access all AVCodec           with Convention => C;
   type Codec_Parameters_Ptr is access all AVCodecParameters with Convention => C;
   type Frame_Ptr            is access all AVFrame           with Convention => C;
   type Packet_Ptr           is access all AVPacket          with Convention => C;
   type Sws_Context_Ptr      is access all SwsContext        with Convention => C;
   type Dictionary_Ptr       is access all AVDictionary      with Convention => C;
   type Input_Format_Ptr     is access all AVInputFormat     with Convention => C;

   ---------------------------------------------------------------------
   --  Versions
   ---------------------------------------------------------------------

   function avutil_version   return unsigned with Import, Convention => C;
   function avcodec_version  return unsigned with Import, Convention => C;
   function avformat_version return unsigned with Import, Convention => C;
   function swscale_version  return unsigned with Import, Convention => C;

   ---------------------------------------------------------------------
   --  libavformat
   ---------------------------------------------------------------------

   function avformat_open_input
     (ps      : access Format_Context_Ptr;
      url     : chars_ptr;
      fmt     : Input_Format_Ptr;
      options : access Dictionary_Ptr) return int
     with Import, Convention => C;

   procedure avformat_close_input (ps : access Format_Context_Ptr)
     with Import, Convention => C;

   function avformat_find_stream_info
     (ic : Format_Context_Ptr; options : access Dictionary_Ptr) return int
     with Import, Convention => C;

   function av_find_best_stream
     (ic              : Format_Context_Ptr;
      media_type      : int;
      wanted_stream   : int;
      related_stream  : int;
      decoder_ret     : access Codec_Ptr;
      flags           : int) return int
     with Import, Convention => C;
   --  Returns the stream index, or a negative error.

   function av_read_frame (s : Format_Context_Ptr; pkt : Packet_Ptr) return int
     with Import, Convention => C;

   function av_seek_frame
     (s : Format_Context_Ptr; stream_index : int; timestamp : Int64; flags : int)
      return int
     with Import, Convention => C;

   ---------------------------------------------------------------------
   --  libavcodec
   ---------------------------------------------------------------------

   function avcodec_alloc_context3 (codec : Codec_Ptr) return Codec_Context_Ptr
     with Import, Convention => C;

   procedure avcodec_free_context (avctx : access Codec_Context_Ptr)
     with Import, Convention => C;

   function avcodec_parameters_to_context
     (codec : Codec_Context_Ptr; par : Codec_Parameters_Ptr) return int
     with Import, Convention => C;

   function avcodec_open2
     (avctx : Codec_Context_Ptr; codec : Codec_Ptr; options : access Dictionary_Ptr)
      return int
     with Import, Convention => C;

   function avcodec_send_packet (avctx : Codec_Context_Ptr; avpkt : Packet_Ptr) return int
     with Import, Convention => C;
   --  avpkt = null enters draining mode (flush at end of stream).

   function avcodec_receive_frame (avctx : Codec_Context_Ptr; frame : Frame_Ptr) return int
     with Import, Convention => C;

   procedure avcodec_flush_buffers (avctx : Codec_Context_Ptr)
     with Import, Convention => C;

   function av_packet_alloc return Packet_Ptr
     with Import, Convention => C;

   procedure av_packet_free (pkt : access Packet_Ptr)
     with Import, Convention => C;

   procedure av_packet_unref (pkt : Packet_Ptr)
     with Import, Convention => C;

   ---------------------------------------------------------------------
   --  libavutil
   ---------------------------------------------------------------------

   function av_frame_alloc return Frame_Ptr
     with Import, Convention => C;

   procedure av_frame_free (frame : access Frame_Ptr)
     with Import, Convention => C;

   procedure av_frame_unref (frame : Frame_Ptr)
     with Import, Convention => C;

   procedure av_frame_move_ref (dst : Frame_Ptr; src : Frame_Ptr)
     with Import, Convention => C;
   --  Moves ownership of the buffers from src to dst; src becomes empty.

   function av_strerror (errnum : int; errbuf : chars_ptr; errbuf_size : size_t) return int
     with Import, Convention => C;

   function av_get_pix_fmt_name (pix_fmt : int) return chars_ptr
     with Import, Convention => C;
   --  May return null for an unknown format.

   ---------------------------------------------------------------------
   --  libswscale
   --
   --  Without External_Name, GNAT imports the lower-cased Ada name.
   --  That is fine for libav's snake_case functions above and wrong for
   --  libswscale's camelCase ones, so these two spell the symbol out.
   ---------------------------------------------------------------------

   function sws_getContext
     (srcW, srcH  : int; srcFormat : int;
      dstW, dstH  : int; dstFormat : int;
      flags       : int;
      srcFilter   : System.Address;
      dstFilter   : System.Address;
      param       : System.Address) return Sws_Context_Ptr
     with Import, Convention => C, External_Name => "sws_getContext";

   function sws_scale
     (c          : Sws_Context_Ptr;
      srcSlice   : System.Address;   --  const uint8_t *const srcSlice[]
      srcStride  : System.Address;   --  const int srcStride[]
      srcSliceY  : int;
      srcSliceH  : int;
      dst        : System.Address;   --  uint8_t *const dst[]
      dstStride  : System.Address)   --  const int dstStride[]
      return int
     with Import, Convention => C;
   --  Returns the height of the output slice, or a negative error.

   procedure sws_freeContext (c : Sws_Context_Ptr)
     with Import, Convention => C, External_Name => "sws_freeContext";

end Libav.Raw;
