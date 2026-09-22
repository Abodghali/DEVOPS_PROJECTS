#!/bin/bash

# ==============================================================================
# Script Name: manage_permissions.sh
# Description: Interactive script to add a Linux user to specific groups:
#              docker, sudo (or wheel), and developers.
#
# Educational Guide:
#   1. usermod Command:
#      - usermod modifies a user account.
#      - -a (append) option is used WITH -G to add the user to supplemental groups
#        without removing them from their current groups.
#      - -G option specifies the list of groups.
#   2. Group Management:
#      - groupadd creates a new group.
#      - getent group <groupname> checks if a group exists.
#   3. OS Compatibility:
#      - Administrative privileges group varies by OS: 'sudo' on Debian/Ubuntu,
#        and 'wheel' on Red Hat/CentOS/Rocky Linux.
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
echo "             Permissions Management Script                "
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
# 4. User Interaction & Validation
# ------------------------------------------------------------------------------
# Prompt for Username
read -p "Enter the username to modify: " username

# Validate Username is not empty
if [ -z "$username" ]; then
    log_error "Username cannot be empty."
    exit 1
fi

# Check if user exists on the system
if ! id "$username" &>/dev/null; then
    log_error "User '$username' does not exist on this system."
    exit 1
fi

# ------------------------------------------------------------------------------
# 5. Group Checking and Creation
# ------------------------------------------------------------------------------
# A. Determine sudo/admin group based on OS
ADMIN_GROUP=""
if getent group sudo &>/dev/null; then
    ADMIN_GROUP="sudo"
elif getent group wheel &>/dev/null; then
    ADMIN_GROUP="wheel"
fi

# B. Ensure 'docker' group exists
if ! getent group docker &>/dev/null; then
    log_info "Group 'docker' does not exist. Creating it..."
    if groupadd docker; then
        log_success "Group 'docker' created successfully."
    else
        log_error "Failed to create group 'docker'."
        exit 1
    fi
fi

# C. Ensure 'developers' group exists
if ! getent group developers &>/dev/null; then
    log_info "Group 'developers' does not exist. Creating it..."
    if groupadd developers; then
        log_success "Group 'developers' created successfully."
    else
        log_error "Failed to create group 'developers'."
        exit 1
    fi
fi

# ------------------------------------------------------------------------------
# 6. Assigning User to Groups
# ------------------------------------------------------------------------------
# 1. Add to Admin Group (sudo or wheel)
if [ -n "$ADMIN_GROUP" ]; then
    log_info "Adding '$username' to administrative group '$ADMIN_GROUP'..."
    if usermod -aG "$ADMIN_GROUP" "$username"; then
        log_success "Added '$username' to group '$ADMIN_GROUP' successfully."
    else
        log_error "Failed to add '$username' to group '$ADMIN_GROUP'."
    fi
else
    log_warning "Neither 'sudo' nor 'wheel' groups were found. Skipping admin group assignment."
fi

# 2. Add to docker Group
log_info "Adding '$username' to group 'docker'..."
if usermod -aG docker "$username"; then
    log_success "Added '$username' to group 'docker' successfully."
else
    log_error "Failed to add '$username' to group 'docker'."
fi

# 3. Add to developers Group
log_info "Adding '$username' to group 'developers'..."
if usermod -aG developers "$username"; then
    log_success "Added '$username' to group 'developers' successfully."
else
    log_error "Failed to add '$username' to group 'developers'."
fi

# ------------------------------------------------------------------------------
# 7. Verification Summary
# ------------------------------------------------------------------------------
echo -e "\n${BLUE}========== USER GROUPS FOR '$username' ==========${NC}"
groups "$username"

echo -e "\n${GREEN}============================================="
echo -e "       PERMISSIONS MANAGEMENT COMPLETED!"
echo -e "=============================================${NC}"
