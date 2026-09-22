#!/bin/bash

# ==============================================================================
# Script Name: system_update.sh
# Description: Updates Ubuntu/Debian systems (update, upgrade, autoremove, clean).
#              Checks if a system reboot is required post-upgrade and prompts 
#              the user to reboot.
#
# Educational Guide:
#   1. Package Management (APT):
#      - apt-get update: Synchronizes local package index files with sources.
#      - apt-get upgrade -y: Installs newest versions of all packages currently installed.
#      - apt-get autoremove -y: Removes packages that were automatically installed 
#        to satisfy dependencies for other packages and are now no longer needed.
#      - apt-get clean: Clears local repository of retrieved package files (.deb).
#   2. Non-interactive Upgrade:
#      - DEBIAN_FRONTEND=noninteractive avoids blockages by automatically accepting
#        default choices for configuration files and prompts.
#   3. Reboot Check:
#      - On Debian/Ubuntu, a reboot is required if the file
#        '/var/run/reboot-required' is created by the package manager.
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
# 2. Logging Utilities
# ------------------------------------------------------------------------------
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Print Banner
echo -e "${BLUE}"
echo "=========================================================="
echo "               Ubuntu/Debian System Updater               "
echo "=========================================================="
echo -e "${NC}"

# ------------------------------------------------------------------------------
# 3. Prerequisites Checks
# ------------------------------------------------------------------------------
# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log_error "Please run this script as root or with sudo."
    exit 1
fi

# Verify OS compatibility (Must be Debian-based)
if [ ! -f /etc/debian_version ]; then
    log_error "This script is optimized for Ubuntu/Debian. /etc/debian_version not found."
    exit 1
fi

# ------------------------------------------------------------------------------
# 4. System Update and Clean Routine
# ------------------------------------------------------------------------------
# Set frontend to non-interactive to prevent APT prompts from blocking execution
export DEBIAN_FRONTEND=noninteractive

# A. apt-get update
log_info "Updating package lists (apt-get update)..."
if apt-get update -y; then
    log_success "Package lists updated successfully."
else
    log_error "Failed to update package lists."
    exit 1
fi

# B. apt-get upgrade
log_info "Upgrading packages (apt-get upgrade)... This may take some time."
if apt-get upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"; then
    log_success "System packages upgraded successfully."
else
    log_error "Failed to upgrade system packages."
    exit 1
fi

# C. apt-get autoremove
log_info "Cleaning up unused dependencies (apt-get autoremove)..."
if apt-get autoremove -y; then
    log_success "Unused dependencies removed successfully."
else
    log_warning "Failed to run autoremove cleanly."
fi

# D. apt-get clean
log_info "Clearing local package cache (apt-get clean)..."
if apt-get clean; then
    log_success "Package cache cleared successfully."
else
    log_warning "Failed to clear package cache."
fi

# ------------------------------------------------------------------------------
# 5. Reboot Verification and User Prompt
# ------------------------------------------------------------------------------
echo -e "\n${CYAN}----------------------------------------------------------${NC}"
log_info "Checking if a system reboot is required..."

if [ -f /var/run/reboot-required ]; then
    echo -e "${YELLOW}"
    echo "=========================================================="
    echo "         ⚠️  SYSTEM REBOOT REQUIRED TO COMPLETE UPDATES ⚠️ "
    echo "=========================================================="
    echo -e "${NC}"
    
    # Check if we have packages triggering the reboot listed in the companion file
    if [ -f /var/run/reboot-required.pkgs ]; then
        log_info "Packages requiring reboot:"
        cat /var/run/reboot-required.pkgs
        echo ""
    fi
    
    # Prompt the user for reboot
    read -p "Do you want to reboot the server now? (y/N): " confirm_reboot
    
    case "$confirm_reboot" in
        [yY]|[yY][eE][sS])
            log_warning "Rebooting the server now. Closing connections..."
            sleep 2
            reboot
            ;;
        *)
            log_info "Reboot postponed. Please reboot the server manually at your earliest convenience."
            ;;
    esac
else
    log_success "All updates applied successfully. No system reboot is required."
fi

echo -e "\n${GREEN}============================================="
echo -e "         SYSTEM UPDATE ROUTINE FINISHED!"
echo -e "=============================================${NC}"
