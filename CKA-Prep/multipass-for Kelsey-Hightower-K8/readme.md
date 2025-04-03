# Kezie Iroha
# Multipass Setup for Kelsey Hightower's "Kubernetes The Hard Way"

This repository contains a shell script to easily create the virtual machines required for following Kelsey Hightower's ["Kubernetes The Hard Way"](https://github.com/kelseyhightower/kubernetes-the-hard-way) tutorial using Ubuntu on macOS (including native Apple Silicon support).

> **Note:** This is an independent project and is not affiliated with or a fork of Kelsey Hightower's work. This Multipass configuration is designed to be used alongside his original tutorial at https://github.com/kelseyhightower/kubernetes-the-hard-way.

## Prerequisites

- [Multipass](https://multipass.run/) installed
  - On macOS: `brew install --cask multipass`
  - On Linux: `sudo snap install multipass`
  - On Windows: Download from [Multipass website](https://multipass.run/install)

## Hardware Requirements

Ensure your host machine has at least:
- 8GB RAM (16GB recommended)
- 4 CPU cores
- 60GB free disk space

## Quick Start

1. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/kubernetes-the-hard-way-multipass.git
   cd kubernetes-the-hard-way-multipass
   ```

2. Make the script executable:
   ```bash
   chmod +x multipass-k8s-setup.sh
   ```

3. Run the setup script:
   ```bash
   ./multipass-k8s-setup.sh
   ```

4. The setup creates four VMs:
   - `jumpbox`: Administration host (2 CPU, 1GB RAM)
   - `server`: Kubernetes control plane (2 CPU, 2GB RAM)
   - `node-0`: Kubernetes worker (2 CPU, 2GB RAM)
   - `node-1`: Kubernetes worker (2 CPU, 2GB RAM)

5. Access the jumpbox:
   ```bash
   multipass shell jumpbox
   ```

6. Switch to the root user (required for the tutorial):
   ```bash
   sudo -i
   ```

## VM Information

| Name     | IP Address       | Role               | Specs                   |
|----------|------------------|--------------------| ------------------------|
| jumpbox  | Auto-assigned    | Administration     | 2 CPU, 1GB RAM, 10GB    |
| server   | Auto-assigned    | Control Plane      | 2 CPU, 2GB RAM, 20GB    |
| node-0   | Auto-assigned    | Worker Node        | 2 CPU, 2GB RAM, 20GB    |
| node-1   | Auto-assigned    | Worker Node        | 2 CPU, 2GB RAM, 20GB    |

The IP addresses are dynamically assigned. You can view them with:
```bash
multipass list
```

## Setting Up the machines.txt File

Once your VMs are running, you'll need to create a `machines.txt` file as required by the tutorial:

1. First, determine the IP addresses of your VMs:
   ```bash
   multipass list
   ```

2. SSH into the jumpbox and create the `machines.txt` file:
   ```bash
   multipass shell jumpbox
   sudo -i
   cat > machines.txt << EOF
   SERVER_IP server.kubernetes.local server  
   NODE_0_IP node-0.kubernetes.local node-0 10.200.0.0/24
   NODE_1_IP node-1.kubernetes.local node-1 10.200.1.0/24
   EOF
   ```
   
   Replace `SERVER_IP`, `NODE_0_IP`, and `NODE_1_IP` with the actual IP addresses of your VMs as shown in the `multipass list` command.

## Following the Tutorial

Now you can follow Kelsey Hightower's [Kubernetes The Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way) tutorial starting from the "Compute Resources" section, using these Multipass VMs.

The root password for all VMs is set to `kuberoot` for simplicity.

## Cleaning Up

When you're done with the tutorial, you can destroy all VMs:

```bash
# Stop all VMs
multipass stop --all

# Delete all VMs
multipass delete --all

# Permanently remove deleted VMs
multipass purge
```

## Customization

You can modify the script to adjust resources if needed:

- Change the VM specs in the `VM_NAMES` and `VM_SPECS` arrays
- Modify the provisioning section to install additional tools
- Adjust network settings as required

## Troubleshooting

### Shell Access Issues

If you encounter issues with accessing a VM:

1. Verify the VM is running:
   ```bash
   multipass list
   ```

2. Try restarting the VM:
   ```bash
   multipass restart VM_NAME
   ```

3. Check VM information:
   ```bash
   multipass info VM_NAME
   ```

### Network Issues

If VMs cannot communicate with each other:

1. Verify the IP addresses:
   ```bash
   multipass list
   multipass info | grep -E "Name|IPv4"
   multipass list --format csv | awk -F',' '{print $1, $3}'
   ```

2. Test connectivity from within a VM:
   ```bash
   # direct access 
   ssh username@server_ip

   # multipass shell
   multipass shell <server name>
   ping SERVER_IP
   ```


