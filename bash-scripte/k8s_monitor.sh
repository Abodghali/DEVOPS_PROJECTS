#!/bin/bash

# ==============================================================================
# Script Name: k8s_monitor.sh
# Description: Monitors Kubernetes Pods health. Uses kubectl to detect and
#              display Pending Pods, CrashLoopBackOff states, and restart counts.
#
# Educational Guide:
#   1. Kubectl Commands:
#      - kubectl get pods -A: Retrieves Pods across all namespaces.
#      - --no-headers: Suppresses header output, ideal for scripting.
#   2. Log Parsing and Fields:
#      - Col 1: Namespace
#      - Col 2: Name
#      - Col 3: Ready state (e.g. 1/1)
#      - Col 4: Status (Running, Pending, CrashLoopBackOff, etc.)
#      - Col 5: Restart Count
#      - Col 6: Age
#   3. Resilient Design:
#      - Automatically switches to 'Mock Mode' with simulated data if kubectl is 
#        not installed or cannot connect to a cluster, allowing offline testing.
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
# 2. Simulated/Mock Data for Offline Testing
# ------------------------------------------------------------------------------
MOCK_DATA="kube-system   coredns-78fcdf6894-abcde     1/1   Running            3     10d
default       my-web-app-12345-fghij       0/1   CrashLoopBackOff   15    3h
default       db-service-abcde-12345       0/1   Pending            0     12m
kube-system   kube-proxy-abcde             1/1   Running            0     10d
default       payment-api-54321-abcde      1/1   Running            0     5h
production    frontend-77889-xyz12         0/1   ImagePullBackOff   0     45m
production    backend-66778-abcde          0/1   Pending            0     5m
production    cache-redis-0                1/1   Running            12    2d
kube-system   kube-apiserver-minikube      1/1   Running            1     24d"

# ------------------------------------------------------------------------------
# 3. Connection Check and Mode Setup
# ------------------------------------------------------------------------------
MOCK_MODE=false

# Check if kubectl is available
if ! command -v kubectl &>/dev/null; then
    MOCK_MODE=true
# If kubectl is available, check if we can connect to a cluster
elif ! kubectl cluster-info &>/dev/null; then
    MOCK_MODE=true
fi

# Force mock mode if '--mock' argument is passed
if [ "$1" = "--mock" ]; then
    MOCK_MODE=true
fi

# Print Banner
echo -e "${BLUE}"
echo "=========================================================="
echo "               Kubernetes Pod Monitor                     "
echo "=========================================================="
echo -e "${NC}"

if [ "$MOCK_MODE" = true ]; then
    echo -e "${YELLOW}[INFO] Running in MOCK MODE (Simulated Cluster Data).${NC}"
    echo -e "To connect to a live cluster, ensure your KUBECONFIG is set and kubectl is working.\n"
else
    CURRENT_CONTEXT=$(kubectl config current-context 2>/dev/null)
    echo -e "${GREEN}[SUCCESS] Connected to live cluster.${NC}"
    echo -e "${YELLOW}Current Context:${NC} $CURRENT_CONTEXT\n"
fi

# ------------------------------------------------------------------------------
# 4. Data Extraction Functions
# ------------------------------------------------------------------------------
get_raw_pods() {
    if [ "$MOCK_MODE" = true ]; then
        echo "$MOCK_DATA"
    else
        kubectl get pods -A --no-headers 2>/dev/null
    fi
}

# ------------------------------------------------------------------------------
# 5. Analysis and Reporting
# ------------------------------------------------------------------------------
# Fetch pods snapshot
pods_list=$(get_raw_pods)

# Check if we got any data
if [ -z "$pods_list" ]; then
    echo -e "${RED}[ERROR] No Pods found or failed to retrieve data.${NC}"
    exit 1
fi

