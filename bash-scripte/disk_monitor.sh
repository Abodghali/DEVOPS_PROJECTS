#!/bin/bash

# ==============================================================================
# Script Name: disk_monitor.sh
# Description: Monitors disk space usage and sends alerts (Slack Webhook, Email, or Logs)
#              if usage exceeds a specific threshold.
#
#
#
# Educational Guide:
#   1. df -Ph :
#      - df (Disk Free) displays information about disk space usage.
#      - -P (POSIX formatting) ensures long filesystem names don't break lines in the output.
#      - -h (Human Readable) shows sizes in easy-to-read units like Gigabytes (G) or Megabytes (M).
#
#   2. awk :
#      - A powerful text processing tool used here to filter columns.
#      - NR>1 : Skips the first line (headers).
#      - $1 !~ /tmpfs|devtmpfs|cdrom/ : Ignores lines containing temporary or virtual filesystems.
#      - gsub(/%/, "", $5) : Replaces the '%' sign in the 5th column with nothing, making it a pure number.
#      - print $1, $5, $6 : Prints the 1st column (device), 5th (usage percentage), and 6th (mount point).
#
#   3. if [ "$usage" -ge "$THRESHOLD" ] :
#      - Conditional statement to compare the usage percentage with the threshold.
#      - -ge (Greater than or Equal to) is used for comparison.
#
#   4. Slack Webhook / mail :
#      - Slack Webhook: Sends a JSON payload using curl via POST to a Slack channel.
#      - mail: Sends a direct email notification from the server using the local mail command.
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. Configuration
# ------------------------------------------------------------------------------
# Threshold percentage (80% by default)
THRESHOLD=80

# Slack Webhook URL for alerts
# Example: "YOUR_SLACK_WEBHOOK_URL_HERE"
SLACK_WEBHOOK_URL=""

# Receiver Email Address (requires mailutils/mailx package to be configured)
# Example: "admin@yourdomain.com"
EMAIL_RECEIVER=""

# Log file path to record disk check runs
LOG_FILE="/var/log/disk_monitor.log"

# Enable console output (true/false)
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
# 3. Log Functions
# ------------------------------------------------------------------------------
log_info() {
    [ "$VERBOSE" = true ] && echo -e "${BLUE}[INFO]${NC} $1"
    # Append to log file, ignore permission errors if not running as root
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
# 4. Alerting Functions
# ------------------------------------------------------------------------------

# Send alert notification to Slack
send_slack_alert() {
    local message="$1"
    if [ -n "$SLACK_WEBHOOK_URL" ]; then
        log_info "Sending Slack alert..."
        # Create JSON payload and send via curl
        local payload="{\"text\": \"🚨 *Disk Space Alert* 🚨\n$message\"}"
        
        # Send request and verify exit status
        curl -s -X POST -H 'Content-type: application/json' --data "$payload" "$SLACK_WEBHOOK_URL" > /dev/null
        if [ $? -eq 0 ]; then
            log_success "Slack alert sent successfully."
        else
            log_error "Failed to send Slack alert."
        fi
    else
        log_info "Slack Webhook URL is not configured. Skipping Slack alert."
    fi
}

# Send alert notification via Email
send_email_alert() {
    local message="$1"
    local subject="🚨 Disk Space Alert on $(hostname) 🚨"
    
    if [ -n "$EMAIL_RECEIVER" ]; then
        log_info "Sending Email alert to $EMAIL_RECEIVER..."
        
        # Check if mail command is available on the system
        if command -v mail >/dev/null 2>&1; then
            echo -e "$message" | mail -s "$subject" "$EMAIL_RECEIVER"
            if [ $? -eq 0 ]; then
                log_success "Email alert sent successfully."
            else
                log_error "Failed to send Email alert."
            fi
        else
            log_warning "'mail' command not found. Please install mailutils (e.g. 'sudo apt-get install mailutils' or 'yum install mailx') to use email alerts."
        fi
    else
        log_info "Email Receiver is not configured. Skipping Email alert."
    fi
}

# ------------------------------------------------------------------------------
# 5. Disk Check Logic
# ------------------------------------------------------------------------------
check_disk_usage() {
    log_info "Starting disk usage check..."
    
    local alert_triggered=false
    local alert_message=""
    
    # 1. Run df -Ph to get disk usage details.
    # 2. Filter output through awk to extract: device name, usage (without % sign), and mount point.
    # 3. Read the columns using a while loop.
    # Note: We use Process Substitution `< <(...)` instead of a pipe `|`
    # because a pipeline runs the loop in a subshell, which would cause variable changes (like alert_triggered)
    # to be lost when the loop ends.
    while read -r device usage mount_point; do
        
        # Verify that the extracted usage value is a valid integer
        if [[ "$usage" =~ ^[0-9]+$ ]]; then
            log_info "Checking $device ($mount_point): Usage is ${usage}%"
            
            # Check if usage is greater than or equal to threshold
            if [ "$usage" -ge "$THRESHOLD" ]; then
                log_warning "ALERT: Device $device mounted on $mount_point exceeds threshold! Current: ${usage}% (Limit: ${THRESHOLD}%)"
                # Build alert message
                alert_message+="- Partition *${device}* mounted on *${mount_point}* is at *${usage}%* usage.\n"
                alert_triggered=true
            fi
        else
            log_warning "Skipping invalid partition data for device: $device (Usage: $usage)"
        fi
    done < <(df -Ph | awk '
        NR > 1 && $1 !~ /tmpfs/ && $1 !~ /devtmpfs/ && $1 !~ /cdrom/ && $1 !~ /udev/ && $1 !~ /loop/ {
            # Remove % sign from column 5 and save as a number
            gsub(/%/, "", $5);
            # Print device name, usage percentage, and mount point
            print $1, $5, $6
        }
    ')
    
    # If any alert was triggered, send notifications
    if [ "$alert_triggered" = true ]; then
        local full_message="The following partition(s) on host *$(hostname)* have exceeded the disk usage threshold of ${THRESHOLD}%:\n\n${alert_message}"
        
        # Send alerts
        send_slack_alert "$full_message"
        send_email_alert "$full_message"
    else
        log_success "All monitored partitions are under the ${THRESHOLD}% threshold."
    fi
}

# ------------------------------------------------------------------------------
# 6. Main execution options
# ------------------------------------------------------------------------------
# Usage options:
# 1. Normal run: ./disk_monitor.sh
# 2. Test run:   ./disk_monitor.sh --test
#    (sends a mock alert to verify Slack and Email alert configurations)

if [ "$1" = "--test" ]; then
    log_info "=== RUNNING IN TEST MODE ==="
    # Temporarily warn if alerts are not configured
    if [ -z "$SLACK_WEBHOOK_URL" ] && [ -z "$EMAIL_RECEIVER" ]; then
        log_warning "No Slack Webhook or Email Receiver configured. Test will only show log/console alerts."
    fi
    
    test_msg="[TEST ALERT] This is a verification message to test the Disk Space Alerting system on host: $(hostname) (Time: $(date))"
    send_slack_alert "$test_msg"
    send_email_alert "$test_msg"
    log_success "=== TEST MODE COMPLETED ==="
else
    check_disk_usage
fi
