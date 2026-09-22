#!/bin/bash

# ==============================================================================
# Script Name: db_backup.sh
# Description: Performs a MySQL database backup using mysqldump, compresses it
#              on-the-fly using gzip, and transfers it to a remote server via scp.
#
# Educational Guide:
#   1. mysqldump options :
#      - --single-transaction: Runs the dump inside a transaction block (great for
#        InnoDB), ensuring consistent state without locking tables for reads/writes.
#      - --quick: Retrieves database rows from the server one at a time instead of
#        buffering the entire table in RAM (essential for large databases).
#      - -h, -u, -p: Connection parameters (host, user, password).
#
#   2. On-the-fly Compression (Piping to gzip) :
#      - Standard: `mysqldump ... > db.sql` followed by `gzip db.sql`. (Writes twice to disk)
#      - Pipeline: `mysqldump ... | gzip > db.sql.gz`. This compresses data stream in-memory,
#        saving disk write I/O and temporary disk space.
#
#   3. Secure Copy (scp) :
#      - Transfers files securely over SSH.
#      - -P [port] : Specifies the SSH port (default is 22).
#      - -i [keyfile] : Paths to private SSH key for passwordless authentication
#                       (essential for automated/cron run).
#      - Usage: scp -P PORT -i KEYFILE local_file user@remote_host:remote_path
#
#   4. SSH Passwordless Authentication setup :
#      - Step 1: Generate key pair on local server: `ssh-keygen -t rsa -b 4096`
#      - Step 2: Copy key to remote server: `ssh-copy-id -p PORT user@remote_host`
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. Configuration
# ------------------------------------------------------------------------------
# Database credentials
DB_HOST="localhost"
DB_USER="backup_user"
DB_PASS="secure_password"
DB_NAME="my_production_db"

# Local directory to store backups temporarily
LOCAL_BACKUP_DIR="/var/backups/db"

# Remote server upload details
REMOTE_HOST=""
REMOTE_USER=""
REMOTE_DIR="/backup/databases"
REMOTE_PORT="22"
SSH_KEY="~/.ssh/id_rsa"

# Local retention policy: Number of days to keep local backups before deleting
KEEP_LOCAL_BACKUP=true
RETENTION_DAYS=7

# Log file path to log backup activities
LOG_FILE="/var/log/db_backup.log"

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
# 4. Backup and Transfer Logic
# ------------------------------------------------------------------------------
perform_db_backup() {
    log_info "Starting database backup process..."
    
    # 1. Verify dependencies are installed
    for cmd in mysqldump gzip scp; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            log_error "Dependency error: '$cmd' is not installed or available in PATH."
            exit 1
        fi
    done

    # Create local backup directory if it doesn't exist
    log_info "Creating local backup folder: $LOCAL_BACKUP_DIR"
    mkdir -p "$LOCAL_BACKUP_DIR"
    if [ $? -ne 0 ]; then
        log_error "Failed to create local backup folder. Check write permissions."
        exit 1
    fi

    # Set backup names
    local current_date=$(date '+%Y-%m-%d_%H%M%S')
    local filename="${DB_NAME}-${current_date}.sql.gz"
    local local_filepath="${LOCAL_BACKUP_DIR}/${filename}"

    log_info "Dumping and compressing database '$DB_NAME'..."

    # 2. mysqldump piped to gzip for on-the-fly compression
    mysqldump -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" --single-transaction --quick "$DB_NAME" 2>/dev/null | gzip > "$local_filepath"
    local dump_status=${PIPESTATUS[0]}
    local gzip_status=${PIPESTATUS[1]}

    # PIPESTATUS captures exit codes of commands in the pipeline
    if [ $dump_status -ne 0 ]; then
        log_error "mysqldump encountered an error (exit code: $dump_status). Verify DB credentials and status."
        rm -f "$local_filepath"
        exit 1
    fi

    if [ $gzip_status -ne 0 ]; then
        log_error "gzip compression encountered an error (exit code: $gzip_status)."
        rm -f "$local_filepath"
        exit 1
    fi

    local file_size=$(du -sh "$local_filepath" | awk '{print $1}')
    log_success "Database successfully backed up locally: $local_filepath ($file_size)"

    # 3. Transfer the backup to remote server via SCP
    if [ -n "$REMOTE_HOST" ] && [ -n "$REMOTE_USER" ]; then
        log_info "Uploading backup to remote server ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}..."
        
        # Expand ~ to home directory inside bash string
        local expanded_ssh_key
        eval expanded_ssh_key="$SSH_KEY"

        # Transfer using scp with keyfile
        scp -P "$REMOTE_PORT" -i "$expanded_ssh_key" -o BatchMode=yes -o StrictHostKeyChecking=accept-new "$local_filepath" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}/" > /dev/null 2>&1
        local upload_status=$?

        if [ $upload_status -eq 0 ]; then
            log_success "Remote transfer completed successfully!"
        else
            log_error "Failed to transfer backup to remote server (exit code: $upload_status)."
            log_warning "Check network connection, SSH port, and passwordless authentication configuration."
            # If upload fails, keep local backup regardless of configuration so data isn't lost
            KEEP_LOCAL_BACKUP=true
        fi
    else
        log_info "Remote server configurations not set. Skipping remote upload."
    fi

    # 4. Clean up local files depending on configuration
    if [ "$KEEP_LOCAL_BACKUP" = false ]; then
        log_info "Deleting local backup file after upload..."
        rm -f "$local_filepath"
        log_success "Deleted local file: $filename"
    else
        cleanup_old_local_backups
    fi
}

# ------------------------------------------------------------------------------
# 5. Local Retention Cleanup
# ------------------------------------------------------------------------------
cleanup_old_local_backups() {
    log_info "Running local retention policy (keeping last $RETENTION_DAYS days of backups)..."
    
    local old_backups=$(find "$LOCAL_BACKUP_DIR" -name "${DB_NAME}-*.sql.gz" -type f -mtime +"$RETENTION_DAYS")
    
    if [ -n "$old_backups" ]; then
        log_warning "Found old backups to delete:"
        echo "$old_backups" | while read -r file; do
            if [ -n "$file" ]; then
                rm -f "$file"
                log_success "Deleted old backup: $(basename "$file")"
            fi
        done
    else
        log_info "No old database backups to clean up."
    fi
}

# ------------------------------------------------------------------------------
# 6. Main Execution
# ------------------------------------------------------------------------------
# Usage:
#   ./db_backup.sh                      # Runs default backup
#   ./db_backup.sh db_name              # Runs backup for custom db_name
#   ./db_backup.sh db_name user pass    # Runs with custom db, user, pass

if [ -n "$1" ]; then
    DB_NAME="$1"
fi
if [ -n "$2" ]; then
    DB_USER="$2"
fi
if [ -n "$3" ]; then
    DB_PASS="$3"
fi

perform_db_backup
