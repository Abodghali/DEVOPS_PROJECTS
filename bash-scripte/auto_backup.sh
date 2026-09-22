#!/bin/bash

# ==============================================================================
# Script Name: auto_backup.sh
# Description: Automatically creates a timestamped compressed backup of a specified
#              directory and manages backup retention.
#
#
#
# Educational Guide:
#   1. mkdir -p :
#      - mkdir (Make Directory) creates a new folder.
#      - -p (Parents) automatically creates any missing parent directories and 
#        prevents errors if the directory already exists.
#
#   2. date :
#      - Used to retrieve and format the current date and time.
#      - +%Y-%m-%d outputs the date as YYYY-MM-DD (e.g., 2026-07-04).
#
#   3. tar :
#      - tar (Tape Archive) bundles multiple files or folders into a single archive file.
#      - -c: Create a new archive.
#      - -f: Specify the archive file name.
#      - -C: Changes the directory before performing the tar operation (useful for keeping paths relative).
#
#   4. gzip :
#      - gzip (GNU zip) compresses the .tar archive to significantly reduce its size, producing a .tar.gz file.
#      - You can do this in two steps:
#          tar -cf backup.tar folder/
#          gzip backup.tar
#      - Or in a single step using the -z flag in tar (which filters the archive through gzip):
#          tar -czf backup.tar.gz folder/
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. Configuration
# ------------------------------------------------------------------------------
# Default directory to back up (Change to your desired production target folder)
DEFAULT_SOURCE="/home/projects"

# Default directory to store the backup files
DEFAULT_DEST="/var/backups"

# Retention policy: Number of days to keep backups before deleting them
RETENTION_DAYS=7

# Log file path to log backup activities
LOG_FILE="/var/log/backup.log"

# Enable console printing
VERBOSE=true

# ------------------------------------------------------------------------------
# 2. Colors for Console Output
# ------------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ------------------------------------------------------------------------------
# 3. Logging Utilities
# ------------------------------------------------------------------------------
log_info() {
    [ "$VERBOSE" = true ] && echo -e "${BLUE}[INFO]${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $1" >> "$LOG_FILE" 2>/dev/null || true
}

log_warning() {
    [ "$VERBOSE" = true ] && echo -e "${YELLOW}[WARNING]${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [WARNING] $1" >> "$LOG_FILE" 2>/dev/null || true
}

log_error() {
    [ "$VERBOSE" = true ] && echo -e "${RED}[ERROR]${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $1" >> "$LOG_FILE" 2>/dev/null || true
}

log_success() {
    [ "$VERBOSE" = true ] && echo -e "${GREEN}[SUCCESS]${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [SUCCESS] $1" >> "$LOG_FILE" 2>/dev/null || true
}

# ------------------------------------------------------------------------------
# 4. Backup Logic
# ------------------------------------------------------------------------------
perform_backup() {
    local source_dir="${1:-$DEFAULT_SOURCE}"
    local dest_dir="${2:-$DEFAULT_DEST}"
    
    log_info "Starting backup process..."
    log_info "Source Directory: $source_dir"
    log_info "Destination Directory: $dest_dir"
    
    # Check if the source directory exists
    if [ ! -d "$source_dir" ]; then
        log_error "Source directory '$source_dir' does not exist. Backup aborted."
        exit 1
    fi
    
    # 1. Use mkdir -p to ensure destination directory exists
    log_info "Checking destination directory..."
    mkdir -p "$dest_dir"
    if [ $? -ne 0 ]; then
        log_error "Failed to create destination directory '$dest_dir'. Check permissions."
        exit 1
    fi
    
    # 2. Use date to generate the timestamped filename
    local current_date=$(date '+%Y-%m-%d')
    local backup_filename="backup-${current_date}.tar.gz"
    local backup_filepath="${dest_dir}/${backup_filename}"
    
    # 3 & 4. Use tar and gzip to archive and compress
    log_info "Creating compressed backup archive..."
    
    # Extract parent directory and base name to keep paths relative inside the archive
    # (Avoiding the "tar: Removing leading '/' from member names" warning)
    local parent_dir=$(dirname "$source_dir")
    local base_dir=$(basename "$source_dir")
    
    # Perform archiving and compression using 'tar -czf'
    # -c (create), -z (gzip compress), -f (specify archive file)
    tar -czf "$backup_filepath" -C "$parent_dir" "$base_dir"
    
    # Verify backup file creation and size
    if [ $? -eq 0 ] && [ -f "$backup_filepath" ]; then
        # Using awk to extract file size from du output
        local file_size=$(du -sh "$backup_filepath" | awk '{print $1}')
        log_success "Backup completed successfully!"
        log_info "Archive File: $backup_filepath"
        log_info "Archive Size: $file_size"
    else
        log_error "Backup compression failed."
        exit 1
    fi
    
    # Apply backup retention rules
    cleanup_old_backups "$dest_dir"
}

# ------------------------------------------------------------------------------
# 5. Backup Retention Cleanup
# ------------------------------------------------------------------------------
cleanup_old_backups() {
    local dest_dir="$1"
    log_info "Checking for backups older than $RETENTION_DAYS days..."
    
    if [ -d "$dest_dir" ]; then
        # Find files matching the backup pattern that are older than RETENTION_DAYS
        local old_backups=$(find "$dest_dir" -name "backup-*.tar.gz" -type f -mtime +"$RETENTION_DAYS")
        
        if [ -n "$old_backups" ]; then
            log_warning "Found old backups to delete:"
            echo "$old_backups" | while read -r file; do
                if [ -n "$file" ]; then
                    rm -f "$file"
                    log_success "Deleted old backup: $(basename "$file")"
                fi
            done
        else
            log_info "No old backups found to clean up."
        fi
    fi
}

# ------------------------------------------------------------------------------
# 6. Execution Options
# ------------------------------------------------------------------------------
# How to run:
#   ./auto_backup.sh                          # Runs using default settings
#   ./auto_backup.sh /path/to/src /path/to/dst # Runs with custom folders

perform_backup "$1" "$2"
