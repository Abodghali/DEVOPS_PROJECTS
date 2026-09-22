#!/bin/bash

# ==============================================================================
# Script Name: clean_logs.sh
# Description: Cleans up log files older than a specified number of days (e.g., 30 days).
#              Includes a safe dry-run mode.
#
#
#
# Educational Guide:
#   1. find [path] [expression] :
#      - Searches for files in a directory hierarchy.
#      - -type f: Restricts search results to regular files (ignores directories/links).
#      - -name "*.log": Matches files ending with the .log extension.
#
#   2. -mtime (Modification Time) :
#      - Filters files based on the number of days since their contents were last modified.
#      - +30: Modified strictly more than 30 days ago (older than 30 days).
#      - -30: Modified strictly less than 30 days ago (newer than 30 days).
#      -  30: Modified exactly 30 days ago.
#
#   3. -delete :
#      - Safely deletes matched files directly within the find command execution.
#      - WARNING: Always place -delete at the very END of your find command expression.
#        Because find evaluates arguments from left-to-right, placing -delete before
#        other flags (like -name) will cause it to delete files before evaluating the match!
#      - It is highly recommended to run without -delete (using -print or standard output)
#        first to verify which files will be deleted.
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. Configuration
# ------------------------------------------------------------------------------
# Default directory containing system logs
DEFAULT_LOG_DIR="/var/log"

# Age threshold in days (delete files older than this)
DEFAULT_DAYS=30

# File patterns to target (space-separated)
FILE_PATTERNS="*.log *.txt"

# Enable console printing
VERBOSE=true

# Log file to record cleanup runs
CLEANUP_LOG="/var/log/log_cleanup.log"

# ------------------------------------------------------------------------------
# 2. Colors for Output
# ------------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ------------------------------------------------------------------------------
# 3. Log Functions
# ------------------------------------------------------------------------------
log_info() {
    [ "$VERBOSE" = true ] && echo -e "${BLUE}[INFO]${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $1" >> "$CLEANUP_LOG" 2>/dev/null || true
}

log_warning() {
    [ "$VERBOSE" = true ] && echo -e "${YELLOW}[WARNING]${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [WARNING] $1" >> "$CLEANUP_LOG" 2>/dev/null || true
}

log_error() {
    [ "$VERBOSE" = true ] && echo -e "${RED}[ERROR]${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $1" >> "$CLEANUP_LOG" 2>/dev/null || true
}

log_success() {
    [ "$VERBOSE" = true ] && echo -e "${GREEN}[SUCCESS]${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [SUCCESS] $1" >> "$CLEANUP_LOG" 2>/dev/null || true
}

# ------------------------------------------------------------------------------
# 4. Cleanup Logic
# ------------------------------------------------------------------------------
clean_logs() {
    local target_dir="${1:-$DEFAULT_LOG_DIR}"
    local days="${2:-$DEFAULT_DAYS}"
    local dry_run="$3"
    
    log_info "Target Directory: $target_dir"
    log_info "Threshold: Older than $days days"
    
    # Check if target directory exists
    if [ ! -d "$target_dir" ]; then
        log_error "Target directory '$target_dir' does not exist. Cleanup aborted."
        exit 1
    fi
    
    # Check if target directory is writeable (unless dry-run is enabled)
    if [ "$dry_run" = false ] && [ ! -w "$target_dir" ]; then
        log_warning "Directory '$target_dir' is not writable by current user. Execution might fail if root/sudo is needed."
    fi
    
    log_info "Scanning for files matching: $FILE_PATTERNS..."
    
    # Build search expressions for multiple target patterns dynamically
    # Example expansion: \( -name "*.log" -o -name "*.txt" \)
    local pattern_args=()
    local is_first=true
    for pattern in $FILE_PATTERNS; do
        if [ "$is_first" = true ]; then
            pattern_args+=("-name" "$pattern")
            is_first=false
        else
            pattern_args+=("-o" "-name" "$pattern")
        fi
    done
    
    # Scan files matching criteria
    local files_found
    files_found=$(find "$target_dir" -type f \( "${pattern_args[@]}" \) -mtime +"$days" 2>/dev/null)
    
    if [ -z "$files_found" ]; then
        log_success "No log files older than $days days found. Nothing to clean."
        return 0
    fi
    
    local count
    count=$(echo "$files_found" | wc -l)
    
    if [ "$dry_run" = true ]; then
        log_warning "=== DRY RUN MODE: Listing files that would be deleted (Total: $count) ==="
        echo "$files_found" | while read -r file; do
            if [ -n "$file" ]; then
                local size=$(du -sh "$file" 2>/dev/null | awk '{print $1}')
                local mtime=$(date -r "$file" "+%Y-%m-%d %H:%M:%S" 2>/dev/null)
                echo -e "  - ${file} [Size: ${size:-unknown}] [Modified: ${mtime:-unknown}]"
            fi
        done
        log_warning "=== DRY RUN COMPLETED: No files were actually deleted ==="
    else
        log_info "Deleting $count files..."
        
        # Perform deletions using find's built-in -delete flag
        find "$target_dir" -type f \( "${pattern_args[@]}" \) -mtime +"$days" -delete 2>/dev/null
        
        if [ $? -eq 0 ]; then
            log_success "Log cleanup completed successfully! Deleted $count files."
        else
            log_error "Cleanup process encountered errors (some files may require root permissions)."
        fi
    fi
}

# ------------------------------------------------------------------------------
# 5. Argument Parsing and Execution
# ------------------------------------------------------------------------------
# Usage options:
#   ./clean_logs.sh                          # Deletes files older than 30 days in /var/log
#   ./clean_logs.sh --dry-run                # Lists files that would be deleted in /var/log
#   ./clean_logs.sh [path] [days]            # Deletes files in [path] older than [days]
#   ./clean_logs.sh [path] [days] --dry-run  # Lists files in [path] older than [days] without deleting

DRY_RUN=false
TARGET_DIR="$DEFAULT_LOG_DIR"
DAYS="$DEFAULT_DAYS"

# Detect dry-run flag
for arg in "$@"; do
    if [ "$arg" = "--dry-run" ]; then
        DRY_RUN=true
    fi
done

# Extract positional arguments (ignoring dry-run flags)
args=()
for arg in "$@"; do
    if [ "$arg" != "--dry-run" ]; then
        args+=("$arg")
    fi
done

if [ ${#args[@]} -ge 1 ]; then
    TARGET_DIR="${args[0]}"
fi
if [ ${#args[@]} -ge 2 ]; then
    DAYS="${args[1]}"
fi

clean_logs "$TARGET_DIR" "$DAYS" "$DRY_RUN"
