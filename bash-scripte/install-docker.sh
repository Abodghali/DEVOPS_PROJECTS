#!/bin/bash

# ==============================================================================
# Script Name: install_docker_rhel.sh
# Description: Installs Docker CE on RHEL (Red Hat Enterprise Linux) and its derivatives.
# Author: Antigravity AI
# Date: May 2026
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. Variables Configuration (Adjust as needed)
# ------------------------------------------------------------------------------
# URL for the Docker CE repository (CentOS repo works perfectly for RHEL and its derivatives)
DOCKER_REPO_URL="https://download.docker.com/linux/centos/docker-ce.repo"

# Docker packages to install
DOCKER_PACKAGES="docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"

# Required prerequisites packages
PREREQUISITES="yum-utils device-mapper-persistent-data lvm2"

# Services to enable and start
SERVICES_TO_START="docker containerd"

# Group configuration
ADD_TO_DOCKER_GROUP=true
# If empty, defaults to the user who ran the script via sudo (SUDO_USER) or the current user
TARGET_USER="${SUDO_USER:-$USER}"

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
echo "      Docker CE Installer for RHEL & Derivatives          "
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
        log_info "Installation aborted by user."
        exit 0
    fi
else
    log_success "Compatible OS detected: $NAME ($VERSION)"
fi

# ------------------------------------------------------------------------------
# 4. Installation Steps
# ------------------------------------------------------------------------------
log_info "Updating package cache and installing prerequisites..."
dnf install -y $PREREQUISITES

log_info "Adding Docker CE repository from: ${DOCKER_REPO_URL}"
dnf config-manager --add-repo "${DOCKER_REPO_URL}"

log_info "Installing Docker CE components..."
dnf install -y $DOCKER_PACKAGES

log_info "Enabling and starting Docker/Containerd services..."
for service in $SERVICES_TO_START; do
    systemctl enable "$service"
    systemctl start "$service"
    log_success "Service '$service' enabled and started."
done

# ------------------------------------------------------------------------------
# 5. User Group Configuration
# ------------------------------------------------------------------------------
if [ "$ADD_TO_DOCKER_GROUP" = true ]; then
    log_info "Configuring Docker group membership..."
    if ! getent group docker > /dev/null; then
        groupadd docker
        log_success "Docker group created."
    fi

    if [ -n "$TARGET_USER" ] && [ "$TARGET_USER" != "root" ]; then
        usermod -aG docker "$TARGET_USER"
        log_success "User '$TARGET_USER' added to the 'docker' group."
        log_warning "Note: You will need to log out and log back in (or run 'newgrp docker') for the group changes to take effect."       
    else
        log_info "No non-root target user detected/specified to add to the docker group."
    fi
fi

# ------------------------------------------------------------------------------
# 6. Verification
# ------------------------------------------------------------------------------
echo -e "\n${BLUE}========== VERIFYING INSTALLATION ==========${NC}"
if docker --version &>/dev/null; then
    log_success "Docker client verified: $(docker --version)"
else
    log_error "Docker verification failed. Check the installation status."
fi

if systemctl is-active --quiet docker; then
    log_success "Docker service is active and running."
else
    log_error "Docker service is not running."
fi

if docker compose version &>/dev/null; then
    log_success "Docker Compose plugin verified: $(docker compose version)"
fi

echo -e "\n${GREEN}============================================="
echo -e "       INSTALLATION COMPLETED SUCCESSFULLY!"
echo -e "=============================================${NC}"