#!/bin/bash

# ==============================================================================
# Script Name: ssl_monitor.sh
# Description: Checks the SSL certificate expiration date of a specified domain
#              (e.g., google.com) and sends alerts if the certificate is set
#              to expire in fewer than a configurable number of days (e.g., 20 days).
#
# Educational Guide:
#   1. openssl s_client :
#      - Establishes a TLS/SSL client connection to a remote server.
#      - -servername [domain]: Sends SNI extension (essential for shared hosting).
#      - -connect [domain:port]: The target host and port (443 for HTTPS).
#      - </dev/null: Immediately closes the input stream so openssl doesn't hang.
#
#   2. openssl x509 :
#      - Utility for certificate handling.
#      - -enddate: Extracts the expiration date (notAfter field).
#      - -noout: Prevents printing the encoded certificate body.
#      - Output format: `notAfter=Mon DD HH:MM:SS YYYY GMT`
#
#   3. Date Arithmetic :
#      - date -d "date_string" +%s: Converts a human-readable date to a Unix
#        timestamp (seconds since 1970-01-01 00:00:00 UTC).
#      - We compute the difference in seconds and divide by 86400 (seconds per day)
#        to get the remaining days.
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. Configuration
# ------------------------------------------------------------------------------
# Default target domain to check
DEFAULT_DOMAIN="google.com"

# Default warning threshold in days (Alert if less than 20 days remaining)
THRESHOLD_DAYS=20

# Slack Webhook URL for alerts
# Example: "YOUR_SLACK_WEBHOOK_URL_HERE"
SLACK_WEBHOOK_URL=""

# Receiver Email Address
# Example: "admin@yourdomain.com"
EMAIL_RECEIVER=""

# Log file path to record SSL checks
LOG_FILE="/var/log/ssl_monitor.log"

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
        local payload="{\"text\": \"🚨 *SSL Certificate Alert* 🚨\n$message\"}"
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
    local subject="🚨 SSL Certificate Expiration Warning: $DEFAULT_DOMAIN 🚨"
    
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
# 5. SSL Monitoring Logic
# ------------------------------------------------------------------------------
check_ssl_expiry() {
    local target_domain="$1"
    log_info "Checking SSL certificate expiration date for: $target_domain..."

    # Verify openssl is installed
    if ! command -v openssl >/dev/null 2>&1; then
        log_error "openssl is not installed on this system."
        exit 1
    fi

    # 1. Fetch certificate end date using openssl
    local end_date_raw
    end_date_raw=$(openssl s_client -servername "$target_domain" -connect "${target_domain}:443" </dev/null 2>/dev/null \
                  | openssl x509 -noout -enddate 2>/dev/null)

    # Verify if we retrieved a valid response
    if [ -z "$end_date_raw" ]; then
        log_error "ALERT: Failed to retrieve SSL certificate for '$target_domain'. Host may be down or does not support HTTPS/SSL."
        send_all_alerts "Failed to retrieve SSL certificate for '$target_domain'. Check host connectivity."
        return 1
    fi

    # Extract date string: e.g. "Mar 10 12:00:00 2026 GMT"
    local end_date_str=$(echo "$end_date_raw" | cut -d= -f2)

    # 2. Convert dates to Unix epoch timestamps
    local current_epoch=$(date +%s)
    local end_epoch
    end_epoch=$(date -d "$end_date_str" +%s 2>/dev/null)

    # Fallback to verify date parsing
    if [ -z "$end_epoch" ]; then
        log_error "Failed to parse SSL expiration date: $end_date_str"
        return 1
    fi

    # 3. Calculate difference in days
    local diff_seconds=$((end_epoch - current_epoch))
    local diff_days=$((diff_seconds / 86400))

    # Evaluate results
    if [ "$diff_days" -lt 0 ]; then
        # Negative days means the certificate has already expired!
        log_error "CRITICAL ALERT: SSL certificate for '$target_domain' expired $(( -diff_days )) days ago!"
        send_all_alerts "CRITICAL ALERT: SSL certificate for '$target_domain' has EXPIRED $(( -diff_days )) days ago! (Expiration: $end_date_str)"
    elif [ "$diff_days" -lt "$THRESHOLD_DAYS" ]; then
        # Expiry is within the threshold warning days
        log_warning "ALERT: SSL certificate for '$target_domain' expires in $diff_days days! (Limit: $THRESHOLD_DAYS days, Expiration: $end_date_str)"
        send_all_alerts "ALERT: SSL certificate for '$target_domain' expires in $diff_days days! (Expiration Date: $end_date_str)"
    else
        log_success "SSL certificate for '$target_domain' is healthy. Expires in $diff_days days ($end_date_str)."
    fi
}

# ------------------------------------------------------------------------------
# 6. Main Execution and Arguments
# ------------------------------------------------------------------------------
# Custom domain can be passed as the first argument:
#   ./ssl_monitor.sh google.com
# Use --test to mock warning behavior:
#   ./ssl_monitor.sh --test

if [ "$1" = "--test" ]; then
    log_info "=== RUNNING IN TEST MODE ==="
    log_info "Simulating SSL expiration warning for: $DEFAULT_DOMAIN..."
    
    test_msg="[TEST ALERT] SSL Certificate for *$DEFAULT_DOMAIN* is expiring soon! Days remaining: 15 (Threshold: $THRESHOLD_DAYS days)."
    send_all_alerts "$test_msg"
    log_success "=== TEST MODE COMPLETED ==="
else
    # Allow overriding target domain via argument
    if [ -n "$1" ]; then
        DEFAULT_DOMAIN="$1"
    fi
    check_ssl_expiry "$DEFAULT_DOMAIN"
fi
