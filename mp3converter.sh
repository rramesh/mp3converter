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
REPLACE_ORIGINAL=false    # new: do not replace originals by default

# Function to show help
show_help() {
    echo "Usage: $0 [OPTIONS] PATH"
    echo "Convert audio files in PATH to MP3 at specified bitrate and sampling rate."
    echo "Options:"
    echo "  -b, --bitrate BITRATE      Set bitrate (default 16k)"
    echo "  -s, --sampling-rate RATE   Set sampling rate (e.g. 24k, 24000). Default 24kHz"
    echo "  -r, --replace-original     Delete original files/directories and replace with converted output"
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
        -r|--replace-original|-ro|--replace-original)
            REPLACE_ORIGINAL=true
            shift
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

# Validate path: accept file or directory (must exist)
if [[ ! -e "$PATH_ARG" ]]; then
    echo "Error: $PATH_ARG does not exist"
    exit 1
fi

# Remember whether input is a file (single-file mode) or a directory (recursive)
IS_FILE=false
if [[ -f "$PATH_ARG" ]]; then
    IS_FILE=true
fi

# Check write permission on parent directory (needed for creating converted files)
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
    local is_root="$2"

    # Get absolute source path once
    src_dir=$(realpath "$src_dir")

    # Process root directory files first
    local files=()
    while IFS= read -r -d '' file; do
        files+=("$file")
    done < <(find "$src_dir" -maxdepth 1 -type f -print0)

    # Process root files
    for file in "${files[@]}"; do
        if is_audio "$file"; then
            local orig_name="$file"
            local base_name="${file%.*}"
            local extension="${file##*.}"
            
            if [[ "$extension" == "mp3" ]]; then
                # For MP3 files: use suffix during conversion
                local suffixed_name="${base_name}_${BITRATE}.mp3"
                if [[ "$DRY_RUN" == true ]]; then
                    echo "[DRY-RUN] Would convert root MP3: $(basename "$orig_name") -> $(basename "$suffixed_name")"
                    if [[ "$REPLACE_ORIGINAL" == true ]]; then
                        echo "[DRY-RUN] Would delete original: $(basename "$orig_name")"
                        echo "[DRY-RUN] Would rename: $(basename "$suffixed_name") -> $(basename "$orig_name")"
                    else
                        echo "[DRY-RUN] Would keep original and leave converted: $(basename "$suffixed_name")"
                    fi
                else
                    convert_audio "$orig_name" "$suffixed_name"
                    if [[ "$REPLACE_ORIGINAL" == true ]]; then
                        rm -f "$orig_name"
                        mv "$suffixed_name" "$orig_name"
                    fi
                fi
            else
                # For non-MP3 audio: convert directly to .mp3 (basename.mp3)
                local new_name="${base_name}.mp3"
                if [[ "$DRY_RUN" == true ]]; then
                    echo "[DRY-RUN] Would convert root file: $(basename "$orig_name") -> $(basename "$new_name")"
                    if [[ "$REPLACE_ORIGINAL" == true ]]; then
                        echo "[DRY-RUN] Would delete original: $(basename "$orig_name")"
                    else
                        echo "[DRY-RUN] Would keep original and create: $(basename "$new_name")"
                    fi
                else
                    convert_audio "$orig_name" "$new_name"
                    if [[ "$REPLACE_ORIGINAL" == true ]]; then
                        rm -f "$orig_name"
                    fi
                fi
            fi
        fi
    done

    # Process subdirectories
    local subdirs=()
    while IFS= read -r -d '' dir; do
        if [[ "$dir" != "$src_dir" ]]; then
            subdirs+=("$dir")
        fi
    done < <(find "$src_dir" -mindepth 1 -type d -print0)

    # Process each subdirectory
    for dir in "${subdirs[@]}"; do
        # Create paths using the full source directory path
        local rel_dir="${dir#$src_dir/}"
        local new_dir="${dir}_${BITRATE}"
        
        if [[ "$DRY_RUN" == true ]]; then
            printf "[DRY-RUN] Would process subdir: %q\n" "$rel_dir"
            printf "[DRY-RUN] Would create directory: %q\n" "$new_dir"
        else
            mkdir -p "$new_dir"
            printf "Processing subdir: %q\n" "$rel_dir"
            printf "Created: %q\n" "$new_dir"
        fi

        # Store all files in array first
        local subfiles=()
        while IFS= read -r -d '' file; do
            subfiles+=("$file")
        done < <(find "$dir" -type f -print0)

        # Process each file
        for file in "${subfiles[@]}"; do
            # Get relative path maintaining directory structure
            local rel_path="${file#$dir/}"
            local dst_file="$new_dir/$rel_path"

            if [[ "$DRY_RUN" == true ]]; then
                if is_audio "$file"; then
                    local orig_size=$(du -m "$file" 2>/dev/null | cut -f1)
                    if [[ -z "$orig_size" ]]; then orig_size="0"; fi
                    printf "[DRY-RUN] Would convert: %q\n" "$rel_path"
                    printf "[DRY-RUN] To: %q\n" "${dst_file%.*}.mp3"
                    echo "[DRY-RUN] Original size: ${orig_size}MB"
                else
                    printf "[DRY-RUN] Would copy: %q\n" "$rel_path"
                fi
            else
                mkdir -p "$(dirname "$dst_file")"
                if is_audio "$file"; then
                    convert_audio "$file" "$dst_file"
                else
                    cp -p "$file" "$dst_file"
                    printf "Copied: %q\n" "$rel_path"
                fi
            fi
        done

        # After processing files in this subdir: either replace original (delete+mv) or keep both
        if [[ "$REPLACE_ORIGINAL" == true ]]; then
            if [[ "$DRY_RUN" == true ]]; then
                printf "[DRY-RUN] Would delete original directory: %q\n" "$rel_dir"
                printf "[DRY-RUN] Would rename: %q -> %q\n" "${new_dir#$src_dir/}" "$rel_dir"
            else
                rm -rf "$dir"
                mv "$new_dir" "$dir"
                printf "Replaced original directory: %q\n" "$rel_dir"
            fi
        else
            if [[ "$DRY_RUN" == true ]]; then
                printf "[DRY-RUN] Would keep original directory: %q and leave converted at: %q\n" "$rel_dir" "$new_dir"
            else
                printf "Left original directory: %q (converted copy at %q)\n" "$rel_dir" "$new_dir"
            fi
        fi
    done
}

