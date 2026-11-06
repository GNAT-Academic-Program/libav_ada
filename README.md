# libav_ada

Ada binding to FFmpeg's `libavformat`, `libavcodec`, `libswscale` and
`libavutil`, with a safe decoding surface on top.

What you get:

```ada
D : Decoder;
F : Frame;
S : Scaler;
Pixels : RGBA_Buffer (0 .. 640 * 360 * 4 - 1);

Open (D, "clip.mp4");
Create (S, From => D, Width => 640, Height => 360);
Seek (D, 7.3);
while Next (D, F) loop
   Convert (S, F, Pixels);     --  Pixels is now the frame, packed RGBA
   ...                         --  upload to a texture, write to disk, etc.
end loop;
```

No pointer reaches your code. `Decoder`, `Frame` and `Scaler` are limited
controlled types: they cannot be copied, and they free their libav objects
when they go out of scope, on every path.

Scope of this version: video decoding, seeking, conversion to RGBA. No
audio, no encoding. Verified with valgrind: zero leaks over a decode,
seek and end-of-stream cycle.

## Read this first: the gotchas

1. **Which FFmpeg is installed decides whether it links.** The crate is
   built against the headers on your machine and links the libraries on
   your machine. Supported majors: FFmpeg 5, 6 and 7. Run `probe` first;
   it prints the library versions actually linked.

2. **Windows needs the DLLs next to the executable.** Six of them, all
   from the same FFmpeg build. A missing one is a crash with no message
   at startup, not a link error. See the Windows section.

3. **Seeking is to a keyframe, then decoding forward.** `Seek (D, T)` with
   `Exact => True` (the default) is frame-accurate but can cost up to one
   GOP of decoding (often 1 to 10 seconds of video). With
   `Exact => False` it is instant but lands on the keyframe at or before
   `T`. Scrubbing a timeline wants `False`; placing a cut wants `True`.

4. **Timestamps are presentation times, not frame indices.** Frames carry
   a `Timestamp` in seconds. There is no "frame number 1234" in a
   container; `Frame_Count` is a hint that MKV and MPEG-TS do not even
   provide. Build your editor on timestamps.

5. **`Convert` needs a buffer of exactly `Output_Length (S)` bytes.** The
   precondition checks it. Build with assertions on (the Alire
   development profile does) while developing.

6. **A `Frame` holds one picture or nothing.** `Next` replaces what the
   frame held. `Reset` empties it. If you want to keep a frame around
   (a ring buffer for playback), keep several `Frame` objects; you cannot
   copy one.

## Install

### Linux (Debian, Ubuntu)

```
sudo apt install libavformat-dev libavcodec-dev libswscale-dev libavutil-dev
```

Fedora:

```
sudo dnf install ffmpeg-free-devel
```

### macOS

```
brew install ffmpeg
```

Homebrew puts headers and libraries on the default search path on Intel.
On Apple Silicon set the two externals below to `/opt/homebrew/include`
and `/opt/homebrew/lib`.

### Windows

Download a **shared** build. Two known sources:

* https://www.gyan.dev/ffmpeg/builds/ , the `ffmpeg-release-full-shared.7z` file
* https://github.com/BtbN/FFmpeg-Builds/releases , a file whose name contains `shared`

