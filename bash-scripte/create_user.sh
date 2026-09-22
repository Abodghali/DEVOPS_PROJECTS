#!/bin/bash

# ==============================================================================
# Script Name: create_user.sh
# Description: Interactive script to create a new Linux user and set their password.
#
# Educational Guide:
#   1. useradd Command:
#      - Used to create a new user.
#      - -m option: Creates the user's home directory.
#   2. passwd Command:
#      - Sets/changes a user's password.
#      - In automation scripts, we feed the password via stdin to passwd,
#        or use chpasswd. Here we use passwd with standard input piping,
#        which is cross-platform.
#   3. Secure Password Input (read -s):
#      - Prevents the password characters from being displayed on the screen.
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. Colors for Console Output
# ------------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
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
echo "               Linux User Creation Script                 "
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

# ------------------------------------------------------------------------------
# 4. User Interaction
# ------------------------------------------------------------------------------
# Prompt for Username
read -p "Username: " username

# Validate Username is not empty
if [ -z "$username" ]; then
    log_error "Username cannot be empty."
    exit 1
fi

# Validate Username format
if [[ ! "$username" =~ ^[a-zA-Z_][a-zA-Z0-9_-]*$ ]]; then
    log_error "Invalid username format. Must start with a letter or underscore."
    exit 1
fi

# Check if user already exists
if id "$username" &>/dev/null; then
    log_warning "User '$username' already exists."
    exit 1
fi

# Prompt for Password (securely, characters not echoed)
read -sp "Password: " password
echo "" # For newline after hidden input

# Validate Password is not empty
if [ -z "$password" ]; then
    log_error "Password cannot be empty."
    exit 1
fi

# ------------------------------------------------------------------------------
# 5. User Creation & Password Configuration
# ------------------------------------------------------------------------------
log_info "Creating user '$username' using 'useradd'..."
if useradd -m "$username"; then
    log_success "User '$username' created successfully."
else
    log_error "Failed to create user '$username'."
    exit 1
fi

log_info "Setting password for '$username' using 'passwd'..."
# Set the password using passwd (compatible with both Debian/Ubuntu and RedHat/CentOS/SUSE)
if echo -e "$password\n$password" | passwd "$username" &>/dev/null; then
    log_success "Password set successfully for user '$username'."
else
    log_warning "Failed setting password with 'passwd'. Trying fallback 'chpasswd'..."
    # Fallback to chpasswd if passwd pipe fails
    if echo "$username:$password" | chpasswd 2>/dev/null; then
        log_success "Password set successfully via 'chpasswd'."
    else
        log_error "Failed to set password. Removing created user to maintain consistency."
        userdel -r "$username" 2>/dev/null
        exit 1
    fi
fi

echo -e "\n${GREEN}============================================="
echo -e "       USER CREATION PROCESS COMPLETED!"
echo -e "=============================================${NC}"
