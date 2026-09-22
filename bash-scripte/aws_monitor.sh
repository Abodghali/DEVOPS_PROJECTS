#!/bin/bash

# ==============================================================================
# Script Name: aws_monitor.sh
# Description: AWS Resource Monitor script. Scans AWS CLI for EC2 instances
#              (Running/Stopped), EBS volumes, Snapshots, and S3 buckets.
#
# Educational Guide:
#   1. AWS CLI Commands:
#      - aws ec2 describe-instances: Lists EC2 servers. Filter/query with JMESPath.
#      - aws ec2 describe-volumes: Lists EBS storage devices.
#      - aws ec2 describe-snapshots: Lists snapshots owned by the account.
#      - aws s3api list-buckets (or aws s3 ls): Lists S3 buckets.
#   2. JMESPath Querying (--query):
#      - The CLI natively filters JSON responses using JMESPath queries to return
#        clean tab-separated or table-formatted results.
#   3. Resilient Design:
#      - Automatically triggers 'Mock Mode' with simulated cloud resources if
#        AWS CLI is not configured or cannot establish connection, allowing 
#        offline verification.
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
# 2. Connection Check and Mode Setup
# ------------------------------------------------------------------------------
MOCK_MODE=false

# Check if aws cli is installed
if ! command -v aws &>/dev/null; then
    MOCK_MODE=true
# Check if aws credentials are valid and can connect
elif ! aws sts get-caller-identity &>/dev/null; then
    MOCK_MODE=true
fi

# Force mock mode if '--mock' argument is passed
if [ "$1" = "--mock" ]; then
    MOCK_MODE=true
fi

# Print Banner
echo -e "${BLUE}"
echo "=========================================================="
echo "                   AWS Resource Monitor                   "
echo "=========================================================="
echo -e "${NC}"

if [ "$MOCK_MODE" = true ]; then
    echo -e "${YELLOW}[INFO] Running in MOCK MODE (Simulated AWS Resources).${NC}"
    echo -e "To query your real AWS cloud account, run 'aws configure' to set credentials.\n"
    AWS_ACCOUNT="123456789012 (Mock Account)"
    AWS_REGION="us-east-1 (Mock Region)"
else
    AWS_ACCOUNT=$(aws sts get-caller-identity --query "Account" --output text)
    AWS_REGION=$(aws configure get region)
    [ -z "$AWS_REGION" ] && AWS_REGION="us-east-1 (default)"
    echo -e "${GREEN}[SUCCESS] Connected to live AWS account.${NC}"
    echo -e "${YELLOW}Account ID:${NC} $AWS_ACCOUNT | ${YELLOW}Region:${NC} $AWS_REGION\n"
fi

# ------------------------------------------------------------------------------
# 3. Data Gathering (Live vs Mock)
# ------------------------------------------------------------------------------

# EC2 Data
get_ec2_data() {
    if [ "$MOCK_MODE" = true ]; then
        cat <<EOF
i-0123456789abcdef0	t3.medium	running	Web-Server-Prod
i-0abcdef0123456789	t2.micro	running	Worker-Node-1
i-0987654321fedcba0	t2.small	stopped	Staging-DB
i-0fedcba0987654321	t3.nano	stopped	Temp-Testing
EOF
    else
        aws ec2 describe-instances --query 'Reservations[*].Instances[*].[InstanceId,InstanceType,State.Name,Tags[?Key==`Name`].Value | [0]]' --output text 2>/dev/null | sed '/^$/d'
    fi
}

# EBS Data
get_ebs_data() {
    if [ "$MOCK_MODE" = true ]; then
        cat <<EOF
vol-0123456789abcdef0	gp3	80	in-use
vol-0abcdef0123456789	gp2	20	in-use
vol-0987654321fedcba0	gp3	100	available
EOF
    else
        aws ec2 describe-volumes --query 'Volumes[*].[VolumeId,VolumeType,Size,State]' --output text 2>/dev/null | sed '/^$/d'
    fi
}

# Snapshots Data
get_snapshot_data() {
    if [ "$MOCK_MODE" = true ]; then
        cat <<EOF
snap-0123456789abcdef0	vol-0123456789abcdef0	80	2026-07-01T12:00:00Z
snap-0abcdef0123456789	vol-0abcdef0123456789	20	2026-07-05T08:30:00Z
EOF
    else
        aws ec2 describe-snapshots --owner-ids self --query 'Snapshots[*].[SnapshotId,VolumeId,VolumeSize,StartTime]' --output text 2>/dev/null | sed '/^$/d'
    fi
}

# S3 Data
get_s3_data() {
    if [ "$MOCK_MODE" = true ]; then
        cat <<EOF
2026-05-12 10:00:00	prod-data-bucket-secure
2026-06-20 14:30:15	dev-assets-bucket-temp
2026-07-10 09:15:00	db-backups-bucket-daily
EOF
    else
        aws s3api list-buckets --query 'Buckets[*].[CreationDate,Name]' --output text 2>/dev/null | sed '/^$/d'
    fi
}

