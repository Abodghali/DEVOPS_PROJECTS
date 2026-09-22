#!/bin/bash

# ==============================================================================
# Script Name: compare_dirs.sh
# Description: Compares two directories (by default, 'Production' and 'Backup')
#              and reports all discrepancies: files present only in one folder,
#              or files with differing content.
#
# Educational Guide:
#   1. diff Command:
#      - -r option: Recursively compares any subdirectories found.
#      - -q option: Brief format - reports only whether files differ, not the 
#        line-by-line differences.
#   2. Parsing diff Output:
#      - "Only in <path>: <file>": Represents files unique to one folder.
#      - "Files <f1> and <f2> differ": Represents files that exist in both but 
#        have different contents.
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
# 2. Configuration and Setup
# ------------------------------------------------------------------------------
# Default directories
DIR1="${1:-Production}"
DIR2="${2:-Backup}"

# Print Banner
echo -e "${BLUE}"
echo "=========================================================="
echo "              Directory Comparison Script                 "
echo "=========================================================="
echo -e "${NC}"

# Check if directories exist
if [ ! -d "$DIR1" ] || [ ! -d "$DIR2" ]; then
    log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
    log_error "One or both target directories do not exist."
    echo -e "Usage: ./compare_dirs.sh [directory1] [directory2]\n"
    
    # Prompt to create default directories with sample files for testing
    if [ "$DIR1" = "Production" ] && [ "$DIR2" = "Backup" ]; then
        read -p "Would you like to generate sample 'Production' and 'Backup' folders to test? (y/N): " choice
        if [[ "$choice" =~ ^[yY]$ ]]; then
            echo -e "${BLUE}[INFO] Creating sample directories...${NC}"
            mkdir -p Production/subdir Backup/subdir
            
            # Identical files
            echo "This is a shared file" > Production/shared.txt
            echo "This is a shared file" > Backup/shared.txt
            
            # Modified file (different content)
            echo "Production version content" > Production/config.cfg
            echo "Backup version content (different)" > Backup/config.cfg
            
            # Unique files
            echo "Only in Production" > Production/new-feature.js
            echo "Only in Backup (old file)" > Backup/old-code.backup
            echo "Subdir Prod File" > Production/subdir/nested.txt
            
            echo -e "${GREEN}[SUCCESS] Test folders generated. Re-running comparison...${NC}\n"
        else
            exit 1
        fi
    else
        exit 1
    fi
fi

echo -e "${YELLOW}Comparing:${NC} Folder 1: '${GREEN}$DIR1${NC}' <---> Folder 2: '${GREEN}$DIR2${NC}'\n"

# ------------------------------------------------------------------------------
# 3. Running Comparison
# ------------------------------------------------------------------------------
# Execute recursive brief diff
diff_raw=$(diff -rq "$DIR1" "$DIR2" 2>/dev/null)
exit_status=$?

if [ $exit_status -eq 0 ] && [ -z "$diff_raw" ]; then
    echo -e "${GREEN}[SUCCESS] Perfect Match! All files in '$DIR1' and '$DIR2' are identical.${NC}"
    echo -e "${CYAN}==========================================================${NC}"
    exit 0
fi

# ------------------------------------------------------------------------------
# 4. Parsing and Formatting Discrepancies
# ------------------------------------------------------------------------------
# Temporary arrays to hold categorized discrepancies
only_in_1=()
only_in_2=()
modified_files=()

while IFS= read -r line; do
    [ -z "$line" ] && continue
    
    if [[ "$line" =~ ^"Only in "$DIR1 ]]; then
        # Format: Only in Production/subdir: file.txt
        # Extract path and file name
        path_part=$(echo "$line" | cut -d: -f1 | sed "s/^Only in //")
        file_part=$(echo "$line" | cut -d: -f2- | sed "s/^ //")
        only_in_1+=("$path_part/$file_part")
        
    elif [[ "$line" =~ ^"Only in "$DIR2 ]]; then
        path_part=$(echo "$line" | cut -d: -f1 | sed "s/^Only in //")
        file_part=$(echo "$line" | cut -d: -f2- | sed "s/^ //")
        only_in_2+=("$path_part/$file_part")
        
    elif [[ "$line" =~ "differ"$ ]]; then
        # Format: Files Production/config.cfg and Backup/config.cfg differ
        # Extract files
        file1=$(echo "$line" | awk '{print $2}')
        file2=$(echo "$line" | awk '{print $4}')
        modified_files+=("$file1 <-> $file2")
    fi
done <<< "$diff_raw"

# A. Display Files Only in Directory 1 (Production)
if [ ${#only_in_1[@]} -gt 0 ]; then
    echo -e "${GREEN}➕ Files present ONLY in '$DIR1' (New/Added):${NC}"
    for file in "${only_in_1[@]}"; do
        echo -e "  - $file"
    done
    echo ""
fi

# B. Display Files Only in Directory 2 (Backup)
if [ ${#only_in_2[@]} -gt 0 ]; then
    echo -e "${RED}➖ Files present ONLY in '$DIR2' (Deleted/Old):${NC}"
    for file in "${only_in_2[@]}"; do
        echo -e "  - $file"
    done
    echo ""
fi

# C. Display Modified Files (Differing Contents)
if [ ${#modified_files[@]} -gt 0 ]; then
    echo -e "${YELLOW}📝 Files with DIFFERENT content (Modified):${NC}"
    for files in "${modified_files[@]}"; do
        echo -e "  - $files"
    done
    echo ""
fi

# ------------------------------------------------------------------------------
# 5. Summary
# ------------------------------------------------------------------------------
total_diffs=$(( ${#only_in_1[@]} + ${#only_in_2[@]} + ${#modified_files[@]} ))
echo -e "${CYAN}----------------------------------------------------------${NC}"
echo -e "${YELLOW}Summary:${NC} Found ${RED}$total_diffs${NC} difference(s) between the directories."
echo -e "${CYAN}==========================================================${NC}"
