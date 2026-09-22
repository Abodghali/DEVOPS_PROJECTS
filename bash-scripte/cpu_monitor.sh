#!/bin/bash

# ==============================================================================
# Script Name: cpu_monitor.sh
# Description: Monitors system CPU usage and logs/prints the top CPU-consuming
#              processes if the usage exceeds a configurable threshold (e.g., 80%).
#
# Educational Guide:
#   1. CPU Usage Calculation via /proc/stat :
#      - /proc/stat contains kernel activity statistics, including CPU time slices.
#      - The first line (cpu) reports cumulative CPU ticks since boot.
#      - We take two readings with a 1-second delay, calculate the difference 
#        in active and idle ticks, and compute the current CPU usage percentage:
#        CPU Usage % = ((Total Diff - Idle Diff) * 100) / Total Diff
#
#   2. ps (Process Status) for CPU :
#      - -e: Lists all processes.
#      - -o: Custom columns: pid, ppid, %cpu, cmd.
#      - --no-headers: Suppresses column header output.
#
#   3. sort & head :
#      - sort -rn -k 3: Sorts numerically (-n) in reverse (-r) by the 3rd field (%cpu).
#      - head -n 10: Retains only the top 10 CPU-consuming processes.
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. Configuration
# ------------------------------------------------------------------------------
# CPU usage threshold percentage (80% by default)
THRESHOLD=80

# Slack Webhook URL for alerts
# Example: "YOUR_SLACK_WEBHOOK_URL_HERE"
SLACK_WEBHOOK_URL=""

# Receiver Email Address
# Example: "admin@yourdomain.com"
EMAIL_RECEIVER=""

# Log file path to record CPU checks
LOG_FILE="/var/log/cpu_monitor.log"

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
        local payload="{\"text\": \"🚨 *CPU Alert* 🚨\n$message\"}"
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
    local subject="🚨 CPU Alert on $(hostname) 🚨"
    
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
    echo -e "\n=== TOP 10 CPU-CONSUMING PROCESSES ==="
    printf "%-8s %-8s %-6s %s\n" "PID" "PPID" "%CPU" "COMMAND"
    echo "--------------------------------------------------------"
    
    # 1. ps lists processes with pid, ppid, %cpu, command
    # 2. sort orders numerically by %cpu (column 3) in descending order
    # 3. head limits output to the top 10 items
    ps -eo pid,ppid,%cpu,cmd --no-headers | sort -rn -k 3 | head -n 10 | while read -r pid ppid cpu cmd; do
        printf "%-8s %-8s %-6s %s\n" "$pid" "$ppid" "${cpu}%" "$cmd"
    done
    echo -e "==========================================\n"
}

# ------------------------------------------------------------------------------
# 6. CPU Monitoring Logic
# ------------------------------------------------------------------------------
check_cpu_usage() {
    log_info "Measuring CPU usage (please wait 1 second)..."

    # Get first CPU state from /proc/stat
    # Format: cpu user nice system idle iowait irq softirq steal guest guest_nice
    read -r _ user nice system idle iowait irq softirq steal guest guest_nice < /proc/stat
    
    local prev_total=$((user + nice + system + idle + iowait + irq + softirq + steal))
    local prev_idle=$((idle + iowait))

    # Wait 1 second to measure the difference
    sleep 1

    # Get second CPU state
    read -r _ user nice system idle iowait irq softirq steal guest guest_nice < /proc/stat
    
    local total=$((user + nice + system + idle + iowait + irq + softirq + steal))
    local idle=$((idle + iowait))

    # Calculate differences
    local total_diff=$((total - prev_total))
    local idle_diff=$((idle - prev_idle))

    if [ "$total_diff" -eq 0 ]; then
        log_error "Failed to calculate CPU usage ticks."
        return 1
    fi

    # Calculate usage percentage
    local cpu_usage=$(( (total_diff - idle_diff) * 100 / total_diff ))

    log_info "CPU Usage: ${cpu_usage}% (Limit: ${THRESHOLD}%)"

    # Check if usage exceeds threshold
    if [ "$cpu_usage" -ge "$THRESHOLD" ]; then
        log_warning "ALERT: CPU usage has exceeded the threshold of ${THRESHOLD}%! Current: ${cpu_usage}%"

        # Capture top processes
        local top_proc
        top_proc=$(get_top_processes)

        # Print top processes to console/logs
        echo "$top_proc"

        # Log alert to file
        echo "$(date '+%Y-%m-%d %H:%M:%S') [ALERT] CPU usage at ${cpu_usage}%!" >> "$LOG_FILE" 2>/dev/null || true
        echo "$top_proc" >> "$LOG_FILE" 2>/dev/null || true

        # Send alerts
        local alert_msg="CPU usage on host *$(hostname)* is at *${cpu_usage}%* (Limit: ${THRESHOLD}%).\n\n\`\`\`\n$top_proc\n\`\`\`"
        send_all_alerts "$alert_msg"
    else
        log_success "CPU usage is healthy: ${cpu_usage}%"
    fi
}

# ------------------------------------------------------------------------------
# 7. Main Execution and Arguments
# ------------------------------------------------------------------------------
# Custom threshold can be passed as argument:
#   ./cpu_monitor.sh 75
# Use --test to mock high CPU behavior and list top processes:
#   ./cpu_monitor.sh --test

if [ "$1" = "--test" ]; then
    log_info "=== RUNNING IN TEST MODE ==="
    log_info "Simulating high CPU usage alert (> $THRESHOLD%)..."
    
    # Run the top process listing
    get_top_processes
    
    # Prepare alert message
    test_proc=$(get_top_processes)
    test_msg="[TEST ALERT] CPU usage on host *$(hostname)* has simulated exceeding the threshold of ${THRESHOLD}%.\n\n\`\`\`\n$test_proc\n\`\`\`"
    
    send_all_alerts "$test_msg"
    log_success "=== TEST MODE COMPLETED ==="
else
    # Allow overriding threshold via argument if it is a valid number
    if [[ "$1" =~ ^[0-9]+$ ]]; then
        THRESHOLD="$1"
        log_info "Custom threshold set to: ${THRESHOLD}%"
    fi
    check_cpu_usage
fi
