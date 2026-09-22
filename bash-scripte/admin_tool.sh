#!/bin/bash

# ==============================================================================
# Script Name: admin_tool.sh
# Description: Master Linux Administration Tool. Provides an interactive menu
#              integrating system monitoring, docker cleanup, backups, log analysis,
#              user management, and DevOps health audits.
#
# Educational Guide:
#   1. Bash Interactive Menus:
#      - Uses a infinite while loop containing a select-like case structure.
#      - clear command resets the terminal view on each menu render.
#   2. Modular Script Reuse:
#      - Checks if individual utility scripts exist in the current folder,
#        executes them dynamically, and falls back to native shell commands
#        if they are missing.
#   3. Submenus:
#      - Options (Docker, Logs, Backup, Users, Services) open secondary menus
#        to keep options organized without violating the 1-9 structure.
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
# 2. Helper Utilities
# ------------------------------------------------------------------------------
log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Run a script if it exists, otherwise execute fallback command
run_script() {
    local script_name="$1"
    local fallback_cmd="$2"
    
    echo -e "\n${CYAN}>>> Executing module: $script_name...${NC}\n"
    if [ -f "./$script_name" ]; then
        chmod +x "./$script_name"
        ./"$script_name"
    else
        log_warning "Script './$script_name' not found in $(pwd)."
        log_warning "Running native fallback command instead..."
        echo ""
        eval "$fallback_cmd"
    fi
    echo -e "\n${BLUE}Press [Enter] to return to the menu...${NC}"
    read -r
}

# ------------------------------------------------------------------------------
# 3. Submenus Definitions
# ------------------------------------------------------------------------------

# Option 4: Docker Menu
show_docker_menu() {
    while true; do
        clear
        echo -e "${BLUE}========================================${NC}"
        echo -e "            Docker Manager              "
        echo -e "${BLUE}========================================${NC}"
        echo "  1) List Running Containers"
        echo "  2) Run Docker Cleanup (docker_clean.sh)"
        echo "  3) Return to Main Menu"
        echo -e "${BLUE}========================================${NC}"
        read -p "Select an option [1-3]: " sub_ch
        
        case "$sub_ch" in
            1)
                echo ""
                if command -v docker &>/dev/null; then
                    docker ps -a
                else
                    log_error "Docker is not installed on this system."
                fi
                echo -e "\n${BLUE}Press [Enter] to continue...${NC}"
                read -r
                ;;
            2)
                run_script "docker_clean.sh" "docker system prune -af"
                ;;
            3)
                break
                ;;
            *)
                log_error "Invalid selection."
                sleep 1
                ;;
        esac
    done
}

# Option 5: Logs Menu
show_logs_menu() {
    while true; do
        clear
        echo -e "${BLUE}========================================${NC}"
        echo -e "           Logs & Analytics             "
        echo -e "${BLUE}========================================${NC}"
        echo "  1) Run Log Analyzer (log_analyzer.sh)"
        echo "  2) Run Log Size Monitor (log_size_monitor.sh)"
        echo "  3) Return to Main Menu"
        echo -e "${BLUE}========================================${NC}"
        read -p "Select an option [1-3]: " sub_ch
        
        case "$sub_ch" in
            1)
                run_script "log_analyzer.sh" "cat access.log | head -n 25 2>/dev/null || echo 'access.log not found.'"
                ;;
            2)
                run_script "log_size_monitor.sh" "ls -lh access.log 2>/dev/null || echo 'access.log not found.'"
                ;;
            3)
                break
                ;;
            *)
                log_error "Invalid selection."
                sleep 1
                ;;
        esac
    done
}

# Option 6: Backup Menu
show_backup_menu() {
    while true; do
        clear
        echo -e "${BLUE}========================================${NC}"
        echo -e "           Backup & Archive             "
        echo -e "${BLUE}========================================${NC}"
        echo "  1) Database Backup (db_backup.sh)"
        echo "  2) File Backup with Retention (auto_backup.sh)"
        echo "  3) Return to Main Menu"
        echo -e "${BLUE}========================================${NC}"
        read -p "Select an option [1-3]: " sub_ch
        
        case "$sub_ch" in
            1)
                run_script "db_backup.sh" "echo 'No database backup script fallback available.'"
                ;;
            2)
                run_script "auto_backup.sh" "echo 'No file backup script fallback available.'"
                ;;
            3)
                break
                ;;
            *)
                log_error "Invalid selection."
                sleep 1
                ;;
        esac
    done
}

# Option 7: Users Menu
show_users_menu() {
    while true; do
        clear
        echo -e "${BLUE}========================================${NC}"
        echo -e "         User & Group Control           "
        echo -e "${BLUE}========================================${NC}"
        echo "  1) Create New User (create_user.sh)"
        echo "  2) Manage User Permissions (manage_permissions.sh)"
        echo "  3) Return to Main Menu"
        echo -e "${BLUE}========================================${NC}"
        read -p "Select an option [1-3]: " sub_ch
        
        case "$sub_ch" in
            1)
                run_script "create_user.sh" "echo 'Requires interactive script execution.'"
                ;;
            2)
                run_script "manage_permissions.sh" "echo 'Requires interactive script execution.'"
                ;;
            3)
                break
                ;;
            *)
                log_error "Invalid selection."
                sleep 1
                ;;
        esac
    done
}