# Fetch data snapshot
ec2_list=$(get_ec2_data)
ebs_list=$(get_ebs_data)
snap_list=$(get_snapshot_data)
s3_list=$(get_s3_data)

# ------------------------------------------------------------------------------
# 4. Analysis and Counts
# ------------------------------------------------------------------------------
# EC2 counts
ec2_running_count=$(echo "$ec2_list" | awk '$3 == "running"' | wc -l | tr -d ' ')
ec2_stopped_count=$(echo "$ec2_list" | awk '$3 == "stopped"' | wc -l | tr -d ' ')
ec2_total_count=$((ec2_running_count + ec2_stopped_count))

# EBS counts
ebs_in_use=$(echo "$ebs_list" | awk '$4 == "in-use"' | wc -l | tr -d ' ')
ebs_available=$(echo "$ebs_list" | awk '$4 == "available"' | wc -l | tr -d ' ')
ebs_total_count=$((ebs_in_use + ebs_available))

# Snapshot count
snap_total_count=$(echo "$snap_list" | grep -v "^$" | wc -l | tr -d ' ')

# S3 count
s3_total_count=$(echo "$s3_list" | grep -v "^$" | wc -l | tr -d ' ')

# ------------------------------------------------------------------------------
# 5. Output Summary Dashboard
# ------------------------------------------------------------------------------
echo -e "${CYAN}=== AWS Resource Summary Dashboard ===${NC}"
printf "%-25s : %d ( ${GREEN}%d Running${NC} / ${RED}%d Stopped${NC} )\n" "EC2 Instances" "$ec2_total_count" "$ec2_running_count" "$ec2_stopped_count"
printf "%-25s : %d ( ${GREEN}%d In-Use${NC} / ${YELLOW}%d Available${NC} )\n" "EBS Volumes" "$ebs_total_count" "$ebs_in_use" "$ebs_available"
printf "%-25s : %d\n" "EBS Snapshots" "$snap_total_count"
printf "%-25s : %d\n" "S3 Buckets" "$s3_total_count"
echo ""

# ------------------------------------------------------------------------------
# 6. Detailed Tables
# ------------------------------------------------------------------------------

# A. EC2 Instances
echo -e "${CYAN}=== EC2 Instances ===${NC}"
printf "%-22s %-12s %-12s %-25s\n" "INSTANCE ID" "TYPE" "STATE" "NAME / TAG"
echo "----------------------------------------------------------------------------"
if [ -n "$ec2_list" ]; then
    while read -r id type state name; do
        [ -z "$id" ] && continue
        # Set state color
        if [ "$state" = "running" ]; then
            state_colored="${GREEN}running${NC}"
        elif [ "$state" = "stopped" ]; then
            state_colored="${RED}stopped${NC}"
        else
            state_colored="${YELLOW}${state}${NC}"
        fi
        [ -z "$name" ] && name="-"
        printf "%-22s %-12s %-22s %-25s\n" "$id" "$type" "$state_colored" "$name"
    done <<< "$ec2_list"
else
    echo "No EC2 instances detected."
fi
echo ""

# B. EBS Volumes
echo -e "${CYAN}=== EBS Volumes ===${NC}"
printf "%-22s %-8s %-10s %-12s\n" "VOLUME ID" "TYPE" "SIZE (GiB)" "STATE"
echo "----------------------------------------------------------------"
if [ -n "$ebs_list" ]; then
    while read -r id type size state; do
        [ -z "$id" ] && continue
        if [ "$state" = "in-use" ]; then
            state_colored="${GREEN}in-use${NC}"
        elif [ "$state" = "available" ]; then
            state_colored="${YELLOW}available${NC}"
        else
            state_colored="${state}"
        fi
        printf "%-22s %-8s %-10s %-22s\n" "$id" "$type" "$size" "$state_colored"
    done <<< "$ebs_list"
else
    echo "No EBS volumes detected."
fi
echo ""

# C. EBS Snapshots
echo -e "${CYAN}=== EBS Snapshots ===${NC}"
printf "%-22s %-22s %-12s %-22s\n" "SNAPSHOT ID" "VOLUME ID" "SIZE (GiB)" "START TIME"
echo "--------------------------------------------------------------------------------------"
if [ -n "$snap_list" ]; then
    while read -r snap_id vol_id size time; do
        [ -z "$snap_id" ] && continue
        printf "%-22s %-22s %-12s %-22s\n" "$snap_id" "$vol_id" "$size" "$time"
    done <<< "$snap_list"
else
    echo "No EBS snapshots detected."
fi
echo ""

# D. S3 Buckets
echo -e "${CYAN}=== S3 Buckets ===${NC}"
printf "%-25s %-35s\n" "CREATION DATE" "BUCKET NAME"
echo "------------------------------------------------------------"
if [ -n "$s3_list" ]; then
    while read -r date time name; do
        [ -z "$name" ] && continue
        printf "%-25s %-35s\n" "$date $time" "$name"
    done <<< "$s3_list"
else
    echo "No S3 Buckets detected."
fi

echo -e "\n${CYAN}==========================================================${NC}"
