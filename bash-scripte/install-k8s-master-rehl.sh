#!/bin/bash

# ==============================================================================
# Script Name: install_k8s_master_rhel.sh
# Description: Installs and configures a Kubernetes Master Node (Control Plane)
#              on RHEL/CentOS/Rocky/Alma Linux.
# Author: Antigravity AI
# Date: May 2026
# ==============================================================================

# Exit immediately if a command exits with a non-zero status
set -e

# === CONFIGURATION VARIABLES ===
K8S_VERSION="v1.30"                   # Kubernetes version (e.g., v1.30, v1.29)
POD_CIDR="10.244.0.0/16"             # Pod network CIDR (10.244.0.0/16 is default for Flannel)
CNI_TYPE="flannel"                   # Pod Network CNI - Options: "flannel" or "calico"
APISERVER_ADVERTISE_ADDRESS="10.0.0.105"       # Master Node IP (Leave empty to auto-detect default interface IP)
# ===============================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Log functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 1. Root Check
if [ "$EUID" -ne 0 ]; then
    log_error "Please run this script as root or with sudo."
    exit 1
fi

# 2. OS Check (RedHat-based only)
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID=$ID
    OS_LIKE=$ID_LIKE
else
    log_error "Cannot determine the OS version. /etc/os-release not found."
    exit 1
fi

if [[ "$OS_ID" != "rhel" && "$OS_ID" != "centos" && "$OS_ID" != "rocky" && "$OS_ID" != "almalinux" && "$OS_LIKE" != *"rhel"* ]]; then     
    log_warning "This script is designed for RedHat-based systems (RHEL, CentOS, Rocky Linux, AlmaLinux)."
    read -p "Do you want to continue anyway? (y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        log_info "Installation aborted."
        exit 0
    fi
fi

# 3. Disable Swap
log_info "Disabling Swap..."
swapoff -a
if grep -q "swap" /etc/fstab; then
    sed -i.bak -r 's/^(.*swap.*)$/#\1/g' /etc/fstab
    log_success "Swap entries disabled in /etc/fstab."
else
    log_info "No active swap entries found in /etc/fstab."
fi

# 4. Disable SELinux
log_info "Configuring SELinux to Permissive mode..."
setenforce 0 || true
if [ -f /etc/selinux/config ]; then
    sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
    log_success "SELinux configured to Permissive in /etc/selinux/config."
fi

# 5. Load Kernel Modules
log_info "Loading Kernel Modules (overlay and br_netfilter)..."
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
modprobe overlay
modprobe br_netfilter

# 6. Configure Sysctl for Networking
log_info "Configuring sysctl parameters..."
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sysctl --system

# 7. Configure Firewall for Control Plane
log_info "Configuring firewalld ports for Control Plane (Master)..."
if systemctl is-active --quiet firewalld; then
    # K8s Master ports
    firewall-cmd --permanent --add-port=6443/tcp
    firewall-cmd --permanent --add-port=2379-2380/tcp
    firewall-cmd --permanent --add-port=10250/tcp
    firewall-cmd --permanent --add-port=10259/tcp
    firewall-cmd --permanent --add-port=10257/tcp
    # CNI ports
    firewall-cmd --permanent --add-port=179/tcp
    firewall-cmd --permanent --add-port=4789/udp
    firewall-cmd --permanent --add-port=8472/udp
    firewall-cmd --reload
    log_success "Firewall rules applied for Master node."
else
    log_warning "firewalld is not running. No firewall configurations needed."
fi

# 8. Install Docker CE and Containerd
log_info "Installing Docker CE and Containerd..."
dnf install -y yum-utils device-mapper-persistent-data lvm2
dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
dnf install -y docker-ce docker-ce-cli containerd.io
systemctl enable --now docker
systemctl enable --now containerd

# 9. Configure Containerd CRI with systemd cgroups
log_info "Configuring Containerd..."
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml > /dev/null
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
systemctl restart containerd

# 10. Add Kubernetes Repository
log_info "Adding Kubernetes RPM repository (${K8S_VERSION})..."
cat <<EOF | tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF

# 11. Install Kubeadm, Kubelet, and Kubectl
log_info "Installing kubelet, kubeadm, and kubectl..."
dnf install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
systemctl daemon-reload
systemctl enable --now kubelet

# 12. Pull Kubernetes Images beforehand
log_info "Pulling Kubernetes images..."
kubeadm config images pull

# 13. Initialize Kubernetes Master Node
log_info "Initializing Kubernetes Master Node..."
INIT_CMD="kubeadm init --pod-network-cidr=$POD_CIDR"

if [ -n "$APISERVER_ADVERTISE_ADDRESS" ]; then
    INIT_CMD="$INIT_CMD --apiserver-advertise-address=$APISERVER_ADVERTISE_ADDRESS"
fi

# Auto-detect CPU count and ignore NumCPU error if CPU is 1
NUM_CPUS=$(nproc)
if [ "$NUM_CPUS" -lt 2 ]; then
    log_warning "Only $NUM_CPUS CPU(s) detected. Kubernetes recommends at least 2 CPUs for the Master Node."
    log_info "Automatically adding --ignore-preflight-errors=NumCPU..."
    INIT_CMD="$INIT_CMD --ignore-preflight-errors=NumCPU"
fi

# Execute initialization
eval $INIT_CMD

# 14. Configure Kubectl access for current user and root
log_info "Setting up kubeconfig..."
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

# If run via sudo, configure kubeconfig for the normal user as well
if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
    USER_HOME=$(eval echo ~$SUDO_USER)
    mkdir -p $USER_HOME/.kube
    cp -i /etc/kubernetes/admin.conf $USER_HOME/.kube/config
    chown -R $SUDO_USER:$(id -gn $SUDO_USER) $USER_HOME/.kube
    log_success "kubeconfig configured for user: $SUDO_USER"
fi

# 15. Install Pod Network Add-on (CNI)
log_info "Installing Pod Network Add-on ($CNI_TYPE)..."
export KUBECONFIG=/etc/kubernetes/admin.conf

if [ "$CNI_TYPE" == "flannel" ]; then
    kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
    log_success "Flannel CNI applied."
elif [ "$CNI_TYPE" == "calico" ]; then
    kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/calico.yaml
    log_success "Calico CNI applied."
else
    log_warning "Unknown CNI type. Please apply CNI manually (e.g. kubectl apply -f ...)"
fi

# 16. Final steps and display join command
log_success "Kubernetes Master Node setup is complete!"
echo -e "\n${GREEN}====================================================================="
echo -e "                 KUBERNETES MASTER INITIALIZED"
echo -e "=====================================================================${NC}"
echo -e "To start using your cluster, run the following as a regular user:"
echo -e "   mkdir -p \$HOME/.kube"
echo -e "   sudo cp -i /etc/kubernetes/admin.conf \$HOME/.kube/config"
echo -e "   sudo chown \$(id -u):\$(id -g) \$HOME/.kube/config"
echo -e "\nTo join worker nodes to this cluster, run the following command on each worker node:"
echo -e "${YELLOW}"
kubeadm token create --print-join-command
echo -e "${NC}====================================================================="