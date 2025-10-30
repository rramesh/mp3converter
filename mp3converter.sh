#!/bin/bash

# MP3 Converter Script
# Converts audio files in a directory to MP3 at specified bitrate, defaults to 16k mono.
# Creates a new directory with _<bitrate> suffix, processes recursively, copies non-audio files,
# then deletes original and renames new directory back.

# Default values
BITRATE="16k"
DRY_RUN=false
PATH_ARG=""
SAMPLING_RATE_RAW=""
SAMPLING_RATE="24000"    # default 24 kHz in Hz

# Function to show help
show_help() {
    echo "Usage: $0 [OPTIONS] PATH"
    echo "Convert audio files in PATH to MP3 at specified bitrate and sampling rate."
    echo "Options:"
    echo "  -b, --bitrate BITRATE      Set bitrate (default 16k)"
    echo "  -s, --sampling-rate RATE   Set sampling rate (e.g. 24k, 24000). Default 24kHz"
    echo "  -d, --dry-run              Show operations without executing"
    echo "  -h, --help                 Show this help"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -b|--bitrate)
            BITRATE="$2"
            shift 2
            ;;
        -s|--sampling-rate)
            SAMPLING_RATE_RAW="$2"
            shift 2
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            if [[ -z "$PATH_ARG" ]]; then
                PATH_ARG="$1"
            else
                echo "Error: Multiple paths provided"
                show_help
                exit 1
            fi
            shift
            ;;
    esac
done

if [[ -z "$PATH_ARG" ]]; then
    show_help
    exit 1
fi

# Validate path
if [[ ! -d "$PATH_ARG" ]]; then
    echo "Error: $PATH_ARG is not a directory"
    exit 1
fi

# Check write permission
PARENT=$(dirname "$PATH_ARG")
if ! touch "$PARENT/.test_write" 2>/dev/null; then
    echo "Error: No write permission in $PARENT"
    exit 1
else
    rm "$PARENT/.test_write"
fi

# Check ffmpeg
if ! command -v ffmpeg >/dev/null 2>&1; then
    echo "Error: ffmpeg not installed"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "Install with: brew install ffmpeg"
    elif command -v apt >/dev/null; then
        echo "Install with: sudo apt install ffmpeg"
    elif command -v yum >/dev/null; then
        echo "Install with: sudo yum install ffmpeg"
    else
        echo "Please install ffmpeg"
    fi
    exit 1
fi

# Detect OS for caffeinate
OS=$(uname -s)
if [[ "$OS" == "Darwin" ]]; then
    CAFFEINATE=true
else
    CAFFEINATE=false
fi

# Get absolute paths (using realpath which handles spaces better)
if ! command -v realpath >/dev/null 2>&1; then
    # Fallback if realpath not available
    PATH_ARG="$(cd "$(dirname "$PATH_ARG")" && pwd)/$(basename "$PATH_ARG")"
else
    PATH_ARG=$(realpath "$PATH_ARG")
fi

PARENT="$(dirname "$PATH_ARG")"
DIR_NAME="$(basename "$PATH_ARG")"
NEW_DIR="${DIR_NAME}_${BITRATE}"
NEW_DIR_PATH="$PARENT/$NEW_DIR"

# Function to check if file is audio
is_audio() {
    local file="$1"
    # Prefer ffprobe for reliable stream detection
    if command -v ffprobe >/dev/null 2>&1; then
        # ffprobe prints stream types; check for any 'audio' stream
        if ffprobe -v error -show_entries stream=codec_type -of default=noprint_wrappers=1:nokey=1 "$file" 2>/dev/null | grep -q '^audio$'; then
            return 0
        else
            return 1
        fi
    else
        # Fallback to ffmpeg: show banner/streams and search for audio stream lines
        if ffmpeg -hide_banner -i "$file" 2>&1 | grep -qiE 'Stream.*Audio:|Audio:'; then
            return 0
        else
            return 1
        fi
    fi
}

