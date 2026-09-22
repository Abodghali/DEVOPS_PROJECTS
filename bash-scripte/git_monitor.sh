#!/bin/bash

# ==============================================================================
# Script Name: git_monitor.sh
# Description: Git Repository Monitor. Displays current branch, details of the 
#              last commit, modified/staged files, and untracked files.
#
# Educational Guide:
#   1. Branch and Commit Inspection:
#      - git branch --show-current: Displays the name of the active branch.
#      - git log -1: Retrieves the most recent commit. We customize format using
#        --pretty=format: Hash (%h), Author (%an), Relative date (%ar), Subject (%s).
#   2. Status Parsing (--porcelain):
#      - git status --porcelain provides machine-readable status updates.
#      - Output format is always "XY PATH" (prefix is exactly 3 characters).
#      - Using cut -c 4- is safer than awk because it preserves spaces in filenames.
#      - "?? " indicates untracked files.
#      - Any other prefix (like M, D, A) indicates modified/staged/deleted files.
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
# 2. Argument Parsing and Directory Check
# ------------------------------------------------------------------------------
# Default target directory is the current directory if no argument is passed
TARGET_DIR="${1:-.}"

# Print Banner
echo -e "${BLUE}"
echo "=========================================================="
echo "                 Git Status Monitor                       "
echo "=========================================================="
echo -e "${NC}"

# Navigate to target directory
if [ ! -d "$TARGET_DIR" ]; then
    log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
    log_error "Directory '$TARGET_DIR' does not exist."
    echo -e "Usage: ./git_monitor.sh [path_to_git_repo]\n"
    exit 1
fi

cd "$TARGET_DIR" || exit 1

# Check if inside a valid Git repository
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    echo -e "${RED}[ERROR] '$TARGET_DIR' is not a valid Git repository.${NC}\n"
    exit 1
fi

# ------------------------------------------------------------------------------
# 3. Gathering Git Metadata
# ------------------------------------------------------------------------------
# A. Get Current Branch
branch_name=$(git branch --show-current 2>/dev/null)
[ -z "$branch_name" ] && branch_name=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

# B. Get Last Commit Info
# Format: hash - author (relative_date): subject_line
last_commit=$(git log -1 --pretty=format:"%h - %an (%ar): %s" 2>/dev/null)
[ -z "$last_commit" ] && last_commit="No commits found in this repository."

# C. Get Status Details
status_raw=$(git status --porcelain 2>/dev/null)

# ------------------------------------------------------------------------------
# 4. Display Repository Summary
# ------------------------------------------------------------------------------
echo -e "${YELLOW}Repository Path :${NC} $(pwd)"
echo -e "${YELLOW}Current Branch  :${NC} ${GREEN}$branch_name${NC}"
echo -e "${YELLOW}Last Commit     :${NC} $last_commit"
echo ""

# ------------------------------------------------------------------------------
# 5. Parsing Modified and Untracked Files
# ------------------------------------------------------------------------------
# Temporary files or lists to store names (preserving spacing)
modified_list=()
untracked_list=()

if [ -n "$status_raw" ]; then
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        
        prefix="${line:0:2}"
        filepath="${line:3}"
        
        if [ "$prefix" = "??" ]; then
            untracked_list+=("$filepath")
        else
            # Collect file and describe operation (M=Modified, A=Added, D=Deleted, R=Renamed)
            modified_list+=("[$prefix] $filepath")
        fi
    done <<< "$status_raw"
fi

# A. Display Tracked / Modified Files
echo -e "${CYAN}=== Modified & Staged Files ===${NC}"
if [ ${#modified_list[@]} -gt 0 ]; then
    for item in "${modified_list[@]}"; do
        # Extract status letters and path
        op_label=$(echo "$item" | cut -d' ' -f1)
        file_path=$(echo "$item" | cut -d' ' -f2-)
        
        # Color code based on changes
        if [[ "$op_label" =~ D ]]; then
            printf "  ${RED}%-5s${NC} %s\n" "$op_label" "$file_path"
        elif [[ "$op_label" =~ A ]]; then
            printf "  ${GREEN}%-5s${NC} %s\n" "$op_label" "$file_path"
        else
            printf "  ${YELLOW}%-5s${NC} %s\n" "$op_label" "$file_path"
        fi
    done
else
    echo -e "  ${GREEN}No modified or staged files. Working directory clean.${NC}"
fi
echo ""

# B. Display Untracked Files
echo -e "${CYAN}=== Untracked Files ===${NC}"
if [ ${#untracked_list[@]} -gt 0 ]; then
    for file in "${untracked_list[@]}"; do
        printf "  ${RED}%-5s${NC} %s\n" "[??]" "$file"
    done
else
    echo -e "  ${GREEN}No untracked files found.${NC}"
fi

echo -e "\n${CYAN}==========================================================${NC}"
