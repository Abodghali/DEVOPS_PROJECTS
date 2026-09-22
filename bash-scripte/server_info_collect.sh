#!/bin/bash

# ==============================================================================
# Script Name: server_report.sh
# Description: Gathers comprehensive server diagnostics and metrics.
#              Outputs a colored version to the console and writes a clean,
#              plain-text version to 'report.txt'.
#
# Educational Guide:
#   1. Hostname & IP:
#      - hostname fetches the machine name.
#      - hostname -I lists all IP addresses assigned to the host.
#   2. Hardware Details (RAM/CPU/Disk):
#      - free -h displays RAM size and usage in human-readable units.
#      - lscpu and /proc/cpuinfo display CPU architecture and model details.
#      - df -h lists disk usage statistics.
#   3. System Details (OS, Kernel, Uptime):
#      - /etc/os-release contains OS distribution info.
#      - uname -r gets the Kernel version.
#      - uptime -p displays the system uptime in a user-friendly format.
#   4. Service State:
#      - systemctl lists running systemd services.
# ==============================================================================

# Colors for Console Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

REPORT_FILE="report.txt"

# ------------------------------------------------------------------------------
# 1. Gathering Information
# ------------------------------------------------------------------------------
echo -e "${BLUE}[INFO] Gathering server information, please wait...${NC}\n"

# Hostname
HOSTNAME=$(hostname)

# IP Addresses
IP_ADDRESSES=$(hostname -I | xargs)
[ -z "$IP_ADDRESSES" ] && IP_ADDRESSES=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7}')
[ -z "$IP_ADDRESSES" ] && IP_ADDRESSES="Not Available (Offline)"

# OS Information
if [ -f /etc/os-release ]; then
    OS_NAME=$(grep -w PRETTY_NAME /etc/os-release | cut -d= -f2- | tr -d '"')
else
    OS_NAME="Unknown Linux Distribution"
fi

# Kernel Version
KERNEL_VERSION=$(uname -r)

# Uptime
SYSTEM_UPTIME=$(uptime -p 2>/dev/null)
[ -z "$SYSTEM_UPTIME" ] && SYSTEM_UPTIME=$(uptime | awk -F', ' '{print $1}')

# CPU Model and Cores
CPU_MODEL=$(grep -m 1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2- | sed 's/^[ \t]*//')
[ -z "$CPU_MODEL" ] && CPU_MODEL=$(lscpu 2>/dev/null | grep 'Model name' | cut -d: -f2- | sed 's/^[ \t]*//')
[ -z "$CPU_MODEL" ] && CPU_MODEL="Unknown CPU"
CPU_CORES=$(nproc 2>/dev/null)
[ -z "$CPU_CORES" ] && CPU_CORES="Unknown"

# RAM Usage
RAM_DETAILS=$(free -h 2>/dev/null)
if [ -z "$RAM_DETAILS" ]; then
    RAM_DETAILS="RAM details not available (free command missing)"
fi

# Disk Usage
DISK_DETAILS=$(df -h -x devtmpfs -x tmpfs -x squashfs 2>/dev/null)
if [ -z "$DISK_DETAILS" ]; then
    DISK_DETAILS="Disk details not available (df command missing)"
fi

# Running Services
RUNNING_SERVICES=""
if command -v systemctl &>/dev/null; then
    RUNNING_SERVICES=$(systemctl list-units --type=service --state=running --no-legend --no-pager 2>/dev/null | awk '{print $1}')
elif command -v service &>/dev/null; then
    RUNNING_SERVICES=$(service --status-all 2>/dev/null | grep '+' | awk '{print $4}')
fi

if [ -z "$RUNNING_SERVICES" ]; then
    RUNNING_SERVICES="No running services detected (or systemd/service utilities missing)."
fi

# ------------------------------------------------------------------------------
# 2. Writing clean report to report.txt
# ------------------------------------------------------------------------------
{
    echo "=========================================================="
    echo "                 SERVER INFORMATION REPORT                "
    echo "=========================================================="
    echo "Generated on : $(date)"
    echo "----------------------------------------------------------"
    echo "Hostname     : $HOSTNAME"
    echo "IP Address   : $IP_ADDRESSES"
    echo "OS           : $OS_NAME"
    echo "Kernel       : $KERNEL_VERSION"
    echo "Uptime       : $SYSTEM_UPTIME"
    echo "----------------------------------------------------------"
    echo "CPU Model    : $CPU_MODEL"
    echo "CPU Cores    : $CPU_CORES cores"
    echo "----------------------------------------------------------"
    echo "RAM Information:"
    echo "$RAM_DETAILS"
    echo "----------------------------------------------------------"
    echo "Disk Information:"
    echo "$DISK_DETAILS"
    echo "----------------------------------------------------------"
    echo "Running Services:"
    echo "$RUNNING_SERVICES"
    echo "=========================================================="
} > "$REPORT_FILE"

# ------------------------------------------------------------------------------
# 3. Printing report with colors to console
# ------------------------------------------------------------------------------
echo -e "${CYAN}==========================================================${NC}"
echo -e "                 ${GREEN}SERVER INFORMATION REPORT${NC}                "
echo -e "${CYAN}==========================================================${NC}"
echo -e "${YELLOW}Generated on :${NC} $(date)"
echo -e "${CYAN}----------------------------------------------------------${NC}"
echo -e "${YELLOW}Hostname     :${NC} $HOSTNAME"
echo -e "${YELLOW}IP Address   :${NC} $IP_ADDRESSES"
echo -e "${YELLOW}OS           :${NC} $OS_NAME"
echo -e "${YELLOW}Kernel       :${NC} $KERNEL_VERSION"
echo -e "${YELLOW}Uptime       :${NC} $SYSTEM_UPTIME"
echo -e "${CYAN}----------------------------------------------------------${NC}"
echo -e "${YELLOW}CPU Model    :${NC} $CPU_MODEL"
echo -e "${YELLOW}CPU Cores    :${NC} $CPU_CORES cores"
echo -e "${CYAN}----------------------------------------------------------${NC}"
echo -e "${YELLOW}RAM Information:${NC}"
if command -v free &>/dev/null; then
    free -h
else
    echo "$RAM_DETAILS"
fi
echo -e "${CYAN}----------------------------------------------------------${NC}"
echo -e "${YELLOW}Disk Information:${NC}"
if command -v df &>/dev/null; then
    df -h -x devtmpfs -x tmpfs -x squashfs
else
    echo "$DISK_DETAILS"
fi
echo -e "${CYAN}----------------------------------------------------------${NC}"
echo -e "${YELLOW}Running Services:${NC}"
echo "$RUNNING_SERVICES"
echo -e "${CYAN}==========================================================${NC}"

echo -e "\n${GREEN}[SUCCESS] Report successfully saved to: ${YELLOW}$REPORT_FILE${NC}"
