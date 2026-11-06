#!/bin/sh
# Regenerates sample.mp4, the clip the examples are documented against.
# Needs the ffmpeg command-line tool with libx264.
#
# The picture is FFmpeg's synthetic "testsrc2" pattern: it burns the
# timestamp and the frame number into every frame, so a frame written by
# dump_frame can be checked by eye against the time that was asked for.
#
# 640x360, 30 fps, 10 s, H.264 yuv420p, one keyframe per second, B-frames.
# One keyframe per second gives seek_check ten GOPs to seek across; the
# B-frames make decode order differ from presentation order.

set -eu
cd "$(dirname "$0")"

ffmpeg -hide_banner -loglevel error -y \
  -f lavfi -i "testsrc2=size=640x360:rate=30:duration=10" \
  -c:v libx264 -preset veryslow -crf 30 -pix_fmt yuv420p \
  -g 30 -bf 2 \
  -movflags +faststart -map_metadata -1 \
  -fflags +bitexact -flags:v +bitexact \
  sample.mp4

echo "wrote $(pwd)/sample.mp4"
