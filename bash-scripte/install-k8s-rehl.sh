#!/bin/bash

# ==============================================================================
# Script Name: install_k8s_rhel.sh
# Description: Installs Docker, Containerd, kubelet, kubeadm, and kubectl on RHEL/CentOS/Rocky/Alma Linux.
# Author: Antigravity AI
# Date: May 2026
# ==============================================================================

# Exit immediately if a command exits with a non-zero status
set -e

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
else
    log_success "Compatible OS detected: $NAME ($VERSION)"
fi

# 3. Configure Kubernetes Version
K8S_VERSION="v1.30"
log_info "Configured Kubernetes version to install: ${K8S_VERSION}"

# 4. Disable Swap (Required by Kubernetes)
log_info "Disabling Swap..."
swapoff -a
# Comment out swap entries in /etc/fstab
if grep -q "swap" /etc/fstab; then
    sed -i.bak -r 's/^(.*swap.*)$/#\1/g' /etc/fstab
    log_success "Swap entries disabled in /etc/fstab."
else
    log_info "No active swap entries found in /etc/fstab."
fi

# 5. Disable SELinux (Required/Recommended)
log_info "Configuring SELinux to Permissive mode..."
setenforce 0 || true
if [ -f /etc/selinux/config ]; then
    sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
    log_success "SELinux configured to Permissive in /etc/selinux/config."
else
    log_warning "/etc/selinux/config not found. Make sure SELinux is set to permissive."
fi

# 6. Load Kernel Modules
log_info "Loading Kernel Modules (overlay and br_netfilter)..."
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter
log_success "Kernel modules loaded successfully."

# 7. Configure Sysctl for Networking
log_info "Configuring sysctl parameters for Kubernetes networking..."
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system
log_success "Sysctl networking parameters applied."

# 8. Firewall Settings Choice
echo -e "\n${BLUE}How would you like to configure the firewall (firewalld)?${NC}"
echo "1) Disable firewalld completely (Recommended for development/test labs)"
echo "2) Open required ports for Control Plane (Master Node)"
echo "3) Open required ports for Worker Node"
echo "4) Do nothing (keep current firewall settings)"
read -p "Enter choice (1-4): " fw_choice

case $fw_choice in
    1)
        log_info "Stopping and disabling firewalld..."
        systemctl stop firewalld || true
        systemctl disable firewalld || true
        log_success "Firewall disabled."
        ;;
    2)
        log_info "Opening Control Plane ports..."
        if systemctl is-active --quiet firewalld; then
            # Control Plane ports: API Server (6443), etcd (2379-2380), Kubelet (10250), Scheduler (10259), Controller (10257)
            firewall-cmd --permanent --add-port=6443/tcp
            firewall-cmd --permanent --add-port=2379-2380/tcp
            firewall-cmd --permanent --add-port=10250/tcp
            firewall-cmd --permanent --add-port=10259/tcp
            firewall-cmd --permanent --add-port=10257/tcp
            # Open port for CNI (e.g. Flannel vxlan 8472 udp, Calico BGP 179 tcp)
            firewall-cmd --permanent --add-port=179/tcp
            firewall-cmd --permanent --add-port=4789/udp
            firewall-cmd --permanent --add-port=8472/udp
            firewall-cmd --reload
            log_success "Master Node ports opened."
        else
            log_warning "firewalld is not running. Skip opening ports."
        fi
        ;;
    3)
        log_info "Opening Worker Node ports..."
        if systemctl is-active --quiet firewalld; then
            # Worker ports: Kubelet (10250), NodePort Services (30000-32767)
            firewall-cmd --permanent --add-port=10250/tcp
            firewall-cmd --permanent --add-port=30000-32767/tcp
            # Open port for CNI
            firewall-cmd --permanent --add-port=179/tcp
            firewall-cmd --permanent --add-port=4789/udp
            firewall-cmd --permanent --add-port=8472/udp
            firewall-cmd --reload
            log_success "Worker Node ports opened."
        else
            log_warning "firewalld is not running. Skip opening ports."
        fi
        ;;
    *)
        log_info "Firewall configurations left untouched."
        ;;
esac

# 9. Install Docker CE and Containerd
log_info "Installing Docker CE and Containerd..."

# Install required package manager helpers
dnf install -y yum-utils device-mapper-persistent-data lvm2

# Add Docker CE Repo
dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

# Install docker components and containerd
dnf install -y docker-ce docker-ce-cli containerd.io

# Enable and start services
systemctl enable --now docker
systemctl enable --now containerd

log_success "Docker CE and Containerd installed and started."

# 10. Configure Containerd CRI with systemd cgroups
log_info "Configuring Containerd..."
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml > /dev/null

# Set SystemdCgroup to true in containerd config
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml

# Restart containerd to apply changes
systemctl restart containerd
log_success "Containerd configured with SystemdCgroup=true and restarted."

# 11. Add Kubernetes Repository
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

log_success "Kubernetes repository added."

# 12. Install Kubeadm, Kubelet, and Kubectl
log_info "Installing kubelet, kubeadm, and kubectl..."
dnf install -y kubelet kubeadm kubectl --disableexcludes=kubernetes

# Enable and start kubelet
systemctl daemon-reload
systemctl enable --now kubelet

log_success "kubelet, kubeadm, and kubectl installed and started successfully!"

# 13. System Verification
echo -e "\n${BLUE}========== VERIFYING INSTALLATION ==========${NC}"
docker --version && log_success "Docker verified." || log_error "Docker is not running correctly."
containerd --version && log_success "Containerd verified." || log_error "Containerd is not running correctly."
kubeadm version && log_success "kubeadm verified." || log_error "kubeadm is not running correctly."
kubectl version --client && log_success "kubectl verified." || log_error "kubectl is not running correctly."
systemctl is-active kubelet && log_success "kubelet service is running." || log_warning "kubelet service is not running yet (normal before running kubeadm init/join)."

echo -e "\n${GREEN}============================================="
echo -e "  INSTALLATION COMPLETED SUCCESSFULLY!"
echo -e "=============================================${NC}"
echo -e "Next steps:"
echo -e "1. If this is the Master node, initialize the cluster:"
echo -e "   ${YELLOW}sudo kubeadm init --pod-network-cidr=10.244.0.0/16${NC}"
echo -e "2. If this is a Worker node, join the cluster using the command generated by the Master node."
echo -e "============================================="