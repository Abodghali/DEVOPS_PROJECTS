#!/bin/bash

# ==============================================================================
# Script Name: ram_monitor.sh
# Description: Monitors system RAM usage and logs/prints the top memory-consuming
#              processes if the usage exceeds a configurable threshold (e.g., 90%).
#
# Educational Guide:
#   1. free :
#      - Displays total, used, free, and available physical memory and swap.
#      - -m flag shows output in Megabytes (MB).
#      - We extract the second line (Mem:) to get the RAM metrics.
#
#   2. RAM Usage Calculation:
#      - Available memory represents how much RAM is actually free for new processes
#        without swapping (accounting for buffers and cache that can be released).
#      - Usage % = ((Total - Available) * 100) / Total.
#
#   3. ps (Process Status) :
#      - Lists running processes.
#      - -e: Selects all processes.
#      - -o: Specifies user-defined output format columns: pid, ppid, %mem, cmd.
#      - --no-headers: Suppresses the column header line.
#
#   4. sort :
#      - -rn: Sorts numerically (-n) in reverse/descending order (-r).
#      - -k 3: Sorts by the 3rd field/column (%mem in our ps output).
#
#   5. head :
#      - -n 10: Outputs only the first 10 lines (the top 10 consumers).
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. Configuration
# ------------------------------------------------------------------------------
# RAM usage threshold percentage (90% by default)
THRESHOLD=90

# Slack Webhook URL for alerts
# Example: "YOUR_SLACK_WEBHOOK_URL_HERE"
SLACK_WEBHOOK_URL=""

# Receiver Email Address
# Example: "admin@yourdomain.com"
EMAIL_RECEIVER=""

# Log file path to record memory checks
LOG_FILE="/var/log/ram_monitor.log"

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
# 4. Alerting Functions
# ------------------------------------------------------------------------------
send_slack_alert() {
    local message="$1"
    if [ -n "$SLACK_WEBHOOK_URL" ]; then
        log_info "Sending Slack alert..."
        local payload="{\"text\": \"🚨 *RAM Space Alert* 🚨\n$message\"}"
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

send_email_alert() {
    local message="$1"
    local subject="🚨 RAM Alert on $(hostname) 🚨"
    
    if [ -n "$EMAIL_RECEIVER" ]; then
        log_info "Sending Email alert to $EMAIL_RECEIVER..."
        if command -v mail >/dev/null 2>&1; then
            echo -e "$message" | mail -s "$subject" "$EMAIL_RECEIVER"
            if [ $? -eq 0 ]; then
                log_success "Email alert sent successfully."
            else
                log_error "Failed to send Email alert."
            fi
        else
            log_warning "'mail' command not found. Please install mailutils to use email alerts."
        fi
    else
        log_info "Email Receiver is not configured. Skipping Email alert."
    fi
}

send_all_alerts() {
    local alert_message="$1"
    send_slack_alert "$alert_message"
    send_email_alert "$alert_message"
}

# ------------------------------------------------------------------------------
# 5. Top Processes Function
# ------------------------------------------------------------------------------
get_top_processes() {
    echo -e "\n=== TOP 10 MEMORY-CONSUMING PROCESSES ==="
    printf "%-8s %-8s %-6s %s\n" "PID" "PPID" "%MEM" "COMMAND"
    echo "--------------------------------------------------------"
    
    # 1. ps lists processes with pid, ppid, %mem, command
    # 2. sort orders numerically by %mem (column 3) in descending order
    # 3. head limits output to the top 10 items
    ps -eo pid,ppid,%mem,cmd --no-headers | sort -rn -k 3 | head -n 10 | while read -r pid ppid mem cmd; do
        printf "%-8s %-8s %-6s %s\n" "$pid" "$ppid" "${mem}%" "$cmd"
    done
    echo -e "==========================================\n"
}

# ------------------------------------------------------------------------------
# 6. RAM Monitoring Logic
# ------------------------------------------------------------------------------
check_ram_usage() {
    log_info "Starting RAM usage check..."

    # Read RAM stats from `free -m` (values are in Megabytes)
    local total=0
    local used=0
    local free=0
    local buff_cache=0
    local available=0

    # Parse the Mem line
    # Format standard: Mem: total used free shared buff/cache available
    # We use awk to assign them to bash variables
    eval $(free -m | awk '/^Mem:/ {print "total="$2" used="$3" free="$4" buff_cache="$6" available="$7"}')

    # Validate that we successfully parsed the values
    if [ -z "$total" ] || [ "$total" -eq 0 ]; then
        log_error "Failed to retrieve RAM memory stats from 'free'."
        return 1
    fi

    # Fallback for older Linux kernels where the 'available' column does not exist
    if [ -z "$available" ]; then
        available=$((free + buff_cache))
    fi

    # Calculate actual used RAM and the usage percentage
    local actual_used=$((total - available))
    local usage_percent=$(( (actual_used * 100) / total ))

    log_info "RAM Usage: ${usage_percent}% (Used: ${actual_used}MB / Total: ${total}MB, Available: ${available}MB)"

    # Check if usage exceeds threshold
    if [ "$usage_percent" -ge "$THRESHOLD" ]; then
        log_warning "ALERT: RAM usage has exceeded the threshold of ${THRESHOLD}%! Current: ${usage_percent}%"

        # Capture top processes output to a local variable
        local top_proc
        top_proc=$(get_top_processes)

        # Print top processes to console/logs
        echo "$top_proc"

        # Log alert to file
        echo "$(date '+%Y-%m-%d %H:%M:%S') [ALERT] RAM usage at ${usage_percent}%!" >> "$LOG_FILE" 2>/dev/null || true
        echo "$top_proc" >> "$LOG_FILE" 2>/dev/null || true

        # Send alert notifications
        local alert_msg="RAM usage on host *$(hostname)* is at *${usage_percent}%* (Limit: ${THRESHOLD}%).\n\n\`\`\`\n$top_proc\n\`\`\`"
        send_all_alerts "$alert_msg"
    else
        log_success "RAM usage is healthy: ${usage_percent}%"
    fi
}

# ------------------------------------------------------------------------------
# 7. Main Execution and Arguments
# ------------------------------------------------------------------------------
# Custom threshold can be passed as argument:
#   ./ram_monitor.sh 85
# Use --test to mock alert behavior and display top processes:
#   ./ram_monitor.sh --test

if [ "$1" = "--test" ]; then
    log_info "=== RUNNING IN TEST MODE ==="
    log_info "Simulating high memory alert (> $THRESHOLD%)..."
    
    # Run the top process listing
    get_top_processes
    
    # Prepare alert message
    test_proc=$(get_top_processes)
    test_msg="[TEST ALERT] RAM usage on host *$(hostname)* has simulated exceeding the threshold of ${THRESHOLD}%.\n\n\`\`\`\n$test_proc\n\`\`\`"
    
    send_all_alerts "$test_msg"
    log_success "=== TEST MODE COMPLETED ==="
else
    # Allow overriding threshold via argument if it is a valid number
    if [[ "$1" =~ ^[0-9]+$ ]]; then
        THRESHOLD="$1"
        log_info "Custom threshold set to: ${THRESHOLD}%"
    fi
    check_ram_usage
fi
