# mp3converter

Simple shell script to convert audio files under a directory to MP3 at a specified bitrate (default 16k) and sampling rate (default 24kHz) using ffmpeg. The script converts all audio files recursively, preserves directory structure, copies non-audio files unchanged, and replaces the original top-level directory after successful conversion.

## Install and make executable:
1. Copy `mp3converter.sh` to a directory you control, e.g. `~/bin/`.
2. Make it executable:
   chmod +x ~/bin/mp3converter.sh

## Add to PATH (example for bash or macOS zsh):
# For bash (Linux or macOS if using bash)
1. Open `~/.bashrc` or `~/.bash_profile` and add:
   export PATH="$HOME/bin:$PATH"
2. Reload:
   source ~/.bashrc   # or source ~/.bash_profile

# For macOS users using zsh (default on newer macOS)
1. Open `~/.zshrc` and add:
   export PATH="$HOME/bin:$PATH"
2. Reload:
   source ~/.zshrc

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