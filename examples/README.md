# libav_ada examples

Four small programs that exercise the library, and a sample clip to run
them on. This directory is its own Alire crate; it uses the library from
the parent directory through a pin, so nothing has to be published or
installed first.

## Before you start

You need [Alire](https://alire.ada.dev) and the FFmpeg development
libraries. On Debian or Ubuntu:

```
sudo apt install libavformat-dev libavcodec-dev libswscale-dev libavutil-dev
```

Other systems, and the Windows setup, are in the
[main README](../README.md#install).

## Build

Run every command on this page from the `examples/` directory.

```
alr build
```

This builds the library and the four programs into `bin/`.

## Run

`alr run NAME -a "ARGUMENTS"` builds if needed, then runs one program.
The arguments go in a single quoted string.

Start with `probe`. If it prints the library versions and the clip's
properties, the crate is linked against a working FFmpeg:

```
alr run probe -a data/sample.mp4
```

```
libraries: avutil 60.8.100, avcodec 62.11.100, avformat 62.3.100, swscale 9.1.100
file:        data/sample.mp4
size:         640 x 360
format:      yuv420p
frame rate:  30/1 ( 3.00000000000000E+01 fps)
length:       10.000000000 s
frame count:  300
```

The version numbers are those of the FFmpeg on your machine and will
differ.

Decode every frame and report the decode rate:

```
alr run decode_all -a data/sample.mp4
```

The same, converting each frame to RGBA at 320 x 180:

```
alr run decode_all -a "data/sample.mp4 320 180"
```

Both must report `frames decoded: 300`, matching `container says: 300`.

Check the seek rules. Every line must start with `ok`, and the last line
must be `all checks passed`:

```
alr run seek_check -a data/sample.mp4
```

Seek to 7.3 seconds and write that frame as an image, 320 pixels wide:

```
alr run dump_frame -a "data/sample.mp4 7.3 frame.ppm 320"
```

```
got frame at  7.333333333 s,  640x 360 yuv420p
wrote frame.ppm ( 320x 180)
```

Open `frame.ppm` in any image viewer. The sample clip has the timestamp
burned into the top left corner of every frame, so the image must read
`00:00:07.333`: the first frame at or after the 7.3 seconds asked for.

The programs can also be run directly once built, for example
`./bin/probe data/sample.mp4`.

## The programs

| Program | Arguments | What it shows |
|---|---|---|
| `probe` | `FILE` | Library versions, size, pixel format, frame rate, length. |
| `decode_all` | `FILE [WIDTH HEIGHT]` | Decodes everything and reports decode fps. Proves the end-of-stream drain. |
| `seek_check` | `FILE` | Checks the seek rules stated in `Libav.Decoding` against a real file. Exits non-zero on a broken rule. |
| `dump_frame` | `FILE SECONDS OUT.ppm [WIDTH]` | Exact seek, one frame, scaled to RGBA, written as a PPM image. |

The sources are in [src/](src/), one file per program, each with a
header comment.

## The sample clip

`data/sample.mp4` is 10 seconds of FFmpeg's synthetic `testsrc2`
pattern: 640 x 360, 30 fps, 300 frames, H.264, about 400 KB. It has one
keyframe per second and B-frames, so seeking has ten groups of pictures
to cross and decode order differs from presentation order. It is
generated, not filmed, so it carries no third-party rights.

To regenerate it (needs the `ffmpeg` command-line tool with libx264):

```
sh data/make_sample.sh
```

## Your own files

Any file FFmpeg can decode works in place of `data/sample.mp4`. Paths
are relative to `examples/`, or absolute:

```
alr run probe -a /path/to/clip.mkv
```

`seek_check` is the one to run on a file that behaves strangely.

## If something goes wrong

* **`libavformat/avformat.h: No such file or directory`** at build time:
  the FFmpeg development packages are missing. See "Before you start".
* **`undefined reference to av_...`** at link time: the headers were
  found but the libraries were not. If FFmpeg is in a non-standard
  place, set `LIBAV_INCLUDE_DIR` and `LIBAV_LIB_DIR` as described in the
  [main README](../README.md#install).
* **`The requested executable is not built by this release`**: the
  command was run from the repository root, which is the library crate.
  Change to `examples/` first.
