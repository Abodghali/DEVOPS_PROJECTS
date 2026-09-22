#!/bin/bash

# ==============================================================================
# Script Name: auto_deploy.sh
# Description: Automated DevOps deployment script. Pulls updates from GitHub,
#              installs npm dependencies, compiles builds, and restarts the
#              application service (PM2, Systemd, or custom).
#
# Educational Guide:
#   1. Git Verification:
#      - Compares local commit hash (HEAD) with remote tracking branch (@{u})
#        to determine if there are new changes to deploy.
#   2. npm Package Management:
#      - npm install reads package.json and updates node_modules.
#      - npm run build compiles assets (TypeScript, Webpack, Vite, Next.js, etc.).
#   3. Process & Service Management:
#      - PM2 (Process Manager 2) is common for Node.js apps.
#      - Systemd manages system-level services (systemctl).
#   4. Robust Logging:
#      - Saves all outputs to deploy.log and displays status on console.
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. Configuration Section (Adjust these to match your environment)
# ------------------------------------------------------------------------------
# Path to your Git project repository
PROJECT_DIR="/var/www/my-nodejs-app"

# Target Git branch
BRANCH="main"

# Service Manager type: "pm2", "systemd", "custom", or "none"
SERVICE_MANAGER="pm2"

# Name of the service or application to restart
# E.g. "my-web-app" (for PM2) or "myapp.service" (for Systemd)
SERVICE_NAME="my-web-app"

# Custom restart command (only executed if SERVICE_MANAGER="custom")
CUSTOM_RESTART_CMD="docker compose restart web"

# Enable npm build step (true/false)
RUN_BUILD=true

# Path to the deployment log file
LOG_FILE="./deploy.log"

# Enable stdout print (true/false)
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
# 3. Logging & Utilities
# ------------------------------------------------------------------------------
log_info() {
    [ "$VERBOSE" = true ] && echo -e "${BLUE}[INFO]${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $1" >> "$LOG_FILE"
}

log_success() {
    [ "$VERBOSE" = true ] && echo -e "${GREEN}[SUCCESS]${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [SUCCESS] $1" >> "$LOG_FILE"
}

log_warning() {
    [ "$VERBOSE" = true ] && echo -e "${YELLOW}[WARNING]${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [WARNING] $1" >> "$LOG_FILE"
}

log_error() {
    [ "$VERBOSE" = true ] && echo -e "${RED}[ERROR]${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $1" >> "$LOG_FILE"
}

# Print Banner
echo -e "${BLUE}"
echo "=========================================================="
echo "               Automated Deploy Script                    "
echo "=========================================================="
echo -e "${NC}"

# Check log file writable
touch "$LOG_FILE" 2>/dev/null
if [ $? -ne 0 ]; then
    echo -e "${RED}[ERROR] Log file '$LOG_FILE' is not writable. Aborting.${NC}"
    exit 1
fi

# ------------------------------------------------------------------------------
# 4. Git Repository & Update Check
# ------------------------------------------------------------------------------
log_info "Navigating to project directory: $PROJECT_DIR"
if [ ! -d "$PROJECT_DIR" ]; then
    log_error "Project directory '$PROJECT_DIR' does not exist."
    exit 1
fi

cd "$PROJECT_DIR" || exit 1

# Check if directory is a valid git repository
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    log_error "'$PROJECT_DIR' is not a valid Git repository."
    exit 1
fi

# Fetch updates from remote
log_info "Fetching latest updates from remote repository..."
if ! git fetch origin "$BRANCH" >> "$LOG_FILE" 2>&1; then
    log_error "Failed to fetch from remote repository."
    exit 1
fi

# Compare local commit with remote commit
LOCAL_COMMIT=$(git rev-parse HEAD)
REMOTE_COMMIT=$(git rev-parse origin/"$BRANCH")

if [ "$LOCAL_COMMIT" = "$REMOTE_COMMIT" ] && [ "$1" != "--force" ]; then
    log_success "Project is already up-to-date with branch '$BRANCH'. No deployment needed."
    log_info "To force a deployment, run the script with: --force"
    exit 0
fi

