# mp3converter

Simple shell script to convert audio files under a directory to MP3 at specified bitrate (default 16k) and sampling rate (default 24kHz) using ffmpeg.

## Quick Install
```bash
curl -s https://raw.githubusercontent.com/rramesh/mp3converter/main/installer.sh | bash
```
This will:
- Download the converter script to ~/.mp3c
- Make it executable
- Add to PATH (detects shell automatically)
- Show usage instructions

## Manual Installation

### Install and make executable:
1. Create directory and copy script:
```bash
mkdir -p ~/.mp3c
cp mp3converter.sh ~/.mp3c/
chmod +x ~/.mp3c/mp3converter.sh
```

### Add to PATH:
# For macOS (using zsh - default):
1. Open `~/.zshrc` and add:
   export PATH="$HOME/.mp3c:$PATH"
2. Reload:
   source ~/.zshrc

# For bash users (Linux or macOS):
1. Open appropriate RC file:
   - Linux: `~/.bashrc`
   - macOS: `~/.bash_profile`
2. Add:
   export PATH="$HOME/.mp3c:$PATH"
3. Reload:
   source ~/.bashrc  # or ~/.bash_profile on macOS

## Requirements
- ffmpeg must be installed and available on PATH.
- Recommended ffmpeg: any recent stable release; the script uses ffmpeg (and optionally ffprobe if available) to detect and convert audio.

Install ffmpeg:
- macOS (Homebrew):
  brew install ffmpeg

- Debian / Ubuntu:
  sudo apt update
  sudo apt install ffmpeg

- RPM-based systems (Fedora / CentOS / RHEL):
  - Fedora:
    sudo dnf install ffmpeg
  - CentOS / RHEL (may require EPEL or RPMFusion):
    sudo yum install epel-release
    sudo yum install ffmpeg
  If packages are not available in default repos, enable the appropriate third-party repo (EPEL/RPMFusion) for your distribution.

## Usage:
  mp3converter.sh [OPTIONS] PATH

## Options:
  -b, --bitrate BITRATE         Set audio bitrate (e.g. 16k, 64k). Default: 16k
  -s, --sampling-rate RATE      Set sampling rate. Accepts formats like `24k`, `24khz`, or `24000`. Default: 24kHz (24000)
  -d, --dry-run                Show operations without executing (no files/dirs created)
  -h, --help                   Show help

Notes:
- The script converts audio to MP3 with one audio channel (mono) by default; it uses ffmpeg parameters to set sampling rate (`-ar`) and bitrate (`-b:a`) and forces mono (`-ac 1`).
- Default values: bitrate = 16k, sampling rate = 24000 Hz (24kHz), mono.

## Examples:
- Convert directory `/tmp/ddv` to default (16k, 24kHz mono):
  mp3converter.sh /tmp/ddv

- Convert using 64k bitrate and keep default sampling rate:
  mp3converter.sh -b 64k /tmp/ddv

- Convert using 32k bitrate and 48kHz sampling rate:
  mp3converter.sh -b 32k -s 48k /tmp/ddv

- Explicit sampling-rate in Hz:
  mp3converter.sh -s 24000 /tmp/ddv

- Dry-run (shows what would be done):
  mp3converter.sh --dry-run -b 32k -s 24k /tmp/ddv

## Behavior summary
- A sibling directory named `<dirname>_<bitrate>` is created (e.g. `ddv_16k`) and the entire structure is replicated with converted `.mp3` files.
- Non-audio files (including hidden files) are copied as-is.
- After successful conversion the original top-level directory is deleted and the new one is renamed back to the original name.
- Dry-run prints the same logs without performing filesystem changes or running ffmpeg.

## Notes:
- Script will create a sibling directory named `<dirname>_<bitrate>` (e.g. `ddv_16k`), replicate the directory structure, convert audio files to `.mp3`, copy non-audio files as-is, then delete the original directory and rename the new one back to the original name.
- On macOS the script uses `caffeinate` (if available) to prevent sleep while processing.
- The script requires `ffmpeg`. If missing it prints install hints (Homebrew / apt / yum).
- In dry-run mode no new directories or files are created; logs indicate what would happen.