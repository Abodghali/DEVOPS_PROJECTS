#!/bin/bash

# ==============================================================================
# Script Name: docker_clean.sh
# Description: Automatically cleans up unused Docker resources (stopped containers,
#              unused networks, dangling images, and optionally all unused images
#              and volumes) to reclaim disk space.
#
# Educational Guide:
#   1. docker system prune :
#      - The main command to clean up Docker resources.
#      - By default, it removes:
#        * Stopped containers.
#        * Networks not used by at least one container.
#        * Dangling images (images without tags and not referenced by containers).
#        * Dangling build cache.
#
#   2. Key Flags:
#      - -f, --force : Bypasses the interactive confirmation prompt ("Are you sure?"),
#                      making it safe for automation and cron jobs.
#      - -a, --all   : Removes all unused images (not just dangling ones).
#      - --volumes   : Removes all unused volumes (disabled by default to prevent
#                      accidental data loss).
#
#   3. Docker Daemon Status Checks:
#      - command -v docker : Checks if the docker executable is installed.
#      - docker info : Verifies if the Docker daemon is active and running.
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. Configuration
# ------------------------------------------------------------------------------
# Set to true to clean ALL unused images, not just dangling ones (docker system prune -a)
CLEAN_ALL_IMAGES=true

# Set to true to clean unused volumes (CAUTION: might delete persistent database data if not active)
CLEAN_VOLUMES=false

# Log file path to record cleanups
LOG_FILE="/var/log/docker_clean.log"

# Enable console printing (true/false)
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
# 4. Clean Docker Function
# ------------------------------------------------------------------------------
clean_docker() {
    log_info "Verifying Docker environment..."

    # 1. Check if Docker command-line tool is installed
    if ! command -v docker >/dev/null 2>&1; then
        log_error "Docker is not installed on this system."
        return 1
    fi

    # 2. Check if the Docker daemon is running
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker daemon is not running. Please start the Docker service."
        return 1
    fi

    log_success "Docker is active. Proceeding with cleanup..."

    # Build the prune command arguments
    local prune_args="-f" # Force flag to bypass interactive prompt

    if [ "$CLEAN_ALL_IMAGES" = true ]; then
        prune_args+=" -a"
        log_info "Configuration: Will delete ALL unused images (not just dangling ones)."
    else
        log_info "Configuration: Will delete dangling images only."
    fi

    if [ "$CLEAN_VOLUMES" = true ]; then
        prune_args+=" --volumes"
        log_warning "Configuration: Unused volumes WILL be deleted. Make sure no important persistent data is lost."
    fi

    log_info "Executing: docker system prune $prune_args"

    # Execute the prune command and capture the output
    local prune_output
    prune_output=$(docker system prune $prune_args 2>&1)
    local exit_code=$?

    if [ $exit_code -eq 0 ]; then
        # Print output to console
        if [ "$VERBOSE" = true ]; then
            echo "$prune_output"
        fi
        
        # Log prune output to logfile
        echo "$prune_output" >> "$LOG_FILE" 2>/dev/null || true

        # Extract reclaimed space info if available in output
        local reclaimed_space
        reclaimed_space=$(echo "$prune_output" | grep -i "Total reclaimed space" || true)
        
        if [ -n "$reclaimed_space" ]; then
            log_success "Docker cleanup completed successfully. $reclaimed_space"
        else
            log_success "Docker cleanup completed successfully."
        fi
    else
        log_error "Docker system prune failed with error code $exit_code."
        echo "$prune_output" >> "$LOG_FILE" 2>/dev/null || true
        return 1
    fi
}

# ------------------------------------------------------------------------------
# 5. Main Execution and Arguments
# ------------------------------------------------------------------------------
# Options:
#   ./docker_clean.sh          # Default clean (using variables above)
#   ./docker_clean.sh --deep   # Deletes ALL unused images and volumes
#   ./docker_clean.sh --help   # Prints usage instructions

case "$1" in
    --deep)
        log_warning "=== RUNNING DEEP CLEAN ==="
        CLEAN_ALL_IMAGES=true
        CLEAN_VOLUMES=true
        clean_docker
        ;;
    --help)
        echo "Usage:"
        echo "  ./docker_clean.sh          - Standard clean (stopped containers, unused networks, and images)"
        echo "  ./docker_clean.sh --deep   - Deep clean (includes all unused images and unused volumes)"
        echo "  ./docker_clean.sh --help   - Show this help message"
        ;;
    *)
        clean_docker
        ;;
esac
