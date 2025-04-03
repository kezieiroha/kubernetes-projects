#!/bin/bash
# Kezie Iroha
# Multipass setup script for Kelsey Hightower's "Kubernetes The Hard Way" lab

set -e  # Exit on error

# Define colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# VM configurations - using simple arrays for better compatibility
VM_NAMES=("jumpbox" "server" "node-0" "node-1")
VM_SPECS=("cpus=2,memory=1G,disk=10G" "cpus=2,memory=2G,disk=20G" "cpus=2,memory=2G,disk=20G" "cpus=2,memory=2G,disk=20G")

# Check if multipass is installed
if ! command -v multipass &> /dev/null; then
    echo -e "${RED}Multipass is not installed. Please install it with:${NC}"
    echo "brew install --cask multipass"
    exit 1
fi

# Function to create VMs
create_vms() {
    echo -e "${GREEN}Creating VMs for Kubernetes The Hard Way...${NC}"
    
    for i in "${!VM_NAMES[@]}"; do
        VM="${VM_NAMES[$i]}"
        SPEC="${VM_SPECS[$i]}"
        
        # Parse the specs
        IFS=',' read -r -a specs <<< "$SPEC"
        cpus=$(echo "${specs[0]}" | cut -d= -f2)
        mem=$(echo "${specs[1]}" | cut -d= -f2)
        disk=$(echo "${specs[2]}" | cut -d= -f2)
        
        # Check if VM already exists
        if multipass info "$VM" &> /dev/null; then
            echo -e "${YELLOW}VM '$VM' already exists. Skipping creation.${NC}"
            continue
        fi
        
        echo -e "Creating VM: $VM (CPUs: $cpus, Memory: $mem, Disk: $disk)"
        multipass launch --name "$VM" --cpus "$cpus" --memory "$mem" --disk "$disk"
    done
}

# Function to provision VMs
provision_vms() {
    echo -e "${GREEN}Provisioning VMs...${NC}"
    
    # Enable root access on all VMs
    for VM in "${VM_NAMES[@]}"; do
        echo "Setting up root access for $VM..."
        multipass exec "$VM" -- sudo bash -c "echo 'root:kuberoot' | chpasswd"
        multipass exec "$VM" -- sudo bash -c "sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config"
        
        # Check which SSH service name is used (Ubuntu uses ssh.service, others might use sshd.service)
        multipass exec "$VM" -- sudo bash -c "if systemctl list-unit-files | grep -q ssh.service; then systemctl restart ssh; else systemctl restart sshd; fi"
    done
    
    # Install common tools on all VMs
    for VM in "${VM_NAMES[@]}"; do
        echo "Installing tools on $VM..."
        multipass exec "$VM" -- sudo bash -c "
            apt-get update
            apt-get install -y apt-transport-https ca-certificates curl software-properties-common gnupg lsb-release \
                          htop iftop iotop pcp sysstat tcpdump strace ltrace lsof net-tools procps \
                          psmisc vim less grep gawk sed iputils-ping telnet netcat-openbsd dnsutils \
                          conntrack ethtool traceroute logrotate
        "
    done
    
    # Additional setup for jumpbox
    echo "Setting up jumpbox with additional tools..."
    multipass exec jumpbox -- sudo bash -c "
        apt-get update
        apt-get install -y git tmux jq
        
        # Create SSH keys for root
        mkdir -p /root/.ssh
        ssh-keygen -t rsa -N '' -f /root/.ssh/id_rsa
        cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys
        chmod 600 /root/.ssh/authorized_keys
    "
}

# Function to display VM info
show_vm_info() {
    echo -e "${GREEN}VM Information:${NC}"
    multipass list
    
    echo -e "\n${GREEN}IP Addresses:${NC}"
    for VM in "${VM_NAMES[@]}"; do
        IP=$(multipass info "$VM" | grep IPv4 | awk '{print $2}')
        echo "$VM: $IP"
    done
    
    echo -e "\n${GREEN}Access Instructions:${NC}"
    echo "To access jumpbox: multipass shell jumpbox"
    echo "For root access:   sudo -i"
    echo "Root password:     kuberoot"
}

# Main execution
echo -e "${GREEN}Setting up Kubernetes The Hard Way lab environment...${NC}"

create_vms
provision_vms
show_vm_info

echo -e "\n${GREEN}Setup complete! The Kubernetes The Hard Way lab environment is ready.${NC}"
echo -e "${YELLOW}Note: The VMs are configured with minimal resources. Adjust if needed.${NC}"