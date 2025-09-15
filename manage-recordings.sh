#!/bin/bash

# Neko Recording Manager
# Manages recording files and provides utilities for handling Neko recordings

set -euo pipefail

readonly SCRIPT_NAME="$(basename "$0")"
readonly RECORDINGS_DIR="./recordings"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

show_help() {
    cat << EOF
Usage: $SCRIPT_NAME [COMMAND] [OPTIONS]

Neko Recording Manager - Manage your Neko stream recordings

COMMANDS:
    list, ls           List all recordings
    info FILE          Show information about a recording file
    play FILE          Play a recording file (requires vlc or mpv)
    convert FILE       Convert WebM to MP4 (requires ffmpeg)
    clean [DAYS]       Clean recordings older than DAYS (default: 30)
    size               Show total size of recordings
    help, -h, --help  Show this help message

EXAMPLES:
    $SCRIPT_NAME list                           # List all recordings
    $SCRIPT_NAME info recording-20250915-143022.webm  # Show file info
    $SCRIPT_NAME play recording-20250915-143022.webm  # Play recording
    $SCRIPT_NAME convert recording-20250915-143022.webm  # Convert to MP4
    $SCRIPT_NAME clean 7                        # Remove recordings older than 7 days
    $SCRIPT_NAME size                           # Show storage usage

EOF
}

list_recordings() {
    print_info "Recordings in $RECORDINGS_DIR:"
    
    if [ ! -d "$RECORDINGS_DIR" ]; then
        print_error "Recordings directory does not exist: $RECORDINGS_DIR"
        return 1
    fi
    
    local count=0
    while IFS= read -r -d '' file; do
        local basename=$(basename "$file")
        local size=$(du -h "$file" | cut -f1)
        local date=$(stat -c %y "$file" | cut -d' ' -f1,2 | cut -d'.' -f1)
        printf "  %-40s %8s  %s\n" "$basename" "$size" "$date"
        ((count++))
    done < <(find "$RECORDINGS_DIR" -name "*.webm" -print0 | sort -z)
    
    if [ $count -eq 0 ]; then
        print_warning "No recordings found."
    else
        print_success "Found $count recording(s)"
    fi
}

show_info() {
    local file="$1"
    
    if [ ! -f "$RECORDINGS_DIR/$file" ]; then
        print_error "Recording not found: $file"
        return 1
    fi
    
    local filepath="$RECORDINGS_DIR/$file"
    
    print_info "Recording Information for: $file"
    echo
    
    # Basic file info
    echo "File: $filepath"
    echo "Size: $(du -h "$filepath" | cut -f1)"
    echo "Modified: $(stat -c %y "$filepath" | cut -d'.' -f1)"
    echo
    
    # Try to get video info with ffprobe if available
    if command -v ffprobe >/dev/null 2>&1; then
        print_info "Video Information:"
        ffprobe -v quiet -show_format -show_streams "$filepath" 2>/dev/null | grep -E "(duration|width|height|codec_name|bit_rate)" || true
    else
        print_warning "Install ffmpeg to see detailed video information"
    fi
}

play_recording() {
    local file="$1"
    
    if [ ! -f "$RECORDINGS_DIR/$file" ]; then
        print_error "Recording not found: $file"
        return 1
    fi
    
    local filepath="$RECORDINGS_DIR/$file"
    
    # Try different video players
    if command -v vlc >/dev/null 2>&1; then
        print_info "Playing with VLC: $file"
        vlc "$filepath" >/dev/null 2>&1 &
    elif command -v mpv >/dev/null 2>&1; then
        print_info "Playing with MPV: $file"
        mpv "$filepath"
    elif command -v xdg-open >/dev/null 2>&1; then
        print_info "Opening with default application: $file"
        xdg-open "$filepath"
    else
        print_error "No video player found. Install vlc, mpv, or use a GUI file manager"
        return 1
    fi
}

convert_recording() {
    local file="$1"
    
    if [ ! -f "$RECORDINGS_DIR/$file" ]; then
        print_error "Recording not found: $file"
        return 1
    fi
    
    if ! command -v ffmpeg >/dev/null 2>&1; then
        print_error "ffmpeg is required for conversion. Install with: apt-get install ffmpeg"
        return 1
    fi
    
    local input_path="$RECORDINGS_DIR/$file"
    local output_path="$RECORDINGS_DIR/${file%.webm}.mp4"
    
    if [ -f "$output_path" ]; then
        print_warning "Output file already exists: $(basename "$output_path")"
        read -p "Overwrite? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Conversion cancelled"
            return 0
        fi
    fi
    
    print_info "Converting $file to MP4..."
    if ffmpeg -i "$input_path" -c:v libx264 -preset medium -crf 23 -c:a aac "$output_path" -y; then
        print_success "Converted to: $(basename "$output_path")"
    else
        print_error "Conversion failed"
        return 1
    fi
}

clean_recordings() {
    local days=${1:-30}
    
    print_info "Cleaning recordings older than $days days..."
    
    if [ ! -d "$RECORDINGS_DIR" ]; then
        print_error "Recordings directory does not exist: $RECORDINGS_DIR"
        return 1
    fi
    
    local count=0
    local total_size=0
    
    while IFS= read -r -d '' file; do
        local size=$(stat -c%s "$file")
        total_size=$((total_size + size))
        rm -f "$file"
        print_info "Deleted: $(basename "$file") ($(numfmt --to=iec $size))"
        ((count++))
    done < <(find "$RECORDINGS_DIR" -name "*.webm" -mtime +$days -print0)
    
    if [ $count -eq 0 ]; then
        print_info "No recordings older than $days days found"
    else
        print_success "Deleted $count recording(s), freed $(numfmt --to=iec $total_size)"
    fi
}

show_size() {
    if [ ! -d "$RECORDINGS_DIR" ]; then
        print_error "Recordings directory does not exist: $RECORDINGS_DIR"
        return 1
    fi
    
    local total_size=$(du -sh "$RECORDINGS_DIR" 2>/dev/null | cut -f1)
    local file_count=$(find "$RECORDINGS_DIR" -name "*.webm" | wc -l)
    
    print_info "Storage Usage:"
    echo "  Directory: $RECORDINGS_DIR"
    echo "  Total size: $total_size"
    echo "  Files: $file_count recording(s)"
}

# Main script logic
main() {
    if [ $# -eq 0 ]; then
        show_help
        exit 0
    fi
    
    case "${1:-}" in
        list|ls)
            list_recordings
            ;;
        info)
            if [ $# -lt 2 ]; then
                print_error "Usage: $SCRIPT_NAME info <filename>"
                exit 1
            fi
            show_info "$2"
            ;;
        play)
            if [ $# -lt 2 ]; then
                print_error "Usage: $SCRIPT_NAME play <filename>"
                exit 1
            fi
            play_recording "$2"
            ;;
        convert)
            if [ $# -lt 2 ]; then
                print_error "Usage: $SCRIPT_NAME convert <filename>"
                exit 1
            fi
            convert_recording "$2"
            ;;
        clean)
            clean_recordings "${2:-30}"
            ;;
        size)
            show_size
            ;;
        help|-h|--help)
            show_help
            ;;
        *)
            print_error "Unknown command: $1"
            echo
            show_help
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
