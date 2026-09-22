#!/bin/bash

# ==============================================================================
# Script Name: setup_rhel_repos.sh
# Description: Configures BaseOS and AppStream YUM/DNF repositories on RHEL.
# Author: Antigravity AI
# Date: May 2026
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. Variables Configuration (Adjust as needed)
# ------------------------------------------------------------------------------
# Choose repository type: "local" (ISO mount) or "custom" (HTTP/HTTPS mirror) or "public" (Rocky Linux mirrors)
REPO_MODE="public"

# If REPO_MODE="local":
# Absolute path to the RHEL ISO file on your server (if you want the script to mount it automatically)
# Example: ISO_FILE_PATH="/home/user/rhel-baseos-9.x-x86_64-dvd.iso"
# Leave empty if you are using a physical/virtual DVD drive (e.g. /dev/sr0)
ISO_FILE_PATH="home/user/rhel-9-dvd.iso"

# Mount path where the RHEL ISO/DVD will be mounted
ISO_MOUNT_PATH="/mnt/rhel"

# Custom HTTP/HTTPS server URLs (used if REPO_MODE="custom")
CUSTOM_BASEOS_URL="http://mirror.example.com/rhel/BaseOS"
CUSTOM_APPSTREAM_URL="http://mirror.example.com/rhel/AppStream"

# Public Rocky Linux version to use as base (used if REPO_MODE="public")
# Options: 9 (for RHEL 9), 8 (for RHEL 8)
PUBLIC_OS_MAJOR_VERSION="9"
PUBLIC_MIRROR_BASE_URL="https://dl.rockylinux.org/pub/rocky"

# Backup existing repository configurations in /etc/yum.repos.d/ before starting
BACKUP_EXISTING=true
BACKUP_DIR="/etc/yum.repos.d/backup_$(date +%Y%m%d_%H%M%S)"

# GPG checks for local/custom repos (1 = enabled, 0 = disabled)
GPG_CHECK=0

# ------------------------------------------------------------------------------
# 2. Initialization and Functions
# ------------------------------------------------------------------------------
# Exit immediately if a command exits with a non-zero status
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging utilities
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
echo "      RHEL YUM / DNF Repository Setup Script             "
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

# Check OS compatibility
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID=$ID
    OS_LIKE=$ID_LIKE
else
    log_error "Cannot determine the OS version. /etc/os-release not found."
    exit 1
fi

# Check if OS is RHEL-like
if [[ "$OS_ID" != "rhel" && "$OS_ID" != "centos" && "$OS_ID" != "rocky" && "$OS_ID" != "almalinux" && "$OS_LIKE" != *"rhel"* ]]; then     
    log_warning "This script is optimized for RHEL/CentOS/Rocky/AlmaLinux. Detected: $NAME"
    read -p "Do you want to proceed anyway? (y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        log_info "Configuration aborted by user."
        exit 0
    fi
fi

# ------------------------------------------------------------------------------
# 4. Backup Existing Repositories
# ------------------------------------------------------------------------------
if [ "$BACKUP_EXISTING" = true ]; then
    log_info "Creating backup of existing repositories in ${BACKUP_DIR}..."
    mkdir -p "$BACKUP_DIR"
    find /etc/yum.repos.d/ -maxdepth 1 -name "*.repo" -exec mv {} "$BACKUP_DIR/" \; || true
    log_success "Backup completed."
fi

