![Repo size](https://img.shields.io/github/repo-size/eco-by-different/Little-Stream-Detector)
![Last commit](https://img.shields.io/github/last-commit/eco-by-different/Little-Stream-Detector)

## What's New in 2.0

- Added native support for Matroska/WebM, AVI, and unfragmented MP4/M4V/MOV containers.
- Added native AVI 1.0 and OpenDML AVI 2.0 parsing, including multi-segment `AVIX` files.
- Added native OpenDML standard index processing with legacy `idx1` fallback.
- Added native H.264/AVC, H.265/HEVC, AV1, and MPEG-4 Part 2/XviD bitstream analysis.
- Added native H.264/AVC Annex B support for AVI, including SPS and PPS discovery from video samples.
- Added native AAC, MP3, PCM, AC-3, and E-AC-3 audio analysis.
- Added integer and floating-point PCM detection, sample accounting, block-alignment validation, decoded-duration calculation, and exact bitrate reporting.
- Added AAC-LC, HE-AAC, and HE-AACv2 configuration detection.
- Added MPEG Audio frame validation, decoded-duration accounting, and exact MP3 bitrate calculation.
- Added Dolby syncframe validation, decoded-duration accounting, and exact AC-3/E-AC-3 bitrate calculation.
- Added frame-level AV1 analysis, including frame types, hidden frames, `show_existing_frame`, and Base Q Index statistics.
- Added native MPEG-4 Part 2/XviD VOP analysis, including I/P/B picture detection and VOP quantizer statistics.
- Added native `avcC`, `hvcC`, `av1C`, AAC `AudioSpecificConfig`, `dac3`, and `dec3` parsing.
- Added support for QuickTime audio sample entry versions 0, 1, and 2.
- Added native MP4/MOV audio support for AAC, MP3, PCM, AC-3, and E-AC-3.
- Added native AVI audio support for MP3, PCM, and AC-3.
- Added native Matroska PCM support for little-endian integer, big-endian integer, and IEEE floating-point audio.
- Added container metadata detection for Matroska, AVI, MP4, and MOV.
- Introduced a shared, container-independent canonical media analysis pipeline.
- Added canonical video and audio sample indexes with sample accounting and validation.
- Improved MP4/MOV loading performance and GUI responsiveness.
- Fixed AVI bitrate profile generation and zero-length index entry handling.
- Fixed OpenDML and legacy AVI index deduplication.
- Fixed HEVC B-frame QP analysis without weighted biprediction.
- Improved reporting of unavailable, unsignaled, or non-applicable metadata.
- Removed obsolete development and validation code.
- No external multimedia tools or temporary files are required.

### Known Limitations

- Fragmented MP4 files using `moof`, `traf`, and `trun` are not supported in version 2.0.
- AVI H.264/AVC support is intended for Annex B streams. AVI files using unusual length-prefixed AVC storage may not be supported.
- AVI files containing AAC or E-AC-3 audio are not currently supported.
- Container-only color metadata such as MP4 `colr`/`nclx` or Matroska `Colour` elements is not currently used as a fallback.
- Some metadata may be shown as `N/A` when it is not explicitly present in the container or codec bitstream.

## Features

### Containers

- Native Matroska and WebM parsing
- Native AVI 1.0 and OpenDML AVI 2.0 parsing
- Native multi-segment `AVIX` processing
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
- MPEG-4 Part 2/XviD analysis
- AVC configuration parsing from `avcC`
- AVC Annex B parsing with SPS/PPS discovery
- HEVC configuration parsing from `hvcC`
- AV1 configuration parsing from `av1C`
- MPEG-4 Visual Object Layer and VOP header analysis
- I, P, and B picture detection
- Keyframe and GOP structure analysis
- Packet size and bitrate profile analysis
- Native frame-level AVC and HEVC SliceQPY/DRF analysis
- Native AV1 Base Q Index analysis
- Native MPEG-4 Part 2 VOP quantizer analysis
- Quantizer distribution histograms
- Packet-to-frame consistency validation
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
- Native AVI PCM parsing through `WAVEFORMATEX` and supported extensible format parameters
- Native Matroska PCM parsing for `A_PCM/INT/LIT`, `A_PCM/INT/BIG`, and `A_PCM/FLOAT/IEEE`
- Native MOV/ISO Media PCM parsing for supported `sowt`, `twos`, `in24`, `in32`, `fl32`, `fl64`, and `lpcm` sample entries
- Native `AudioSpecificConfig`, `dac3`, and `dec3` parsing
- Sample rate, channel count, and channel layout reporting
- PCM bit-depth, endianness, sample format, and block-alignment reporting
- Canonical audio sample accounting
- Rejected-sample and first-failure reporting
- Codec-derived decoded-duration calculation
- Exact MP3, PCM, AC-3, and E-AC-3 bitrate calculation
- PCM block-alignment validation
- Multiple audio track association

### Interface and Reports

- Video and audio stream information
- Summary, Streams, JSON, and Log views
- Bitrate profile graph
- DRF, QP, Base Q Index, and VOP quantizer histograms
- File selection and drag-and-drop support
- Responsive background metadata preparation and analysis
- Copyable analysis reports
- Explicit reporting of unavailable or unsignaled values as `N/A`
- No external multimedia tools or temporary files

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
