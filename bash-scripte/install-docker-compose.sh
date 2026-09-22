#!/bin/bash

# ==============================================================================
# Script Name: install-docker-compose.sh
# Description: Installs Docker Compose (Standalone or Plugin) on RHEL and its derivatives.
# Author: Antigravity AI
# Date: May 2026
# ==============================================================================

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
echo "    Docker Compose Installer for RHEL & Derivatives       "
echo "=========================================================="
echo -e "${NC}"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log_error "Please run this script as root or with sudo."
    exit 1
fi

# Function to install standalone Docker Compose binary
install_standalone() {
    log_info "Installing standalone Docker Compose binary..."

    # Check for curl or wget
    if ! command -v curl &> /dev/null; then
        log_info "curl is not installed. Installing curl..."
        dnf install -y curl || yum install -y curl
    fi

    # Detect architecture
    ARCH=$(uname -m)
    log_info "Detected system architecture: $ARCH"

    # Map architecture to Docker Compose naming convention
    case "$ARCH" in
        x86_64)  COMPOSE_ARCH="x86_64" ;;
        aarch64|arm64) COMPOSE_ARCH="aarch64" ;;
        ppc64le) COMPOSE_ARCH="ppc64le" ;;
        s390x)   COMPOSE_ARCH="s390x" ;;
        *)
            log_error "Unsupported architecture: $ARCH"
            exit 1
            ;;
    esac

    # Fetch latest Docker Compose version dynamically
    log_info "Fetching the latest version of Docker Compose from GitHub API..."
    LATEST_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

    if [ -z "$LATEST_VERSION" ]; then
        # Fallback to a stable version if GitHub API request fails or is rate-limited
        LATEST_VERSION="v2.29.1"
        log_warning "Failed to fetch latest version from GitHub API. Falling back to stable version: $LATEST_VERSION"
    else
        log_success "Found latest version: $LATEST_VERSION"
    fi

    DOWNLOAD_URL="https://github.com/docker/compose/releases/download/${LATEST_VERSION}/docker-compose-linux-${COMPOSE_ARCH}"
    DEST_PATH="/usr/local/bin/docker-compose"
    SYMLINK_PATH="/usr/bin/docker-compose"

    log_info "Downloading Docker Compose from: $DOWNLOAD_URL"
    curl -SL "$DOWNLOAD_URL" -o "$DEST_PATH"

    log_info "Applying executable permissions to $DEST_PATH..."
    chmod +x "$DEST_PATH"

    # Create symlink in /usr/bin if it doesn't exist for compatibility
    if [ ! -L "$SYMLINK_PATH" ] && [ ! -f "$SYMLINK_PATH" ]; then
        log_info "Creating symlink from $DEST_PATH to $SYMLINK_PATH..."
        ln -s "$DEST_PATH" "$SYMLINK_PATH"
    fi

    # Verify installation
    if docker-compose --version &>/dev/null; then
        log_success "Standalone Docker Compose verified: $(docker-compose --version)"
    else
        log_error "Standalone Docker Compose installation verification failed."
        exit 1
    fi
}

# Function to install Docker Compose plugin (via Docker repository)
install_plugin() {
    log_info "Installing Docker Compose Plugin (docker-compose-plugin)..."

    # Check if Docker CE repository is already set up
    if ! yum repolist | grep -q "docker-ce"; then
        log_warning "Docker CE repository not found. Adding it now..."
        if ! command -v dnf &> /dev/null; then
            yum install -y yum-utils
            yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        else
            dnf install -y yum-utils
            dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        fi
    fi

    log_info "Installing docker-compose-plugin via package manager..."
    if ! command -v dnf &> /dev/null; then
        yum install -y docker-compose-plugin
    else
        dnf install -y docker-compose-plugin
    fi

    # Create a symlink docker-compose -> docker compose for backward compatibility
    SYMLINK_PATH="/usr/bin/docker-compose"
    if [ ! -L "$SYMLINK_PATH" ] && [ ! -f "$SYMLINK_PATH" ]; then
        log_info "Creating symbolic link /usr/bin/docker-compose to allow running 'docker-compose'..."
        # Locate the plugin path
        PLUGIN_PATH="/usr/libexec/docker/cli-plugins/docker-compose"
        if [ -f "$PLUGIN_PATH" ]; then
            ln -s "$PLUGIN_PATH" "$SYMLINK_PATH"
        fi
    fi

    # Verify installation
    if docker compose version &>/dev/null; then
        log_success "Docker Compose Plugin verified: $(docker compose version)"
    else
        log_error "Docker Compose Plugin installation verification failed."
        exit 1
    fi
}

# ------------------------------------------------------------------------------
# Selection Flow
# ------------------------------------------------------------------------------
echo "Choose how you want to install Docker Compose:"
echo "1) Standalone Binary (Installs /usr/local/bin/docker-compose)"
echo "2) Docker Compose Plugin (Requires Docker repository, run via 'docker compose')"
echo "3) Both (Standalone and Plugin)"
read -p "Enter choice [1-3] (Default is 1): " choice

case "$choice" in
    2)
        install_plugin
        ;;
    3)
        install_standalone
        install_plugin
        ;;
    *)
        install_standalone
        ;;
esac

echo -e "\n${GREEN}============================================="
echo -e "       INSTALLATION COMPLETED SUCCESSFULLY!"
echo -e "=============================================${NC}"