# A. State Count Summary
total_pods=$(echo "$pods_list" | wc -l | tr -d ' ')
running_pods=$(echo "$pods_list" | awk '$4 == "Running" {print}' | wc -l | tr -d ' ')
pending_pods=$(echo "$pods_list" | awk '$4 == "Pending" {print}' | wc -l | tr -d ' ')
crashloop_pods=$(echo "$pods_list" | awk '$4 ~ /CrashLoopBackOff/ {print}' | wc -l | tr -d ' ')
other_err_pods=$(echo "$pods_list" | awk '$4 != "Running" && $4 != "Pending" && $4 !~ /CrashLoopBackOff/ {print}' | wc -l | tr -d ' ')

echo -e "${CYAN}=== Pods Status Summary ===${NC}"
printf "%-20s : %s\n" "Total Pods" "$total_pods"
printf "%-20s : ${GREEN}%s${NC}\n" "Running" "$running_pods"
printf "%-20s : ${YELLOW}%s${NC}\n" "Pending" "$pending_pods"
printf "%-20s : ${RED}%s${NC}\n" "CrashLoopBackOff" "$crashloop_pods"
printf "%-20s : ${RED}%s${NC}\n" "Other Unhealthy/Errors" "$other_err_pods"
echo ""

# B. Pending Pods Section
echo -e "${CYAN}=== Pending Pods ===${NC}"
printf "%-15s %-35s %-10s\n" "NAMESPACE" "POD NAME" "AGE"
echo "------------------------------------------------------------"
pending_found=0
while read -r ns name ready status restarts age; do
    [ -z "$ns" ] && continue
    pending_found=1
    printf "%-15s %-35s %-10s\n" "$ns" "$name" "$age"
done < <(echo "$pods_list" | awk '$4 == "Pending" {print $1, $2, $3, $4, $5, $6}')

if [ $pending_found -eq 0 ]; then
    echo -e "${GREEN}No Pending pods found.${NC}"
fi
echo ""

# C. CrashLoopBackOff and Unhealthy Pods Section
echo -e "${CYAN}=== CrashLoopBackOff & Error Pods ===${NC}"
printf "%-15s %-35s %-18s %-8s\n" "NAMESPACE" "POD NAME" "STATUS" "RESTARTS"
echo "----------------------------------------------------------------------------"
unhealthy_found=0
while read -r ns name ready status restarts age; do
    [ -z "$ns" ] && continue
    unhealthy_found=1
    printf "%-15s %-35s ${RED}%-18s${NC} %-8s\n" "$ns" "$name" "$status" "$restarts"
done < <(echo "$pods_list" | awk '$4 ~ /CrashLoopBackOff|Error|Failed|BackOff/ {print $1, $2, $3, $4, $5, $6}')

if [ $unhealthy_found -eq 0 ]; then
    echo -e "${GREEN}No CrashLoopBackOff or Error state pods found.${NC}"
fi
echo ""

# D. High Restart Counts Section (> 0 restarts)
echo -e "${CYAN}=== Pods with Restart Counts > 0 ===${NC}"
printf "%-15s %-35s %-10s %-8s\n" "NAMESPACE" "POD NAME" "STATUS" "RESTARTS"
echo "----------------------------------------------------------------------------"
restarts_found=0
while read -r ns name ready status restarts age; do
    [ -z "$ns" ] && continue
    restarts_found=1
    # Highlight high restarts (> 10) in red, low restarts in yellow
    if [ "$restarts" -ge 10 ]; then
        printf "%-15s %-35s %-10s ${RED}%-8s${NC}\n" "$ns" "$name" "$status" "$restarts"
    else
        printf "%-15s %-35s %-10s ${YELLOW}%-8s${NC}\n" "$ns" "$name" "$status" "$restarts"
    fi
done < <(echo "$pods_list" | awk '$5 > 0 {print $1, $2, $3, $4, $5, $6}')

if [ $restarts_found -eq 0 ]; then
    echo -e "${GREEN}No pods with restarts detected.${NC}"
fi

echo -e "\n${CYAN}==========================================================${NC}"
