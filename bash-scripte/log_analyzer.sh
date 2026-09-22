#!/bin/bash

# ==============================================================================
# Script Name: log_analyzer.sh
# Description: Parses Nginx/Apache access.log files to extract insights:
#              total request count, top IPs, top requested pages, and top errors.
#
# Educational Guide:
#   1. text-processing tools:
#      - awk: Pattern scanning and processing language. Ideal for splitting lines into fields.
#      - sort: Sorts lines of text files. -r reverses, -n sorts numerically.
#      - uniq -c: Filters adjacent duplicate lines and prefixes them with occurrence counts.
#      - head -n 5: Restricts output to the top 5 entries.
#   2. Field Mapping (Combined/Common Log Format):
#      - $1: Client IP Address.
#      - $7: Request Path/Page (URL).
#      - $9: HTTP Status Code (200, 404, 500, etc.).
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. Colors for Console Output
# ------------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ------------------------------------------------------------------------------
# 2. Argument Parsing and File Check
# ------------------------------------------------------------------------------
# Default log file is access.log in current directory if no argument is passed
LOG_FILE="${1:-access.log}"

# Print Banner
echo -e "${BLUE}"
echo "=========================================================="
echo "                 Access Log Analyzer                      "
echo "=========================================================="
echo -e "${NC}"

# Verify if file exists and is readable
if [ ! -f "$LOG_FILE" ]; then
    log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
    log_error "Log file '$LOG_FILE' does not exist."
    echo -e "Usage: ./log_analyzer.sh [path_to_access.log]\n"
    
    # Offer to create a sample log file if default access.log is missing
    if [ "$LOG_FILE" = "access.log" ]; then
        read -p "Would you like to generate a sample 'access.log' to test the script? (y/N): " choice
        if [[ "$choice" =~ ^[yY]$ ]]; then
            echo -e "${BLUE}[INFO] Generating sample 'access.log'...${NC}"
            cat <<EOF > access.log
192.168.1.10 - - [11/Jul/2026:10:00:01 +0200] "GET /index.html HTTP/1.1" 200 3426 "-" "Mozilla/5.0"
192.168.1.10 - - [11/Jul/2026:10:00:05 +0200] "GET /about.html HTTP/1.1" 200 1205 "-" "Mozilla/5.0"
192.168.1.12 - - [11/Jul/2026:10:01:10 +0200] "GET /index.html HTTP/1.1" 200 3426 "-" "Mozilla/5.0"
192.168.1.15 - - [11/Jul/2026:10:02:15 +0200] "GET /contact.html HTTP/1.1" 200 892 "-" "Mozilla/5.0"
192.168.1.10 - - [11/Jul/2026:10:02:30 +0200] "GET /login HTTP/1.1" 404 230 "-" "Mozilla/5.0"
192.168.1.12 - - [11/Jul/2026:10:03:00 +0200] "POST /login HTTP/1.1" 500 567 "-" "Mozilla/5.0"
10.0.0.5 - - [11/Jul/2026:10:04:12 +0200] "GET /index.html HTTP/1.1" 200 3426 "-" "Mozilla/5.0"
192.168.1.10 - - [11/Jul/2026:10:05:00 +0200] "GET /index.html HTTP/1.1" 200 3426 "-" "Mozilla/5.0"
192.168.1.12 - - [11/Jul/2026:10:06:18 +0200] "GET /dashboard HTTP/1.1" 403 120 "-" "Mozilla/5.0"
10.0.0.5 - - [11/Jul/2026:10:07:05 +0200] "GET /about.html HTTP/1.1" 200 1205 "-" "Mozilla/5.0"
192.168.1.10 - - [11/Jul/2026:10:08:45 +0200] "GET /missing-page HTTP/1.1" 404 230 "-" "Mozilla/5.0"
EOF
            echo -e "${GREEN}[SUCCESS] Sample 'access.log' created. Re-running analysis...${NC}\n"
        else
            exit 1
        fi
    else
        exit 1
    fi
fi

# ------------------------------------------------------------------------------
# 3. Log Parsing and Calculation
# ------------------------------------------------------------------------------

# A. Total Requests Count
total_requests=$(wc -l < "$LOG_FILE" | tr -d ' ')
echo -e "${YELLOW}Analyzing log file :${NC} $LOG_FILE"
echo -e "${YELLOW}Total Requests     :${NC} ${GREEN}$total_requests${NC} requests"
echo ""

# B. Top 5 IPs
echo -e "${CYAN}=== Top 5 Active IP Addresses ===${NC}"
printf "%-10s %-20s\n" "REQUESTS" "IP ADDRESS"
echo "-------------------------------------"
while read -r count ip; do
    [ -z "$ip" ] && continue
    printf "%-10s %-20s\n" "$count" "$ip"
done < <(awk '{print $1}' "$LOG_FILE" | sort | uniq -c | sort -rn | head -n 5)
echo ""

# C. Top 5 Requested Pages/URLs
echo -e "${CYAN}=== Top 5 Requested Pages/URLs ===${NC}"
printf "%-10s %-35s\n" "REQUESTS" "PAGE / URL"
echo "-------------------------------------"
while read -r count page; do
    [ -z "$page" ] && continue
    printf "%-10s %-35s\n" "$count" "$page"
done < <(awk '{print $7}' "$LOG_FILE" | sort | uniq -c | sort -rn | head -n 5)
echo ""

# D. Top 5 Error Status Codes (4xx and 5xx Client/Server Errors)
echo -e "${CYAN}=== Top 5 HTTP Errors (4xx/5xx) ===${NC}"
printf "%-10s %-12s %-20s\n" "COUNT" "STATUS CODE" "ERROR TYPE"
echo "------------------------------------------------"
errors_found=0
while read -r count status; do
    [ -z "$status" ] && continue
    errors_found=1
    # Determine error classification label
    if [[ "$status" =~ ^4 ]]; then
        error_type="${RED}Client Error (4xx)${NC}"
    elif [[ "$status" =~ ^5 ]]; then
        error_type="${RED}Server Error (5xx)${NC}"
    else
        error_type="Other"
    fi
    printf "%-10s %-12s %b\n" "$count" "$status" "$error_type"
done < <(awk '$9 ~ /^[45][0-9][0-9]$/ {print $9}' "$LOG_FILE" | sort | uniq -c | sort -rn | head -n 5)

if [ $errors_found -eq 0 ]; then
    echo -e "${GREEN}No HTTP errors (4xx or 5xx) found in the log file.${NC}"
fi

echo -e "\n${CYAN}==========================================================${NC}"
