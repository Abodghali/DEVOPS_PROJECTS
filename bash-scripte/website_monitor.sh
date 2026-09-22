#!/bin/bash

# ==============================================================================
# Script Name: website_monitor.sh
# Description: Monitors the availability and HTTP status code of a website,
#              sending alerts (Slack, Email, or Logs) if it returns critical 
#              errors like 404 (Not Found) or 500 (Internal Server Error).
#
# Educational Guide:
#   1. curl options:
#      - -s (silent): Suppresses progress meter and error messages.
#      - -o /dev/null (output redirection): Discards the response body.
#      - -w "%{http_code}" (write out): Prints only the HTTP status code.
#
#   2. HTTP Status Codes checked:
#      - 200 (OK): Target website is functional and reachable.
#      - 404 (Not Found): Target resource was not found.
#      - 500 (Internal Server Error): Target server encountered an internal failure.
#      - 000 (Curl standard): Indicates a network level failure (connection timeout, 
#        name resolution failure, etc.).
#
#   3. Alerting and logs:
#      - Provides Slack webhook, Local Email, and log file alerts.
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. Configuration
# ------------------------------------------------------------------------------
# Default target URL to check
TARGET_URL="https://example.com"

# Slack Webhook URL for alerts
# Example: "YOUR_SLACK_WEBHOOK_URL_HERE"
SLACK_WEBHOOK_URL=""

# Receiver Email Address (requires mailutils/mailx package to be configured)
# Example: "admin@yourdomain.com"
EMAIL_RECEIVER=""

# Log file path to record website checks
LOG_FILE="/var/log/website_monitor.log"

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
        local payload="{\"text\": \"🚨 *Website Alert* 🚨\n$message\"}"
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
    local subject="🚨 Website Alert: $TARGET_URL 🚨"
    
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
# 5. Website Monitoring Logic
# ------------------------------------------------------------------------------
check_website() {
    log_info "Checking availability for: $TARGET_URL..."

    # Use curl to get the HTTP status code
    # If the request fails entirely, curl output might be empty or 000
    local http_status
    http_status=$(curl -s -o /dev/null -w "%{http_code}" "$TARGET_URL")

    # If curl failed to get any response (e.g. host down, dns error)
    if [ -z "$http_status" ] || [ "$http_status" = "000" ] || [ "$http_status" = "0" ]; then
        log_error "ALERT: Failed to reach $TARGET_URL! Network failure or invalid domain."
        send_all_alerts "Failed to reach $TARGET_URL! Network failure or invalid domain."
        return 1
    fi

    # Handle status code cases
    case "$http_status" in
        200)
            log_success "Website $TARGET_URL returned 200 OK. Everything is good!"
            ;;
        404)
            log_error "ALERT: Website $TARGET_URL returned 404 (Not Found)!"
            send_all_alerts "Website $TARGET_URL returned 404 (Not Found)!"
            ;;
        500)
            log_error "ALERT: Website $TARGET_URL returned 500 (Internal Server Error)!"
            send_all_alerts "Website $TARGET_URL returned 500 (Internal Server Error)!"
            ;;
        *)
            # For other codes, log them as a warning and trigger alert just in case
            log_warning "Website $TARGET_URL returned unexpected status: $http_status"
            send_all_alerts "Website $TARGET_URL returned unexpected status: $http_status"
            ;;
    esac
}

# ------------------------------------------------------------------------------
# 6. Main Execution and Arguments
# ------------------------------------------------------------------------------
# Custom URL can be passed as the first argument:
#   ./website_monitor.sh https://mywebsite.com
# Use --test to mock alert dispatching:
#   ./website_monitor.sh --test

if [ "$1" = "--test" ]; then
    log_info "=== RUNNING IN TEST MODE ==="
    if [ -z "$SLACK_WEBHOOK_URL" ] && [ -z "$EMAIL_RECEIVER" ]; then
        log_warning "No alert receivers (Slack / Email) configured. Tests will output to console/logs only."
    fi
    
    test_msg="[TEST ALERT] website_monitor.sh testing alerts for target: $TARGET_URL at $(date)"
    send_all_alerts "$test_msg"
    log_success "=== TEST MODE COMPLETED ==="
else
    # Allow overriding target URL via argument
    if [ -n "$1" ]; then
        TARGET_URL="$1"
    fi
    check_website
fi