if [ "$1" = "--force" ]; then
    log_warning "Force deployment flag detected. Proceeding..."
fi

# ------------------------------------------------------------------------------
# 5. Execute git pull
# ------------------------------------------------------------------------------
log_info "Pulling changes from branch '$BRANCH'..."
if git pull origin "$BRANCH" >> "$LOG_FILE" 2>&1; then
    log_success "Successfully pulled code changes."
else
    log_error "Git pull failed. Check git credentials or merge conflicts."
    exit 1
fi

# ------------------------------------------------------------------------------
# 6. Install npm Dependencies
# ------------------------------------------------------------------------------
if [ -f "package.json" ]; then
    log_info "package.json found. Installing npm dependencies..."
    
    # Check if npm is installed
    if ! command -v npm &>/dev/null; then
        log_error "npm command not found. Cannot run install."
        exit 1
    fi
    
    # Run npm install (or npm ci for cleaner production builds)
    if npm install >> "$LOG_FILE" 2>&1; then
        log_success "Dependencies installed successfully."
    else
        log_error "npm install failed. Check logs in '$LOG_FILE' for details."
        exit 1
    fi
else
    log_warning "package.json not found in '$PROJECT_DIR'. Skipping npm install."
fi

# ------------------------------------------------------------------------------
# 7. Build Project
# ------------------------------------------------------------------------------
if [ "$RUN_BUILD" = true ] && [ -f "package.json" ]; then
    # Verify build script exists in package.json
    if grep -q '"build":' package.json; then
        log_info "Running npm build..."
        if npm run build >> "$LOG_FILE" 2>&1; then
            log_success "Build completed successfully."
        else
            log_error "npm build failed. Check logs in '$LOG_FILE' for details."
            exit 1
        fi
    else
        log_warning "No build script found in package.json. Skipping build step."
    fi
fi

# ------------------------------------------------------------------------------
# 8. Service Restart
# ------------------------------------------------------------------------------
log_info "Restarting application service (Manager: $SERVICE_MANAGER)..."

case $SERVICE_MANAGER in
    pm2)
        if ! command -v pm2 &>/dev/null; then
            log_error "pm2 is not installed or not in PATH."
            exit 1
        fi
        
        # Check if service is already running under PM2
        if pm2 show "$SERVICE_NAME" &>/dev/null; then
            if pm2 restart "$SERVICE_NAME" >> "$LOG_FILE" 2>&1; then
                log_success "PM2 service '$SERVICE_NAME' restarted successfully."
            else
                log_error "Failed to restart PM2 service '$SERVICE_NAME'."
                exit 1
            fi
        else
            log_warning "PM2 service '$SERVICE_NAME' is not active. Attempting start..."
            if pm2 start npm --name "$SERVICE_NAME" -- start >> "$LOG_FILE" 2>&1; then
                log_success "PM2 service '$SERVICE_NAME' started successfully."
            else
                log_error "Failed to start PM2 service '$SERVICE_NAME'."
                exit 1
            fi
        fi
        ;;

    systemd)
        log_info "Attempting to restart systemd service '$SERVICE_NAME' via sudo..."
        if sudo systemctl restart "$SERVICE_NAME" >> "$LOG_FILE" 2>&1; then
            log_success "Systemd service '$SERVICE_NAME' restarted successfully."
        else
            log_error "Failed to restart systemd service '$SERVICE_NAME'. Ensure passwordless sudo config exists for systemctl."
            exit 1
        fi
        ;;

    custom)
        log_info "Executing custom restart command: $CUSTOM_RESTART_CMD"
        if eval "$CUSTOM_RESTART_CMD" >> "$LOG_FILE" 2>&1; then
            log_success "Custom restart command completed successfully."
        else
            log_error "Custom restart command failed."
            exit 1
        fi
        ;;

    none)
        log_warning "Service manager set to 'none'. Skipping service restart."
        ;;

    *)
        log_error "Unknown SERVICE_MANAGER: '$SERVICE_MANAGER'."
        exit 1
        ;;
esac

echo -e "\n${GREEN}============================================="
echo -e "       DEPLOYMENT COMPLETED SUCCESSFULLY!"
echo -e "=============================================${NC}"
