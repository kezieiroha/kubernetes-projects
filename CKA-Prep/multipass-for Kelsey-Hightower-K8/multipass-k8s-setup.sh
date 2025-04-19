#!/bin/bash
# Kezie Iroha
# Multipass setup script for Kelsey Hightower's "Kubernetes The Hard Way" lab

set -e  # Exit on error

# VM configurations - using simple arrays for better compatibility
VM_NAMES=("jumpbox" "server" "node-0" "node-1")
VM_SPECS=("cpus=1,memory=512M,disk=10G" "cpus=1,memory=2G,disk=20G" "cpus=1,memory=2G,disk=20G" "cpus=1,memory=2G,disk=20G")

# Check if multipass is installed
if ! command -v multipass &> /dev/null; then
    echo "Multipass is not installed. Please install it first."
    exit 1
fi

# Function to create VMs
create_vms() {
    echo "Creating VMs for Kubernetes The Hard Way..."
    
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
            echo "VM '$VM' already exists. Skipping creation."
            continue
        fi
        
        echo "Creating VM: $VM (CPUs: $cpus, Memory: $mem, Disk: $disk)"
        multipass launch --name "$VM" --cpus "$cpus" --memory "$mem" --disk "$disk"
    done
}

# Function to provision VMs
provision_vms() {
    echo "Provisioning VMs..."
    
    # Enable root access on all VMs
    for VM in "${VM_NAMES[@]}"; do
        echo "Setting up root access for $VM..."
        # Set root password
        multipass exec "$VM" -- sudo bash -c "echo 'root:kuberoot' | chpasswd"
        
        # Enable root SSH login with password - more thorough approach
        multipass exec "$VM" -- sudo bash -c "cat > /etc/ssh/sshd_config.d/50-cloud-init.conf << EOF
# Added by Kubernetes lab setup script
PermitRootLogin yes
PasswordAuthentication yes
PubkeyAuthentication yes
EOF"
        
        # Restart SSH service
        multipass exec "$VM" -- sudo systemctl restart ssh
        
        # Disable cloud-init's management of /etc/hosts
        echo "Disabling cloud-init's management of /etc/hosts on $VM..."
        multipass exec "$VM" -- sudo bash -c "sed -i 's/manage_etc_hosts: true/manage_etc_hosts: false/' /etc/cloud/cloud.cfg 2>/dev/null || echo 'manage_etc_hosts: false' >> /etc/cloud/cloud.cfg"
    done
    
    # Install common tools on all VMs
    for VM in "${VM_NAMES[@]}"; do
        echo "Installing tools on $VM..."
        multipass exec "$VM" -- sudo bash -c "
            apt-get update
            apt-get install -y apt-transport-https ca-certificates curl software-properties-common gnupg lsb-release \
                          htop iftop iotop pcp sysstat tcpdump strace ltrace lsof net-tools procps \
                          psmisc vim less grep gawk sed iputils-ping telnet netcat-openbsd dnsutils \
                          conntrack ethtool traceroute logrotate git tmux jq
        "
    done
    
    # Set up SSH keys on all VMs
    for VM in "${VM_NAMES[@]}"; do
        echo "Setting up SSH keys for $VM..."
        multipass exec "$VM" -- sudo bash -c "
            mkdir -p /root/.ssh
            ssh-keygen -t rsa -N '' -f /root/.ssh/id_rsa
            cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys
            chmod 600 /root/.ssh/authorized_keys
        "
    done
}

# Function to display VM info
show_vm_info() {
    echo "VM Information:"
    multipass list
    
    echo -e "\nIP Addresses:"
    for VM in "${VM_NAMES[@]}"; do
        IP=$(multipass info "$VM" | grep IPv4 | awk '{print $2}')
        echo "$VM: $IP"
    done
    
    echo -e "\nAccess Instructions:"
    echo "To access jumpbox: multipass shell jumpbox"
    echo "To SSH directly:   ssh root@VM_IP_ADDRESS"
    echo "Root password:     kuberoot"
}

# Main execution
echo "Setting up Kubernetes The Hard Way lab environment..."

create_vms
provision_vms
show_vm_info

echo -e "\nSetup complete! The Kubernetes The Hard Way lab environment is ready."
echo "Note: The VMs are configured with minimal resources. Adjust if needed."