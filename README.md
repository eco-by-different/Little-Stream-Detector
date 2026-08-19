![Repo size](https://img.shields.io/github/repo-size/eco-by-different/Little-Stream-Detector)
![Last commit](https://img.shields.io/github/last-commit/eco-by-different/Little-Stream-Detector)

# Little Stream Detector (LSD) 2.0

Little Stream Detector is a lightweight and portable tool for fast video file analysis without decoding or transcoding.

## What's New in 2.0

- Added native support for Matroska/WebM, AVI 1.0, and unfragmented MP4/M4V/MOV containers.
- Added native H.264/AVC, H.265/HEVC, AV1, and MPEG-4 Part 2/XviD bitstream analysis.
- Added native H.264/AVC Annex B support for AVI, including SPS and PPS discovery from video samples.
- Added native AAC, MP3, AC-3, and E-AC-3 audio analysis.
- Added AAC-LC, HE-AAC, and HE-AACv2 configuration detection.
- Added MPEG Audio frame validation, decoded-duration accounting, and exact MP3 bitrate calculation.
- Added Dolby syncframe validation, decoded-duration accounting, and exact AC-3/E-AC-3 bitrate calculation.
- Added frame-level AV1 analysis, including frame types, hidden frames, `show_existing_frame`, and Base Q Index statistics.
- Added native MPEG-4 Part 2/XviD VOP analysis, including I/P/B picture detection and VOP quantizer statistics.
- Added native `avcC`, `hvcC`, `av1C`, AAC `AudioSpecificConfig`, `dac3`, and `dec3` parsing.
- Added support for QuickTime audio sample entry versions 0, 1, and 2.
- Added native MP4/MOV audio support for AAC, MP3, AC-3, and E-AC-3.
- Added native AVI audio support for MP3 and AC-3.
- Added container metadata detection for Matroska, AVI, MP4, and MOV.
- Introduced a shared, container-independent canonical media analysis pipeline.
- Added canonical video and audio sample indexes with sample accounting and validation.
- Improved MP4/MOV loading performance and GUI responsiveness.
- Fixed AVI bitrate profile generation and zero-length `idx1` sample handling.
- Fixed HEVC B-frame QP analysis without weighted biprediction.
- Improved reporting of unavailable or unsignaled metadata.
- Removed obsolete development and validation code.
- No external multimedia tools or temporary files are required.

### Known Limitations

- Fragmented MP4 files using `moof`, `traf`, and `trun` are not supported in version 2.0.
- OpenDML AVI and multi-segment `AVIX` files are not supported.
- AVI H.264/AVC support is intended for Annex B streams. AVI files using unusual length-prefixed AVC storage may not be supported.
- Complete PCM analysis is not included.
- AVI files containing AAC or E-AC-3 audio are not currently supported.
- Container-only color metadata such as MP4 `colr`/`nclx` or Matroska `Colour` elements is not currently used as a fallback.
- Some metadata may be shown as `N/A` when it is not explicitly present in the container or codec bitstream.

## Features

### Containers

- Native Matroska and WebM parsing
- Native AVI 1.0 parsing with `idx1` sample indexing
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
- MPEG-

## Zero Dependencies

LSD does not use FFmpeg, FFprobe, MediaInfo, or any other external multimedia tool.

Video files are read and analyzed only. They are never decoded, modified, or transcoded.

## Antivirus Notice

The executable is generated from a PowerShell-based application. Some sensitive antivirus engines, including Windows Defender and machine-learning-based scanners, may occasionally report a false positive.

The underlying `LSD.ps1` script is included for transparency. If the executable is blocked, review and run the PowerShell script directly instead.

---

## Screenshot

![lsd-gui.png](lsd-gui.png)

## Usage

1. Run `LSD.exe`.
2. Drag a video file into the application window, or click **Open video**.
3. Wait for the native analysis to complete.
4. Use **Copy** to copy the generated report.

No installation or administrator privileges are required.

## Running the PowerShell source

If `LSD.ps1` was downloaded from the Internet, Windows may block it.

Right-click `LSD.ps1`, select **Properties**, check **Unblock**, and click **Apply**. The script can then be started using **Run with PowerShell**.

Alternatively, unblock the downloaded ZIP file before extracting it. This prevents the extracted files from inheriting the Internet security marker.

This step is not required for the compiled executable.

## System Requirements

- Windows 10 or Windows 11
- 64-bit Windows recommended

## License

Little Stream Detector is licensed under the GNU General Public License v3.0.

You may use, study, modify, and redistribute the software under the terms of the GPL-3.0 license. Distributed modified versions must provide the corresponding source code and remain licensed under GPL-3.0.

See the LICENSE file for the complete license terms.