# Function to process a single file
process_file() {
    local src="$1"
    # ensure absolute path
    src=$(realpath "$src")
    if ! is_audio "$src"; then
        echo "Skipping non-audio file: $src"
        return 0
    fi

    local dir="$(dirname "$src")"
    local base="$(basename "$src")"
    local name="${base%.*}"
    local ext="${base##*.}"
    # For single-file we create a suffixed mp3
    local suffixed_dst="${dir}/${name}_${BITRATE}.mp3"
    local base_mp3="${dir}/${name}.mp3"
    local orig_size=$(du -m "$src" 2>/dev/null | cut -f1)
    if [[ -z "$orig_size" ]]; then orig_size="0"; fi

    if [[ "$DRY_RUN" == true ]]; then
        echo "[DRY-RUN] Would convert file: $src -> $(basename "$suffixed_dst")"
        if [[ "$REPLACE_ORIGINAL" == true ]]; then
            if [[ "$ext" == "mp3" ]]; then
                echo "[DRY-RUN] Would delete original: $(basename "$src")"
                echo "[DRY-RUN] Would rename: $(basename "$suffixed_dst") -> $(basename "$src")"
            else
                echo "[DRY-RUN] Would delete original: $(basename "$src")"
                echo "[DRY-RUN] Would place converted file as: $(basename "$base_mp3")"
            fi
        else
            echo "[DRY-RUN] Would keep original and create: $(basename "$suffixed_dst")"
        fi
        echo "[DRY-RUN] Original size: ${orig_size}MB"
        return 0
    fi

    # Actual conversion
    ffmpeg -y -i "$src" -ar "$SAMPLING_RATE" -b:a "$BITRATE" -ac 1 "$suffixed_dst" >/dev/null 2>&1
    local new_size=$(du -m "$suffixed_dst" 2>/dev/null | cut -f1)
    if [[ -z "$new_size" ]]; then new_size="0"; fi

    if [[ "$REPLACE_ORIGINAL" == true ]]; then
        if [[ "$ext" == "mp3" ]]; then
            rm -f "$src"
            mv "$suffixed_dst" "$src"
            echo "Converted and replaced: $src (was ${orig_size}MB -> ${new_size}MB)"
        else
            # keep standardized name without bitrate suffix for replacement
            rm -f "$src"
            mv "$suffixed_dst" "$base_mp3"
            echo "Converted and replaced: $base_mp3 (was ${orig_size}MB -> ${new_size}MB)"
        fi
    else
        echo "Converted: $suffixed_dst (was ${orig_size}MB -> ${new_size}MB)"
    fi
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
export -f is_audio convert_audio copy_file process_dir process_file
export BITRATE
export DRY_RUN
export SAMPLING_RATE
export REPLACE_ORIGINAL

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
if [[ "$DRY_RUN" == true ]]; then
    echo "Dry run: converting to ${BITRATE} (mono) at ${SAMPLING_RATE}Hz"
    echo "Dry run: Would process path $PATH_ARG"
else
    echo "Converting to ${BITRATE} (mono) at ${SAMPLING_RATE}Hz"
    echo "Processing path $PATH_ARG"
fi

# If PATH_ARG is a file handle single-file conversion
if [[ -f "$PATH_ARG" ]]; then
    if [[ "$CAFFEINATE" == true ]]; then
        caffeinate -i bash -c "$(declare -f); process_file '$PATH_ARG'"
    else
        process_file "$PATH_ARG"
    fi
    # finished single-file mode
    if [[ "$DRY_RUN" == true ]]; then
        echo "Dry run: Completed single file conversion"
    else
        echo "Single file conversion completed"
    fi
    exit 0
fi

# Otherwise assume directory mode (existing behavior)
if [[ "$CAFFEINATE" == true ]]; then
    caffeinate -i bash -c "$(declare -f); process_dir '$PATH_ARG' true"
else
    process_dir "$PATH_ARG" true
fi

# No need for final directory rename since we process root in place
if [[ "$DRY_RUN" == true ]]; then
    echo "Dry run: Completed"
else
    echo "Conversion completed"
fi