# ------------------------------------------------------------------------------
# 5. Configure Repositories Based on Selected Mode
# ------------------------------------------------------------------------------
case $REPO_MODE in
    local)
        log_info "Configuring repository using local mount point: ${ISO_MOUNT_PATH}"

        # Verify or mount the ISO/DVD
        if [ ! -d "$ISO_MOUNT_PATH/BaseOS" ] || [ ! -d "$ISO_MOUNT_PATH/AppStream" ]; then
            log_warning "Could not find 'BaseOS' or 'AppStream' directories inside '$ISO_MOUNT_PATH'."
            mkdir -p "$ISO_MOUNT_PATH"

            if [ -n "$ISO_FILE_PATH" ]; then
                if [ -f "$ISO_FILE_PATH" ]; then
                    log_info "Attempting to mount ISO file '${ISO_FILE_PATH}' to '${ISO_MOUNT_PATH}'..."
                    if mount -o loop "$ISO_FILE_PATH" "$ISO_MOUNT_PATH" &>/dev/null; then
                        log_success "Successfully mounted ISO file to $ISO_MOUNT_PATH"
                    else
                        log_error "Failed to mount ISO file '${ISO_FILE_PATH}'."
                        exit 1
                    fi
                else
                    log_error "ISO file path '${ISO_FILE_PATH}' was specified, but the file does not exist."
                    exit 1
                fi
            else
                log_info "Attempting to mount CD/DVD device to '${ISO_MOUNT_PATH}'..."
                if mount /dev/sr0 "$ISO_MOUNT_PATH" &>/dev/null || mount /dev/cdrom "$ISO_MOUNT_PATH" &>/dev/null; then
                    log_success "Successfully mounted DVD drive to $ISO_MOUNT_PATH"
                else
                    log_error "Failed to mount device. Please specify an 'ISO_FILE_PATH' or mount the ISO/DVD at '${ISO_MOUNT_PATH}' manually and try again."
                    exit 1
                fi
            fi
        fi

        # Create repo file
        cat <<EOF > /etc/yum.repos.d/rhel_local.repo
[local-baseos]
name=Red Hat Enterprise Linux - BaseOS (Local ISO)
baseurl=file://${ISO_MOUNT_PATH}/BaseOS
enabled=1
gpgcheck=${GPG_CHECK}

[local-appstream]
name=Red Hat Enterprise Linux - AppStream (Local ISO)
baseurl=file://${ISO_MOUNT_PATH}/AppStream
enabled=1
gpgcheck=${GPG_CHECK}
EOF
        log_success "Local ISO repository file configured."
        ;;

    custom)
        log_info "Configuring repository using custom URLs..."
        cat <<EOF > /etc/yum.repos.d/rhel_custom.repo
[custom-baseos]
name=Red Hat Enterprise Linux - BaseOS (Custom Mirror)
baseurl=${CUSTOM_BASEOS_URL}
enabled=1
gpgcheck=${GPG_CHECK}

[custom-appstream]
name=Red Hat Enterprise Linux - AppStream (Custom Mirror)
baseurl=${CUSTOM_APPSTREAM_URL}
enabled=1
gpgcheck=${GPG_CHECK}
EOF
        log_success "Custom repository file configured."
        ;;

    public)
        log_info "Configuring repository using public Rocky Linux mirrors (compatible with RHEL ${PUBLIC_OS_MAJOR_VERSION})..."
        cat <<EOF > /etc/yum.repos.d/rhel_public.repo
[public-baseos]
name=Rocky Linux ${PUBLIC_OS_MAJOR_VERSION} - BaseOS (Public Mirror)
baseurl=${PUBLIC_MIRROR_BASE_URL}/${PUBLIC_OS_MAJOR_VERSION}/BaseOS/\$basearch/os/
gpgcheck=1
gpgkey=https://dl.rockylinux.org/pub/rocky/RPM-GPG-KEY-Rocky-${PUBLIC_OS_MAJOR_VERSION}
enabled=1

[public-appstream]
name=Rocky Linux ${PUBLIC_OS_MAJOR_VERSION} - AppStream (Public Mirror)
baseurl=${PUBLIC_MIRROR_BASE_URL}/${PUBLIC_OS_MAJOR_VERSION}/AppStream/\$basearch/os/
gpgcheck=1
gpgkey=https://dl.rockylinux.org/pub/rocky/RPM-GPG-KEY-Rocky-${PUBLIC_OS_MAJOR_VERSION}
enabled=1
EOF
        log_success "Public mirror repository file configured."
        ;;

    *)
        log_error "Unknown REPO_MODE: '${REPO_MODE}'. Please select 'local', 'custom', or 'public'."
        exit 1
        ;;
esac

# ------------------------------------------------------------------------------
# 6. Verify and Cache
# ------------------------------------------------------------------------------
log_info "Cleaning DNF/YUM cache..."
dnf clean all

log_info "Rebuilding metadata cache..."
if dnf makecache; then
    log_success "Cache rebuilt successfully."
else
    log_warning "Could not rebuild cache completely. Please check your network/mount configurations."
fi

echo -e "\n${BLUE}========== ENABLED REPOSITORIES ==========${NC}"
dnf repolist

echo -e "\n${GREEN}============================================="
echo -e "       REPOSITORY SETUP COMPLETED!"
echo -e "=============================================${NC}"