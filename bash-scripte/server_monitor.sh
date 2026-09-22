#!/bin/bash

# ==============================================================================
# Script Name: server_monitor.sh
# Description: Multi-server monitoring script. Checks Ping availability,
#              SSH port accessibility, CPU usage, and Disk space.
#              Outputs a summary highlighting healthy (✓) and failed (✗) servers.
#
# Educational Guide:
#   1. Ping Check:
#      - ping -c 1 -W 2 sends 1 packet with a 2-second timeout.
#   2. SSH Port Check:
#      - Uses Bash's built-in TCP socket redirection /dev/tcp/<host>/<port>
#        to check if port 22 is listening without requiring full authentication.
#   3. Remote Diagnostics (SSH Command Execution):
#      - ssh -o ConnectTimeout=2 runs commands on remote servers.
#      - Reads CPU load and disk consumption.
#      - Requires key-based passwordless SSH authentication for remote collection.
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. Configuration Section
# ------------------------------------------------------------------------------
# Servers to monitor in "DisplayName|IP_or_Hostname" format
# Server3 uses a non-routable documentation IP (192.0.2.1) to demonstrate failure
SERVERS=(
    "Server1|127.0.0.1"
    "Server2|localhost"
    "Server3|192.0.2.1"
)

# Threshold limits
CPU_THRESHOLD=90      # % CPU usage threshold
DISK_THRESHOLD=90     # % Disk usage threshold

# ------------------------------------------------------------------------------
# 2. Colors for Console Output
# ------------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Print Banner
echo -e "${BLUE}"
echo "=========================================================="
echo "                 Server Fleet Monitor                     "
echo "=========================================================="
echo -e "${NC}"

# ------------------------------------------------------------------------------
# 3. Monitoring Logic
# ------------------------------------------------------------------------------
declare -A RESULTS
declare -A DETAILS

for item in "${SERVERS[@]}"; do
    IFS="|" read -r name host <<< "$item"
    
    log_info="Checking $name ($host)..."
    echo -e "${BLUE}[INFO]${NC} $log_info"
    
    ping_ok=false
    ssh_ok=false
    cpu_ok=true
    disk_ok=true
    
    # A. Ping check
    if ping -c 1 -W 2 "$host" &>/dev/null; then
        ping_ok=true
    fi
    
    # B. SSH Port 22 check
    if (timeout 2 bash -c "cat < /dev/tcp/$host/22" &>/dev/null); then
        ssh_ok=true
    fi
    
    # C. CPU & Disk Checks (If ping & ssh are up)
    cpu_val=""
    disk_val=""
    auth_failed=false
    
    if [ "$ping_ok" = true ] && [ "$ssh_ok" = true ]; then
        if [ "$host" = "127.0.0.1" ] || [ "$host" = "localhost" ]; then
            # Run local checks
            disk_val=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')
            cpu_val=$(top -bn1 2>/dev/null | grep "Cpu(s)" | awk '{print $2 + $4}' | cut -d. -f1)
            [ -z "$cpu_val" ] && cpu_val=$(uptime | awk -F'load average:' '{print $2}' | awk -F',' '{print $1}' | sed 's/ //g' | cut -d. -f1)
        else
            # Run remote checks via non-interactive SSH
            remote_info=$(ssh -o ConnectTimeout=2 -o BatchMode=yes -o StrictHostKeyChecking=no "$host" \
                "df -h / | awk 'NR==2 {print \$5}' | tr -d '%'; top -bn1 2>/dev/null | grep 'Cpu(s)' | awk '{print \$2 + \$4}' | cut -d. -f1" 2>/dev/null)
            
            if [ $? -eq 0 ] && [ -n "$remote_info" ]; then
                disk_val=$(echo "$remote_info" | sed -n '1p')
                cpu_val=$(echo "$remote_info" | sed -n '2p')
            else
                auth_failed=true
            fi
        fi
        
        # Verify CPU usage
        if [ -n "$cpu_val" ]; then
            if [ "$cpu_val" -ge "$CPU_THRESHOLD" ]; then
                cpu_ok=false
            fi
        fi
        
        # Verify Disk usage
        if [ -n "$disk_val" ]; then
            if [ "$disk_val" -ge "$DISK_THRESHOLD" ]; then
                disk_ok=false
            fi
        fi
    fi
    
    # Build detailed result text
    detail_msg="Ping: "
    if [ "$ping_ok" = true ]; then
        detail_msg+="${GREEN}OK${NC} | SSH Port: "
    else
        detail_msg+="${RED}FAIL${NC} | SSH Port: "
    fi
    
    if [ "$ssh_ok" = true ]; then
        detail_msg+="${GREEN}OPEN${NC}"
    else
        detail_msg+="${RED}CLOSED${NC}"
    fi
    
    if [ "$ssh_ok" = true ] && [ "$ping_ok" = true ]; then
        if [ "$auth_failed" = true ]; then
            detail_msg+=" | CPU/Disk: ${YELLOW}Key Auth Required${NC}"
        else
            # CPU Status display
            if [ "$cpu_ok" = true ]; then
                detail_msg+=" | CPU: ${GREEN}OK (${cpu_val}%)${NC}"
            else
                detail_msg+=" | CPU: ${RED}FAIL (${cpu_val}%)${NC}"
            fi
            
            # Disk Status display
            if [ "$disk_ok" = true ]; then
                detail_msg+=" | Disk: ${GREEN}OK (${disk_val}%)${NC}"
            else
                detail_msg+=" | Disk: ${RED}FAIL (${disk_val}%)${NC}"
            fi
        fi
    fi
    
    DETAILS["$name"]="$detail_msg"
    
    # Overall server check outcome
    if [ "$ping_ok" = true ] && [ "$ssh_ok" = true ] && [ "$cpu_ok" = true ] && [ "$disk_ok" = true ]; then
        RESULTS["$name"]="✓"
    else
        RESULTS["$name"]="✗"
    fi
done

# ------------------------------------------------------------------------------
# 4. Final Report Output
# ------------------------------------------------------------------------------
echo -e "\n${CYAN}==========================================================${NC}"
echo -e "                   ${GREEN}MONITORING REPORT SUMMARY${NC}              "
echo -e "${CYAN}==========================================================${NC}"

for item in "${SERVERS[@]}"; do
    IFS="|" read -r name host <<< "$item"
    status="${RESULTS[$name]}"
    details="${DETAILS[$name]}"
    
    if [ "$status" = "✓" ]; then
        echo -e "${GREEN}✓ ${NC} ${name}  [${details}]"
    else
        echo -e "${RED}✗ ${NC} ${name}  [${details}]"
    fi
done

echo -e "${CYAN}==========================================================${NC}"
