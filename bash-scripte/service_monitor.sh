#!/bin/bash

# ==============================================================================
# Script Name: service_monitor.sh
# Description: Monitors critical system services (e.g., nginx, docker, mysql)
#              and automatically restarts them if they are down, logging the events.
#
#
#
# Educational Guide:
#   1. systemctl :
#      - The primary command-line tool to inspect and control the state of the 
#        "systemd" system and service manager.
#
#   2. systemctl is-active [service] :
#      - Checks whether the specified service unit is currently active (running).
#      - Returns an exit status code of 0 if running, or a non-zero code if it is stopped,
#        failed, or inactive.
#      - The --quiet flag suppresses standard output, which is useful in shell scripts
#        to check the exit status without displaying raw console logs.
#
#   3. systemctl restart [service] :
#      - Stops the specified service and then starts it again.
#      - Useful for automatic recovery scripts to reload failed services.
#
#   4. EUID Check ($EUID) :
#      - An environmental variable holding the Effective User ID of the current shell user.
#      - Root user always has a UID of 0. Since restarting system services requires root
#        privileges, checking if $EUID equals 0 ensures the script has permission to act.
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. Configuration
# ------------------------------------------------------------------------------
# Default list of system services to monitor (space-separated)
DEFAULT_SERVICES="nginx docker mysql"

# Path to the log file recording check statuses and recovery actions
LOG_FILE="/var/log/service_monitor.log"

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
# 4. Service Recovery Logic
# ------------------------------------------------------------------------------
monitor_services() {
    local services_list="$1"
    local status_only="$2"
    
    log_info "Starting service monitoring check..."
    
    # Service control (start/restart) requires administrative privileges
    if [ "$status_only" = false ] && [ "$EUID" -ne 0 ]; then
        log_error "This script must be run as root or with sudo to perform service restarts."
        exit 1
    fi
    
    for service in $services_list; do
        log_info "Checking service status: $service..."
        
        # Check if the service file is actually installed in systemd
        if ! systemctl list-unit-files --type=service | grep -Fq "${service}.service" 2>/dev/null; then
            log_warning "Service '$service' is not installed or loaded on this system. Skipping."
            continue
        fi
        
        # 1. Use systemctl is-active to query status
        if systemctl is-active --quiet "$service"; then
            log_success "Service '$service' is active and running."
        else
            log_warning "Service '$service' is DOWN!"
            
            # If status_only flag is set, do not attempt to start the service
            if [ "$status_only" = true ]; then
                log_info "Status-only mode active. Skipping restart."
                continue
            fi
            
            # Log the service failure event
            log_error "ALERT: Service '$service' is stopped. Initiating automatic recovery restart..."
            
            # 2. Attempt service restart
            systemctl restart "$service" 2>/dev/null
            
            # Verify if recovery was successful
            if systemctl is-active --quiet "$service"; then
                log_success "Service '$service' successfully restarted and is now running."
            else
                log_error "CRITICAL: Automatic recovery failed for '$service'. Manual intervention required."
            fi
        fi
    done
    
    log_info "Service monitoring check completed."
}

# ------------------------------------------------------------------------------
# 5. Argument Parsing and Execution
# ------------------------------------------------------------------------------
# How to run:
#   ./service_monitor.sh                         # Checks default services, restarts if down (requires sudo)
#   ./service_monitor.sh --status                # Checks and displays status only (no root required)
#   ./service_monitor.sh apache2 sshd            # Monitors custom services (requires sudo)
#   ./service_monitor.sh apache2 sshd --status   # Checks custom services in status-only mode

STATUS_ONLY=false
SERVICES_TO_CHECK=""

# Detect status flag
for arg in "$@"; do
    if [ "$arg" = "--status" ]; then
        STATUS_ONLY=true
    fi
done

# Extract custom service names
for arg in "$@"; do
    if [ "$arg" != "--status" ]; then
        SERVICES_TO_CHECK+="$arg "
    fi
done

# Fallback to default service list if none specified
if [ -z "$SERVICES_TO_CHECK" ]; then
    SERVICES_TO_CHECK="$DEFAULT_SERVICES"
fi

monitor_services "$SERVICES_TO_CHECK" "$STATUS_ONLY"