# Function to process directory recursively
process_dir() {
    local src_dir="$1"
    local dst_dir="$2"

    # Resolve absolute source directory (must exist)
    src_dir=$(cd "$src_dir" && pwd)

    # Use the dst_dir parameter as provided.
    # If it's not absolute, make it absolute relative to its parent if possible.
    if [[ "$dst_dir" == /* ]]; then
        dst_dir="$dst_dir"
    else
        # try to compute absolute destination without creating it
        dst_dir="$(cd "$(dirname "$dst_dir")" 2>/dev/null && pwd)/$(basename "$dst_dir")"
        # if the above failed, fallback to expanding relative to current working dir
        if [[ -z "$dst_dir" ]]; then
            dst_dir="$(pwd)/$dst_dir"
        fi
    fi

    # Collect files (relative paths) from source dir
    local files=()
    while IFS= read -r -d '' f; do
        files+=("$f")
    done < <(cd "$src_dir" && find . -type f -print0)

    # Process each file preserving directory structure
    for rel in "${files[@]}"; do
        # strip leading ./ if present
        rel="${rel#./}"

        local src_file="$src_dir/$rel"
        local dst_file="$dst_dir/$rel"
        local dst_dir_path
        dst_dir_path="$(dirname "$dst_file")"

        if [[ "$DRY_RUN" == true ]]; then
            echo "[DRY-RUN] Would create directory: $dst_dir_path"
        else
            mkdir -p "$dst_dir_path"
        fi

        if is_audio "$src_file"; then
            convert_audio "$src_file" "$dst_file"
        else
            copy_file "$src_file" "$dst_file"
        fi
    done
}

# Normalize sampling rate input into integer Hz (supports: 24000, 24k, 24khz)
normalize_sampling_rate() {
    local v="$1"
    if [[ -z "$v" ]]; then
        SAMPLING_RATE="24000"
        return 0
    fi
    local low="${v,,}"   # lowercase
    if [[ $low =~ ^([0-9]+)$ ]]; then
        SAMPLING_RATE="${BASH_REMATCH[1]}"
    elif [[ $low =~ ^([0-9]+)[kK]$ ]]; then
        SAMPLING_RATE=$(( ${BASH_REMATCH[1]} * 1000 ))
    elif [[ $low =~ ^([0-9]+)[kK][hH][zZ]$ ]]; then
        SAMPLING_RATE=$(( ${BASH_REMATCH[1]} * 1000 ))
    else
        echo "Error: Unsupported sampling rate format: '$v'. Use e.g. 24000 or 24k"
        exit 1
    fi

    # basic sanity check
    if ! [[ "$SAMPLING_RATE" =~ ^[0-9]+$ ]] || [[ "$SAMPLING_RATE" -lt 8000 ]]; then
        echo "Error: Invalid sampling rate after normalization: $SAMPLING_RATE"
        exit 1
    fi
}

# Normalize user sampling rate (if provided)
normalize_sampling_rate "$SAMPLING_RATE_RAW"

# Function to convert audio (simplified logging)
convert_audio() {
    local src="$1"
    local dst="${2%.*}.mp3"
    local orig_size=$(du -m "$src" 2>/dev/null | cut -f1)
    if [[ -z "$orig_size" ]]; then orig_size="0"; fi

    if [[ "$DRY_RUN" == true ]]; then
        echo "[DRY-RUN] Would convert: $(basename "$src")"
        echo "[DRY-RUN] To: $(basename "$dst")"
        echo "[DRY-RUN] Original size: ${orig_size}MB"
    else
        # include sampling rate (-ar) and bitrate (-b:a)
        ffmpeg -y -i "$src" -ar "$SAMPLING_RATE" -b:a "$BITRATE" -ac 1 "$dst" >/dev/null 2>&1
        local new_size=$(du -m "$dst" 2>/dev/null | cut -f1)
        if [[ -z "$new_size" ]]; then new_size="0"; fi
        echo "Converted: $(basename "$src") -> $(basename "$dst")"
        echo "Size: ${orig_size}MB -> ${new_size}MB"
    fi
}

# Function to copy file (simplified logging)
copy_file() {
    local src="$1"
    local dst="$2"
    
    if [[ "$DRY_RUN" == true ]]; then
        echo "[DRY-RUN] Would copy: $(basename "$src")"
    else
        cp -p "$src" "$dst"
        echo "Copied: $(basename "$src")"
    fi
}

# Export functions and key variables so they are available to subprocesses (like bash -c)
export -f is_audio convert_audio copy_file process_dir
export BITRATE
export DRY_RUN
export SAMPLING_RATE

# Safety check - never process root or system directories
if [[ "$PATH_ARG" == "/" || "$PATH_ARG" =~ ^/(bin|sbin|usr|etc|var|tmp) ]]; then
    echo "Error: Cannot process system directories"
    exit 1
fi

# Safety check for destination path
if [[ ! "$NEW_DIR_PATH" =~ ^/ ]]; then
    echo "Error: Invalid destination path"
    exit 1
fi

# Main logic
# Log bitrate and sampling rate info before processing
if [[ "$DRY_RUN" == true ]]; then
    echo "Dry run: converting to ${BITRATE} (mono) at ${SAMPLING_RATE}Hz"
else
    echo "Converting to ${BITRATE} (mono) at ${SAMPLING_RATE}Hz"
fi

if [[ "$DRY_RUN" == true ]]; then
    echo "Dry run: Would create $NEW_DIR_PATH"
else
    mkdir -p "$NEW_DIR_PATH"
    echo "Created $NEW_DIR_PATH"
fi

if [[ "$CAFFEINATE" == true ]]; then
    # Use exported functions/vars so bash -c can call process_dir
    # Quote paths to handle spaces correctly
    caffeinate -i bash -c "$(declare -f); process_dir '$PATH_ARG' '$NEW_DIR_PATH'"
else
    process_dir "$PATH_ARG" "$NEW_DIR_PATH"
fi

# Verify new directory exists and has files before deletion
if [[ "$DRY_RUN" == true ]]; then
    echo "Dry run: Would delete $PATH_ARG"
    echo "Dry run: Would rename $NEW_DIR_PATH to $PATH_ARG"
else
    if [[ ! -d "$NEW_DIR_PATH" ]]; then
        echo "Error: Conversion failed - new directory not created"
        exit 1
    fi
    if ! find "$NEW_DIR_PATH" -type f | grep -q .; then
        echo "Error: Conversion failed - no files in new directory"
        exit 1
    fi
    rm -rf "$PATH_ARG"
    echo "Deleted $PATH_ARG"
    mv "$NEW_DIR_PATH" "$PATH_ARG"
    echo "Renamed $NEW_DIR_PATH to $PATH_ARG"
fi