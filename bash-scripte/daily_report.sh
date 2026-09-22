#!/bin/bash

# ==============================================================================
# Script Name: daily_report.sh
# Description: Generates a consolidated system status report encompassing
#              CPU load, RAM consumption, Disk space, Docker state, 
#              Kubernetes health, and log file analysis.
#              Outputs to the console and writes to 'daily_report.txt'.
#
# Educational Guide:
#   1. System Diagnostics:
#      - Uses free, top/uptime, and df for standard server metrics.
#   2. Optional Daemon checks (Docker & Kubernetes):
#      - Gracefully checks if docker/kubectl commands exist and have active daemons,
#        falling back to status reports without failing the entire script.
#   3. Log Summary:
#      - Reads access.log if available for HTTP traffic and checks syslog/messages
#        for system-level errors.
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

REPORT_FILE="daily_report.txt"

# ------------------------------------------------------------------------------
# 2. Information Gathering
# ------------------------------------------------------------------------------
echo -e "${BLUE}[INFO] Compiling daily system report, please wait...${NC}\n"

# A. General Details
HOSTNAME=$(hostname)
REPORT_DATE=$(date)

# B. CPU Details
cpu_usage=$(top -bn1 2>/dev/null | grep "Cpu(s)" | awk '{print $2 + $4}' | cut -d. -f1)
[ -z "$cpu_usage" ] && cpu_usage=$(uptime 2>/dev/null | awk -F'load average:' '{print $2}' | awk -F',' '{print $1}' | sed 's/ //g' | cut -d. -f1)
[ -z "$cpu_usage" ] && cpu_usage="N/A"

load_avg=$(uptime | awk -F'load average:' '{print $2}' | sed 's/^[ \t]*//')
[ -z "$load_avg" ] && load_avg="N/A"

top_cpu_process=$(ps -eo %cpu,comm --sort=-%cpu --no-headers 2>/dev/null | head -n1 | awk '{printf "%s (%s%% CPU)", $2, $1}')
[ -z "$top_cpu_process" ] && top_cpu_process="N/A"

# C. RAM Details
ram_details=""
if command -v free &>/dev/null; then
    ram_details=$(free -h)
else
    ram_details="Memory tools (free) not available."
fi
top_ram_process=$(ps -eo %mem,comm --sort=-%mem --no-headers 2>/dev/null | head -n1 | awk '{printf "%s (%s%% RAM)", $2, $1}')
[ -z "$top_ram_process" ] && top_ram_process="N/A"

# D. Disk Details
disk_details=""
if command -v df &>/dev/null; then
    disk_details=$(df -h -x devtmpfs -x tmpfs -x squashfs 2>/dev/null)
else
    disk_details="Disk tools (df) not available."
fi

# E. Docker Status
docker_status="Not Installed / Not Running"
docker_info=""
if command -v docker &>/dev/null; then
    if docker info &>/dev/null; then
        docker_status="Running"
        docker_info=$(docker info --format 'Running Containers: {{.ContainersRunning}}, Paused: {{.ContainersPaused}}, Stopped: {{.ContainersStopped}}' 2>/dev/null)
        docker_info+=$'\n'$(docker ps --format "  - {{.Names}} ({{.Status}})" 2>/dev/null)
    fi
fi

# F. Kubernetes Status
k8s_status="Not Configured / Unreachable"
k8s_info=""
if command -v kubectl &>/dev/null; then
    if kubectl cluster-info &>/dev/null; then
        k8s_status="Connected"
        pods_list=$(kubectl get pods -A --no-headers 2>/dev/null)
        k8s_total=$(echo "$pods_list" | wc -l | tr -d ' ')
        k8s_running=$(echo "$pods_list" | awk '$4 == "Running" {print}' | wc -l | tr -d ' ')
        k8s_pending=$(echo "$pods_list" | awk '$4 == "Pending" {print}' | wc -l | tr -d ' ')
        k8s_unhealthy=$(echo "$pods_list" | awk '$4 ~ /CrashLoopBackOff|Error|Failed/ {print}' | wc -l | tr -d ' ')
        k8s_info="Total Pods: $k8s_total | Running: $k8s_running | Pending: $k8s_pending | Unhealthy: $k8s_unhealthy"
    fi
fi

# G. Log Analysis
log_summary="No web log files found to analyze."
if [ -f "access.log" ]; then
    total_reqs=$(wc -l < access.log 2>/dev/null | tr -d ' ')
    err_reqs=$(awk '$9 ~ /^[45][0-9][0-9]$/ {print}' access.log 2>/dev/null | wc -l | tr -d ' ')
    log_summary="Log target: access.log\n  - Total requests processed: $total_reqs\n  - HTTP 4xx/5xx Errors: $err_reqs"
fi

