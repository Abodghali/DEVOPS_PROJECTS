#!/bin/bash

# ==============================================================================
# Script Name: log_size_monitor.sh
# Description: Monitors the size of a log file (default 'access.log').
#              If it exceeds a configured threshold (default 2GB), it prompts
#              the user and compresses the log file using gzip if confirmed,
#              safely rotating it.
#
# Educational Guide:
#   1. File Size Retrieval:
#      - wc -c < file is a highly portable way to get the file size in bytes
#        across different Unix/Linux platforms without stat command variances.
#   2. Log Rotation Principle:
#      - Directly compressing a live log file can crash the writing process.
#      - Correct way: Move the live log to a temporary filename, recreate the 
#        original file empty (touch), reset permissions, and then compress the
#        renamed log file.
#   3. Gzip Compression:
#      - gzip reduces log file sizes significantly (often by 85-90% for text).
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. Colors for Console Output
# ------------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ------------------------------------------------------------------------------
# 2. Configuration & Setup
# ------------------------------------------------------------------------------
# Default target log file path
LOG_FILE="${1:-access.log}"

# Size threshold: Default is 2GB (2 * 1024 * 1024 * 1024 bytes)
THRESHOLD_BYTES=$((2 * 1024 * 1024 * 1024))
THRESHOLD_LABEL="2 GB"

# Optional: Allow customizing threshold via second argument (in Megabytes) for testing
# Usage: ./log_size_monitor.sh access.log 10 (sets threshold to 10MB)
if [ -n "$2" ] && [[ "$2" =~ ^[0-9]+$ ]]; then
    THRESHOLD_BYTES=$(($2 * 1024 * 1024))
    THRESHOLD_LABEL="$2 MB"
fi

# Print Banner
echo -e "${BLUE}"
echo "=========================================================="
echo "                 Log Size Monitor                         "
echo "=========================================================="
echo -e "${NC}"

# Check if log file exists
if [ ! -f "$LOG_FILE" ]; then
    log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
    log_error "Log file '$LOG_FILE' does not exist."
    echo -e "Usage: ./log_size_monitor.sh [path_to_log] [optional_threshold_in_MB]\n"
    
    # Offer to create a sample large file to test the script
    read -p "Would you like to generate a sample 5MB 'access.log' for testing? (y/N): " choice
    if [[ "$choice" =~ ^[yY]$ ]]; then
        echo -e "${BLUE}[INFO] Creating a 5MB 'access.log'...${NC}"
        # Write 5MB of dummy text
        dd if=/dev/zero of=access.log bs=1M count=5 &>/dev/null
        if [ $? -eq 0 ]; then
            log_success "Created 5MB 'access.log'. Run script as: ./log_size_monitor.sh access.log 2 (to set threshold to 2MB)."
        else
            # Fallback if dd is unavailable or fails
            for i in {1..80000}; do
                echo "192.168.1.10 - - [11/Jul/2026:10:00:00 +0200] \"GET /index.html HTTP/1.1\" 200 3426" >> access.log
            done
            log_success "Created sample 'access.log' (~6MB). Run script as: ./log_size_monitor.sh access.log 2"
        fi
        exit 0
    else
        exit 1
    fi
fi

# Helper function to convert bytes into human-readable size
format_size() {
    local b=${1:-0}
    if [ "$b" -ge 1073741824 ]; then
        echo "$(awk "BEGIN {printf \"%.2f\", $b/1073741824}") GB"
    elif [ "$b" -ge 1048576 ]; then
        echo "$(awk "BEGIN {printf \"%.2f\", $b/1048576}") MB"
    elif [ "$b" -ge 1024 ]; then
        echo "$(awk "BEGIN {printf \"%.2f\", $b/1024}") KB"
    else
        echo "$b Bytes"
    fi
}

# ------------------------------------------------------------------------------
# 3. Size Inspection
# ------------------------------------------------------------------------------
# Fetch size in bytes
size_bytes=$(wc -c < "$LOG_FILE" 2>/dev/null | tr -d ' ')
size_formatted=$(format_size "$size_bytes")
threshold_formatted=$(format_size "$THRESHOLD_BYTES")

echo -e "${YELLOW}File Target :${NC} $LOG_FILE"
echo -e "${YELLOW}Current Size:${NC} $size_formatted"
echo -e "${YELLOW}Limit Size  :${NC} $threshold_formatted"
echo "----------------------------------------------------------"

if [ "$size_bytes" -ge "$THRESHOLD_BYTES" ]; then
    log_warning "Log file '$LOG_FILE' has exceeded the threshold of $threshold_formatted!"
    
    # Prompt the user for compression
    read -p "Do you want to compress the log file now? (y/N): " confirm_compress
    
    case "$confirm_compress" in
        [yY]|[yY][eE][sS])
            echo -e "${BLUE}[INFO] Starting log rotation and compression...${NC}"
            
            # Timestamp for the rotated file
            timestamp=$(date +%Y%m%d_%H%M%S)
            rotated_file="${LOG_FILE}.${timestamp}"
            
            # Step A: Move the active log file to preserve state
            if mv "$LOG_FILE" "$rotated_file"; then
                # Step B: Recreate active log immediately so server writes are uninterrupted
                touch "$LOG_FILE"
                chmod 644 "$LOG_FILE" # standard readable file permissions
                
                # Step C: Compress the moved file
                echo -e "${BLUE}[INFO] Compressing rotated log '${rotated_file}' using gzip...${NC}"
                if gzip "$rotated_file"; then
                    compressed_file="${rotated_file}.gz"
                    compressed_bytes=$(wc -c < "$compressed_file" 2>/dev/null | tr -d ' ')
                    compressed_formatted=$(format_size "$compressed_bytes")
                    
                    log_success "Compression complete!"
                    echo -e "  - Rotated log: ${GREEN}${compressed_file}${NC}"
                    echo -e "  - Original Size: ${YELLOW}${size_formatted}${NC}"
                    echo -e "  - Compressed Size: ${GREEN}${compressed_formatted}${NC}"
                    echo -e "  - Fresh empty log recreated: ${GREEN}${LOG_FILE}${NC}"
                else
                    log_error "Compression failed during gzip execution."
                    # Rollback: rename back if compression failed and log is empty
                    if [ ! -s "$LOG_FILE" ]; then
                        mv "$rotated_file" "$LOG_FILE"
                        log_warning "Rolled back moved log file due to compression failure."
                    fi
                    exit 1
                fi
            else
                log_error "Failed to rotate log file. Check folder write permissions."
                exit 1
            fi
            ;;
        *)
            echo -e "${BLUE}[INFO] Compression cancelled by user. No action taken.${NC}"
            ;;
    esac
else
    log_success "Log file '$LOG_FILE' size is healthy. No compression needed."
fi

echo -e "\n${CYAN}==========================================================${NC}"