Unpack it somewhere without spaces in the path, for example `C:\ffmpeg`.
It contains `include\`, `lib\` and `bin\`. Then, before building, tell the
crate where it is.

PowerShell:

```
$env:LIBAV_INCLUDE_DIR = "C:\ffmpeg\include"
```

```
$env:LIBAV_LIB_DIR = "C:\ffmpeg\lib"
```

cmd:

```
set LIBAV_INCLUDE_DIR=C:\ffmpeg\include
```

```
set LIBAV_LIB_DIR=C:\ffmpeg\lib
```

After building, copy every `.dll` from `C:\ffmpeg\bin` next to your
executable, or add `C:\ffmpeg\bin` to `PATH`.

The Windows path has not been exercised on this crate's first release.
The externals and the link line are as they should be; if `ld` cannot
find `avcodec.lib`, report the exact error.

## Build

Build the library:

```
alr build
```

The examples are their own Alire crate in `examples/`, so the library
stays free of executables. A sample clip ships with them:

```
cd examples
```

```
alr run probe -a data/sample.mp4
```

[examples/README.md](examples/README.md) walks through all four programs
on that clip, with the output to expect.

## Examples

| Program | What it shows |
|---|---|
| `probe FILE` | Library versions, size, pixel format, frame rate, length. Week-one check. |
| `dump_frame FILE SECONDS OUT.ppm [WIDTH]` | Exact seek, one frame, scaled to RGBA, written as PPM. The preview path of an editor. |
| `decode_all FILE [W H]` | Decodes everything, reports decode fps. Proves the end-of-stream drain and gives you a playback headroom number. |
| `seek_check FILE` | Checks the seek rules stated in `Libav.Decoding` against a real file. Run it on any file that behaves strangely. |

## The packages

From the bottom up. Application code uses the last three.

| Package | Role |
|---|---|
| `Libav` | `Pixel_Format` (opaque), `RGBA_Buffer`, `Linked_Version` (a record per library), `Library_Versions` (all four as text). |
| `Libav.Raw` | Direct imports of the libav C functions. Opaque pointers. The binding proper. |
| `Libav.Shim` | Struct fields and macros, each one a one-line C function in `src/c/libav_shim.c`. |
| `Libav.Errors` | `Libav_Error` exception; `Check (Code, Doing)` turns a negative return into it. |
| `Libav.Rationals` | Time bases. `To_Duration` and `To_Ticks` are the only place ticks meet seconds. |
| `Libav.Frames` | `Frame`: one decoded picture, limited controlled. |
| `Libav.Decoding` | `Decoder`: `Open`, `Next`, `Seek`, stream properties. |
| `Libav.Scaling` | `Scaler`: `Create` once, `Convert` per frame, to RGBA at any size. |

## Why there is a C file in an Ada binding

`src/c/libav_shim.c` is 40 lines of field reads and constants. It exists
because two things cannot be imported:

* **Struct fields.** libav's public structs change layout at every major
  release (`AVFrame` lost `key_frame` in 7.0, shifting every field after
  it). A field read compiled by the C compiler against the installed
  headers is correct on every major. An Ada record mirroring the layout
  is correct on one.
* **Macros.** `AVERROR(EAGAIN)`, `AVERROR_EOF`, `AV_NOPTS_VALUE`,
  `AV_TIME_BASE` and the enum constants have no symbol.

Rule for the shim: no logic. If a function in it does more than return a
field or a constant, it belongs in Ada.

## Rules for code built on this crate

* Only the bodies of `Libav.Decoding`, `Libav.Frames` and `Libav.Scaling`
  may `with Libav.Raw` or `Libav.Shim`. Grep for it in review.
* Ticks (`Int64` timestamps) never leave `Libav.Decoding`. Application
  code sees `Duration`.
* Never read a `Frame` from a task other than the one that owns the
  `Decoder` while `Next` may be running. The `Decoder` is not
  task-safe; one decoder, one task, a bounded ring of `Frame`s to the
  rest of the program.

## Binding notes, for whoever extends Libav.Raw

* GNAT lower-cases the imported symbol unless `External_Name` is given.
  libav's functions are snake_case and import as is; libswscale's are
  camelCase (`sws_getContext`) and need `External_Name`. The linker
  error for this is `undefined reference to sws_getcontext`.
* A C `T **out` parameter is `access T_Ptr` on the Ada side, called with
  `X'Access` on an `aliased` local.
* A null `AVDictionary **` or `AVInputFormat *` is just `null`.
* Array parameters (`uint8_t *const dst[]`) are passed as
  `System.Address` of an aliased Ada array declared with
  `Convention => C`.

## Adding audio or encoding

Both fit the same shape. Audio is a second `av_find_best_stream` with
`AVMEDIA_TYPE_AUDIO`, the same send/receive pump, and `libswresample` in
place of `libswscale` to get packed `s16` samples. Encoding is the pump
in reverse (`send_frame` / `receive_packet`) plus a muxer; its extra
costs are pts assignment, `av_packet_rescale_ts` between the codec and
stream time bases, and the final flush with a null frame. Add the needed
imports to `Libav.Raw`, field reads to the shim, and a new package next
to `Decoding`.

## License

Apache-2.0.