syslog_path="/var/log/syslog"
[ ! -f "$syslog_path" ] && syslog_path="/var/log/messages"
syslog_errors=""
if [ -f "$syslog_path" ]; then
    syslog_errors=$(grep -i -E "error|failed|critical" "$syslog_path" | tail -n 5)
    [ -z "$syslog_errors" ] && syslog_errors="No critical errors found in syslog."
else
    syslog_errors="Syslog file not found or unreadable."
fi

# ------------------------------------------------------------------------------
# 3. Write Clean Report to File
# ------------------------------------------------------------------------------
{
    echo "=========================================================="
    echo "                 DAILY SYSTEM STATUS REPORT               "
    echo "=========================================================="
    echo "Generated on : $REPORT_DATE"
    echo "Hostname     : $HOSTNAME"
    echo "----------------------------------------------------------"
    echo "1. CPU PERFORMANCE"
    echo "   CPU Usage: $cpu_usage%"
    echo "   Load Avg : $load_avg"
    echo "   Top CPU  : $top_cpu_process"
    echo "----------------------------------------------------------"
    echo "2. RAM UTILIZATION"
    echo "$ram_details"
    echo "   Top RAM  : $top_ram_process"
    echo "----------------------------------------------------------"
    echo "3. DISK SPACE STATUS"
    echo "$disk_details"
    echo "----------------------------------------------------------"
    echo "4. DOCKER DAEMON STATUS"
    echo "   Status: $docker_status"
    if [ -n "$docker_info" ]; then
        echo "$docker_info"
    fi
    echo "----------------------------------------------------------"
    echo "5. KUBERNETES CLUSTER STATUS"
    echo "   Status: $k8s_status"
    if [ -n "$k8s_info" ]; then
        echo "   Metrics: $k8s_info"
    fi
    echo "----------------------------------------------------------"
    echo "6. LOG DIAGNOSTICS & SYSTEM ERRORS"
    echo -e "$log_summary"
    echo "   Recent Syslog Errors:"
    echo "$syslog_errors"
    echo "=========================================================="
} > "$REPORT_FILE"

# ------------------------------------------------------------------------------
# 4. Display Colored Report in Terminal
# ------------------------------------------------------------------------------
echo -e "${CYAN}==========================================================${NC}"
echo -e "                 ${GREEN}DAILY SYSTEM STATUS REPORT${NC}               "
echo -e "${CYAN}==========================================================${NC}"
echo -e "${YELLOW}Generated on :${NC} $REPORT_DATE"
echo -e "${YELLOW}Hostname     :${NC} $HOSTNAME"
echo -e "${CYAN}----------------------------------------------------------${NC}"
echo -e "${GREEN}1. CPU PERFORMANCE${NC}"
echo -e "   CPU Usage: ${YELLOW}$cpu_usage%${NC}"
echo -e "   Load Avg : $load_avg"
echo -e "   Top CPU  : $top_cpu_process"
echo -e "${CYAN}----------------------------------------------------------${NC}"
echo -e "${GREEN}2. RAM UTILIZATION${NC}"
if command -v free &>/dev/null; then
    free -h
else
    echo "$ram_details"
fi
echo -e "   Top RAM  : $top_ram_process"
echo -e "${CYAN}----------------------------------------------------------${NC}"
echo -e "${GREEN}3. DISK SPACE STATUS${NC}"
if command -v df &>/dev/null; then
    df -h -x devtmpfs -x tmpfs -x squashfs 2>/dev/null
else
    echo "$disk_details"
fi
echo -e "${CYAN}----------------------------------------------------------${NC}"
echo -e "${GREEN}4. DOCKER DAEMON STATUS${NC}"
if [ "$docker_status" = "Running" ]; then
    echo -e "   Status: ${GREEN}Running${NC}"
    echo "$docker_info"
else
    echo -e "   Status: ${RED}$docker_status${NC}"
fi
echo -e "${CYAN}----------------------------------------------------------${NC}"
echo -e "${GREEN}5. KUBERNETES CLUSTER STATUS${NC}"
if [ "$k8s_status" = "Connected" ]; then
    echo -e "   Status: ${GREEN}Connected${NC}"
    echo -e "   Metrics: $k8s_info"
else
    echo -e "   Status: ${RED}$k8s_status${NC}"
fi
echo -e "${CYAN}----------------------------------------------------------${NC}"
echo -e "${GREEN}6. LOG DIAGNOSTICS & SYSTEM ERRORS${NC}"
echo -e "$log_summary"
echo -e "   ${YELLOW}Recent Syslog Errors:${NC}"
echo "$syslog_errors"
echo -e "${CYAN}==========================================================${NC}"

echo -e "\n${GREEN}[SUCCESS] Consolidated report generated and saved to: ${YELLOW}$REPORT_FILE${NC}"
