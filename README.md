![Repo size](https://img.shields.io/github/repo-size/eco-by-different/Little-Stream-Detector)
![Last commit](https://img.shields.io/github/last-commit/eco-by-different/Little-Stream-Detector)

# Little Stream Detector (LSD) 2.0

Little Stream Detector is a lightweight and portable tool for fast video file analysis without decoding or transcoding.

## What's New in 2.0

- Added native MP4, M4V, and MOV support.
- Added AVC/H.264 and HEVC/H.265 analysis for both Matroska and MP4.
- Introduced a shared, container-independent analysis pipeline.
- Added native `avcC`, `hvcC`, and AAC configuration parsing.
- Improved MP4 loading performance and GUI responsiveness.
- Fixed HEVC QP analysis for B-frames without weighted biprediction.
- Cleaned up obsolete validation and development code.
- No external tools or temporary files are required.

### Known Limitation

Fragmented MP4 files are not supported in version 2.0.

## Features

- Native Matroska, WebM, MP4, M4V, and MOV parsing
- H.264/AVC and H.265/HEVC analysis
- I, P, and B picture detection
- GOP structure and bitrate profile
- Native frame-level AVC and HEVC SliceQPY/DRF analysis
- DRF distribution histogram
- Video and audio stream information
- Summary, Streams, JSON, and Log views
- File selection and drag-and-drop support

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