# Option 8: Service Restart, Deployment & Health Menu
show_services_menu() {
    while true; do
        clear
        echo -e "${BLUE}========================================${NC}"
        echo -e "    Services, Deployment & Audits       "
        echo -e "${BLUE}========================================${NC}"
        echo "  1) Restart a System Service (Systemd/PM2)"
        echo "  2) Run Application Deployment (auto_deploy.sh)"
        echo "  3) Web & Ports Health Check (website_monitor.sh / port_monitor.sh)"
        echo "  4) SSL Certificate Monitor (ssl_monitor.sh)"
        echo "  5) Kubernetes Cluster Health Check (k8s_monitor.sh)"
        echo "  6) AWS Resource Audit (aws_monitor.sh)"
        echo "  7) Generate Daily Health Report (daily_report.sh)"
        echo "  8) Return to Main Menu"
        echo -e "${BLUE}========================================${NC}"
        read -p "Select an option [1-8]: " sub_ch
        
        case "$sub_ch" in
            1)
                echo ""
                read -p "Enter service name to restart: " sname
                if [ -n "$sname" ]; then
                    if command -v systemctl &>/dev/null; then
                        sudo systemctl restart "$sname" && echo -e "${GREEN}[SUCCESS] Systemd service '$sname' restarted.${NC}"
                    elif command -v pm2 &>/dev/null; then
                        pm2 restart "$sname" && echo -e "${GREEN}[SUCCESS] PM2 service '$sname' restarted.${NC}"
                    else
                        log_warning "Neither systemctl nor pm2 detected."
                        sudo service "$sname" restart
                    fi
                else
                    log_warning "Service name cannot be empty."
                fi
                echo -e "\n${BLUE}Press [Enter] to continue...${NC}"
                read -r
                ;;
            2)
                run_script "auto_deploy.sh" "echo 'Auto Deploy requires script execution.'"
                ;;
            3)
                echo -e "\n${CYAN}>>> Checking Web Targets...${NC}"
                if [ -f "./website_monitor.sh" ]; then
                    chmod +x ./website_monitor.sh
                    ./website_monitor.sh
                fi
                echo -e "\n${CYAN}>>> Checking Local Ports...${NC}"
                if [ -f "./port_monitor.sh" ]; then
                    chmod +x ./port_monitor.sh
                    ./port_monitor.sh
                fi
                echo -e "\n${BLUE}Press [Enter] to continue...${NC}"
                read -r
                ;;
            4)
                run_script "ssl_monitor.sh" "echo 'SSL Monitor requires script execution.'"
                ;;
            5)
                run_script "k8s_monitor.sh" "kubectl get nodes 2>/dev/null || echo 'Kubernetes commands unavailable.'"
                ;;
            6)
                run_script "aws_monitor.sh" "aws sts get-caller-identity 2>/dev/null || echo 'AWS commands unavailable.'"
                ;;
            7)
                # Check for daily_report.sh first, fall back to server_info_collect.sh
                if [ -f "./daily_report.sh" ]; then
                    run_script "daily_report.sh" "echo 'Error running report.'"
                else
                    run_script "server_info_collect.sh" "echo 'No report scripts found.'"
                fi
                ;;
            8)
                break
                ;;
            *)
                log_error "Invalid selection."
                sleep 1
                ;;
        esac
    done
}

# ------------------------------------------------------------------------------
# 4. Main Menu Loop
# ------------------------------------------------------------------------------
while true; do
    clear
    echo -e "${BLUE}========================================${NC}"
    echo -e "            Linux Admin Tool            "
    echo -e "${BLUE}========================================${NC}"
    echo "  1. Disk"
    echo "  2. CPU"
    echo "  3. RAM"
    echo "  4. Docker"
    echo "  5. Logs"
    echo "  6. Backup"
    echo "  7. Users"
    echo "  8. Restart Service"
    echo "  9. Exit"
    echo -e "${BLUE}========================================${NC}"
    read -p "Select an option [1-9]: " main_choice
    
    case "$main_choice" in
        1)
            run_script "disk_monitor.sh" "df -h"
            ;;
        2)
            run_script "cpu_monitor.sh" "top -bn1 2>/dev/null | grep 'Cpu(s)' || uptime"
            ;;
        3)
            run_script "ram_monitor.sh" "free -h"
            ;;
        4)
            show_docker_menu
            ;;
        5)
            show_logs_menu
            ;;
        6)
            show_backup_menu
            ;;
        7)
            show_users_menu
            ;;
        8)
            show_services_menu
            ;;
        9)
            echo -e "\n${GREEN}Thank you for using Linux Admin Tool. Goodbye!${NC}\n"
            exit 0
            ;;
        *)
            log_error "Invalid selection. Please enter a number between 1 and 9."
            sleep 1.5
            ;;
    esac
done
