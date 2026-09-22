#!/bin/bash

# ==============================================================================
# Script Name: port_monitor.sh
# Description: Checks the status of essential TCP ports (22, 80, 443, 3306)
#              and reports whether they are open (listening) or closed.
#
# Educational Guide:
#   1. Port Listening (LISTEN state):
#      - An open port means a service is actively listening for incoming connections.
#   2. Detection Methods:
#      - ss -tln: Displays TCP sockets in listening state (modern, fast).
#      - netstat -tln: Deprecated but widely available alternative to ss.
#      - /dev/tcp/127.0.0.1/<port>: Built-in Bash socket connection capability.
#   3. Process Resolution:
#      - Running as root allows the script to read /proc filesystem and map 
#        open ports to their actual process names (e.g., sshd, nginx, mysqld).
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
# 2. Logging and Headers
# ------------------------------------------------------------------------------
# Print Banner
echo -e "${BLUE}"
echo "=========================================================="
echo "                 Port Monitoring Script                   "
echo "=========================================================="
echo -e "${NC}"

# Check for root privilege (optional, but recommended for process name detection)
if [ "$EUID" -ne 0 ]; then
    echo -e "${YELLOW}[WARNING] Run as root/sudo to detect actual process names utilizing the ports.${NC}\n"
fi

# Ports to check
MONITORED_PORTS=(22 80 443 3306)

# ------------------------------------------------------------------------------
# 3. Helper Functions
# ------------------------------------------------------------------------------
# Check if a port is open/listening
is_port_open() {
    local port=$1
    
    # 1. Try 'ss' (modern socket statistics)
    if command -v ss &>/dev/null; then
        if ss -tln | awk '{print $4}' | grep -q -E "(^|:)$port$"; then
            return 0
        fi
    # 2. Try 'netstat' (fallback)
    elif command -v netstat &>/dev/null; then
        if netstat -tln | awk '{print $4}' | grep -q -E "(^|:)$port$"; then
            return 0
        fi
    fi

    # 3. Try Bash raw TCP socket connection
    # (Tries to connect to localhost port using bash built-in /dev/tcp)
    if (timeout 1 bash -c "cat < /dev/tcp/127.0.0.1/$port" &>/dev/null); then
        return 0
    fi

    return 1
}

# Resolve the service/process name using the port
get_service_name() {
    local port=$1
    local process_name=""

    # Attempt to resolve using ss or lsof if run as root
    if [ "$EUID" -eq 0 ]; then
        if command -v ss &>/dev/null; then
            # Extract process name from 'users:(("process_name",pid,fd))'
            process_name=$(ss -tlnp | grep -E "(^|:)$port\s" | grep -o -E 'users:\(\("[^"]+"' | head -n1 | cut -d'"' -f2)
        fi
        
        if [ -z "$process_name" ] && command -v lsof &>/dev/null; then
            process_name=$(lsof -i :$port -sTCP:LISTEN -F c 2>/dev/null | grep '^c' | head -n1 | cut -c2-)
        fi
    fi

    # Fallback to standard/common service name if process name couldn't be resolved
    if [ -z "$process_name" ]; then
        case $port in
            22)   process_name="SSH" ;;
            80)   process_name="HTTP (Web Server)" ;;
            443)  process_name="HTTPS (Web Server)" ;;
            3306) process_name="MySQL/MariaDB Database" ;;
            *)    process_name="Unknown" ;;
        esac
    fi

    echo "$process_name"
}

# ------------------------------------------------------------------------------
# 4. Port Check Execution
# ------------------------------------------------------------------------------
echo -e "${CYAN}Checking port statuses...${NC}\n"
printf "%-10s %-15s %-30s\n" "PORT" "STATUS" "SERVICE / PROCESS"
echo "--------------------------------------------------------"

closed_ports_count=0
open_ports_count=0

for port in "${MONITORED_PORTS[@]}"; do
    service=$(get_service_name "$port")
    
    if is_port_open "$port"; then
        status_label="[ OPEN ]"
        printf "%-10s ${GREEN}%-15s${NC} %-30s\n" "$port" "$status_label" "$service"
        ((open_ports_count++))
    else
        status_label="[ CLOSED ]"
        printf "%-10s ${RED}%-15s${NC} %-30s\n" "$port" "$status_label" "$service"
        ((closed_ports_count++))
    fi
done

# ------------------------------------------------------------------------------
# 5. Summary
# ------------------------------------------------------------------------------
echo "--------------------------------------------------------"
if [ "$closed_ports_count" -eq 0 ]; then
    echo -e "${GREEN}[SUCCESS] All monitored ports are open and listening.${NC}"
else
    echo -e "${YELLOW}[ALERT] Port scan completed: $open_ports_count Open, $closed_ports_count Closed.${NC}"
fi
echo -e "\n${CYAN}==========================================================${NC}"
