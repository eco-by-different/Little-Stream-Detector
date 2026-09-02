# Little Stream Detector (LSD)

![Repo size](https://img.shields.io/github/repo-size/eco-by-different/Little-Stream-Detector)
![Last commit](https://img.shields.io/github/last-commit/eco-by-different/Little-Stream-Detector)

Little Stream Detector (LSD) is a lightweight, portable video stream analyzer for Windows.

LSD performs native parsing of Matroska, WebM, MP4, M4V, MOV, and AVI containers together with native XviD, AVC/H.264, HEVC/H.265, VP9 and AV1 bitstream analysis. It provides frame-level QP/DRF statistics, quantizer distributions, GOP and I/P/B frame analysis, bitrate profiles, stream metadata, and detailed diagnostic reports.

Version 3.0 adds direct comparison of a current encode against a saved reference. The application can display both bitrate profiles and DRF/QP distributions in a shared view while preserving separate reports for the current file and the reference file.

LSD does not use FFmpeg, FFprobe, MediaInfo, or other external multimedia tools. Video files are read and analyzed without decoding, modification, or transcoding.

## Screenshot

![Little Stream Detector 3.0](lsd-gui.png)

---
## Antivirus Notice

The compiled `.exe` is generated from the PowerShell source. Some sensitive antivirus engines, including Windows Defender or machine-learning-based scanners, may report a false positive.

The readable PowerShell source is included. If the executable is blocked, use `LSD.ps1` instead and review the source before running it.

---

## Running the PowerShell Source

If `LSD.ps1` was downloaded from the Internet, Windows may block it.

1. Right-click `LSD.ps1`.
2. Select **Properties**.
3. Check **Unblock**.
4. Click **Apply**.
5. Start the script using **Run with PowerShell**.

Alternatively, unblock the downloaded ZIP archive before extracting it. This prevents extracted files from inheriting the Internet security marker.

This step is not required for the compiled executable.

## Download

Use the files from the latest `3.0` release:

- `LSD.exe` for normal use
- `LSD.ps1` as the readable PowerShell source
- the technical documentation for implementation details and supported analysis paths

No installation or administrator privileges are required.

## Usage

1. Run `LSD.exe`, or start `LSD.ps1` with PowerShell.
2. Drag a video file into the application window, or click **Open video**.
3. Wait for the native analysis to complete. The loaded file is shown as **A Current** in blue.
4. Click **Set Ref B** to store the current analysis as **B Reference** in gold.
5. Load another file to compare the new **A Current** against the saved **B Reference**.
6. Click **Remove Ref B** to remove the reference while keeping the current A result. If only B remains, removing B resets the application to its initial state.
7. Use **Summary A** and **Summary B** to review the reports independently.
8. Use **Copy** to copy the current analysis report.

For meaningful timeline comparison, A and B should represent time-aligned versions of the same source. Resolution, bitrate, file size, encoder settings, and quality parameters may differ.

## A Current and B Reference

LSD 3.0 uses a simple two-result model:

- **A Current** is the most recently analyzed file and is shown in blue.
- **B Reference** is the saved comparison result and is shown in gold.
- **Set Ref B** converts the current A result into the B reference.
- Loading another file creates a new A result while preserving B.
- **Remove Ref B** removes only B when A and B are present.
- Removing B when no A is present resets the interface to its startup state.

The comparison view includes:

- a shared bitrate profile using a common vertical scale
- blue A Current and gold B Reference legends
- frame-level DRF/QP distribution comparison
- shared DRF/QP scaling and aligned quantizer values
- separate **Summary A** and **Summary B** report tabs

The bitrate timeline is normalized to the duration of each file. Comparison is intended for time-aligned encodes of the same content.

## System Requirements

- Windows 10 or Windows 11
- PowerShell 5.1 or later when using `LSD.ps1`
- 64-bit Windows recommended

## What's New in 3.0

- Added the **A Current / B Reference** comparison model.
- Added **Set Ref B** and **Remove Ref B** controls.
- Added simultaneous blue A and gold B bitrate profiles with a shared scale.
- Added a clear in-graph legend for A Current and B Reference.
- Added comparative DRF, SliceQPY, AV1 Base Q Index, and MPEG-4 VOP quantizer distributions.
- Added a compact shared quantizer range from the lowest non-zero A/B value minus one to the highest non-zero A/B value plus one.
- Added side-by-side quantizer percentages for A and B.
- Added separate **Summary A** and **Summary B** views.
- Added automatic reset to the startup state when the last remaining reference is removed.
- Preserved the native, container-independent analysis pipeline introduced in version 2.0.
- No external multimedia tools or temporary files are required.

## Analysis Features

### Containers

- Native Matroska and WebM parsing
- Native AVI 1.0 and OpenDML AVI 2.0 parsing
- Native multi-segment AVIX processing
- Native AVI `idx1` sample indexing
- Native OpenDML `ix##` standard index processing
- Automatic OpenDML index preference with legacy `idx1` fallback
- 64-bit OpenDML base-offset handling
- Duplicate and zero-length AVI index entry protection
- Native unfragmented MP4, M4V, and MOV parsing
- Native Matroska block and lacing processing
- Native MP4/MOV sample table processing using `stsc`, `stsz`, `stco`/`co64`, `stts`, `ctts`, and `stss`
- Native AVI `LIST/INFO/ISFT` metadata detection
- Native MP4/MOV `©too` and QuickTime `©swr` metadata detection
- Separate Matroska muxing and writing application reporting

### Video Analysis

- H.264/AVC analysis
- H.265/HEVC analysis
- AV1 analysis
- VP9 analysis
- MPEG-4 Part 2/XviD analysis
- AVC configuration parsing from avcC
- AVC Annex B parsing with SPS/PPS discovery
- HEVC configuration parsing from hvcC
- AV1 configuration parsing from av1C
- VP9 uncompressed frame header analysis
- VP9 superframe detection and internal frame traversal
- MPEG-4 Visual Object Layer and VOP header analysis
- I, P, and B picture detection
- VP9 KEY and INTER frame detection
- Hidden and shown frame event analysis for AV1 and VP9
- Keyframe and GOP structure analysis
- Packet size and bitrate profile analysis
- Native frame-level AVC and HEVC SliceQPY/DRF analysis
- Native AV1 Base Q Index analysis
- Native VP9 Base Q Index analysis
- Native MPEG-4 Part 2 VOP quantizer analysis
- Quantizer distribution histograms
- Packet-to-frame consistency validation
- Internal frame and superframe accounting validation
- Codec-derived color metadata for AVC, HEVC, and AV1

### Audio Analysis

- AAC-LC analysis
- HE-AAC with SBR detection
- HE-AACv2 with SBR and Parametric Stereo detection
- MPEG-1 Layer III/MP3 frame analysis
- Dolby Digital/AC-3 syncframe analysis
- Dolby Digital Plus/E-AC-3 syncframe analysis
- Signed integer PCM analysis
- IEEE floating-point PCM analysis
- Little-endian and big-endian PCM detection
- Native AVI PCM parsing through WAVEFORMATEX and supported extensible format parameters
- Native Matroska PCM parsing for `A_PCM/INT/LIT`, `A_PCM/INT/BIG`, and `A_PCM/FLOAT/IEEE`
- Native MOV/ISO Media PCM parsing for supported `sowt`, `twos`, `in24`, `in32`, `fl32`, `fl64`, and `lpcm` sample entries
- Native `AudioSpecificConfig`, `dac3`, and `dec3` parsing
- Sample rate, channel count, and channel layout reporting
- PCM bit depth, endianness, sample format, and block-alignment reporting
- Canonical audio sample accounting
- Rejected-sample and first-failure reporting
- Codec-derived decoded-duration calculation
- Exact MP3, PCM, AC-3, and E-AC-3 bitrate calculation
- PCM block-alignment validation
- Multiple audio track association

### Interface and Reports

- Video and audio stream information
- **Summary A**, **Summary B**, **Streams**, **JSON**, and **Log** views
- Comparative bitrate profile graph
- Comparative DRF, QP, Base Q Index, and VOP quantizer distributions
- File selection and drag-and-drop support
- Responsive background metadata preparation and analysis
- Copyable analysis reports
- Explicit reporting of unavailable or unsignaled values as `N/A`
- No external multimedia tools or temporary files

## Known Limitations

- Fragmented MP4 files using `moof`, `traf`, and `trun` are not supported.
- AVI H.264/AVC support is intended for Annex B streams. AVI files using unusual length-prefixed AVC storage may not be supported.
- AVI files containing AAC or E-AC-3 audio are not currently supported.
- Container-only color metadata such as MP4 `colr`/`nclx` or Matroska `Colour` elements is not currently used as a fallback.
- Some metadata may be shown as `N/A` when it is not explicitly present in the container or codec bitstream.
- Bitrate comparison assumes that A and B are time-aligned versions of the same content.
- Quantizer distributions are directly comparable only when A and B use the same quantizer metric.

## License

Little Stream Detector is licensed under the GNU General Public License v3.0.

You may use, study, modify, and redistribute the software under the terms of the GPL-3.0 license. Distributed modified versions must provide the corresponding source code and remain licensed under GPL-3.0.

See the `LICENSE` file for the complete license terms.
