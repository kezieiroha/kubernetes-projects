# Kezie Iroha 
# Kubernetes CKA Lab Environment

This is my local Kubernetes environment built with Vagrant and VMware for Certified Kubernetes Administrator (CKA) exam preparation.

## Overview

This project provides a fully automated setup of a multi-node Kubernetes cluster using Vagrant and VMware Fusion. It creates one control plane (master) node and two worker nodes configured with Flannel CNI networking, providing a realistic environment for practicing Kubernetes administration tasks relevant to the CKA exam.

## Components & Technologies

- **Vagrant**: Infrastructure-as-code tool for creating and managing virtual machine environments
- **VMware Fusion**: Virtualization platform
- **AlmaLinux 9**: Enterprise-grade Linux distribution (RHEL compatible)
- **Kubernetes 1.32**: Container orchestration platform
- **Containerd**: Container runtime
- **Flannel**: Simple and reliable CNI (Container Network Interface) for pod networking
- **CoreDNS**: Kubernetes cluster DNS solution
- **Kube-proxy**: Kubernetes network proxy

## Prerequisites

- [Vagrant](https://www.vagrantup.com/downloads) installed
- [VMware Fusion](https://blogs.vmware.com/teamfusion/2024/05/fusion-pro-now-available-free-for-personal-use.html) installed
- [VMware Utility for Vagrant](https://www.vagrantup.com/docs/providers/vmware/installation) installed
- At least 12GB of free RAM (4GB per node)
- At least 20GB of free disk space

## Getting Started

### Starting the Cluster

Clone this repository and navigate to the project directory:

```bash
git clone <repository-url>
cd vagrant-k8-lab
```

Start the Kubernetes cluster with VMware provider:

```bash
vagrant up --provider=vmware_desktop
```

Check the status of the Vagrant VMs:

```bash
vagrant global-status
```

### Accessing the Cluster

SSH into the master node:

```bash
vagrant ssh k8s-master
```

The kubeconfig file is already set up for the `vagrant` user, so you can immediately start using `kubectl` commands.

### Destroying the Cluster

When you're done, you can destroy the cluster:

```bash
vagrant destroy -f
```

Clean up any stale Vagrant VM references:

```bash
vagrant global-status --prune
```

## Verifying Cluster Functionality

After SSHing to the master node, run the following commands to verify the cluster is working correctly:

### Check Node Status

```bash
kubectl get nodes
```

Expected output:
```
NAME          STATUS   ROLES           AGE     VERSION
k8s-master    Ready    control-plane   5m39s   v1.32.2
k8s-worker1   Ready    <none>          3m35s   v1.32.2
k8s-worker2   Ready    <none>          1m51s   v1.32.2
```

### Check All Pods

```bash
kubectl get pods --all-namespaces
```

All pods should be in the `Running` state after initial setup is complete.

### Check Flannel CNI

```bash
kubectl get pods -n kube-flannel
```

## Testing the Cluster

### Deploy a Test Application

Create an Nginx deployment:

```bash
kubectl create deployment nginx --image=nginx
kubectl scale deployment nginx --replicas=3
```

Expose it as a service:

```bash
kubectl expose deployment nginx --port=80 --type=NodePort
```

### Verify the Deployment

Check running pods:

```bash
kubectl get pods -o wide
```

Check the created service:

```bash
kubectl get services nginx
```

### Test DNS Resolution and Pod Connectivity

Create a test pod and verify connectivity:

```bash
kubectl run busybox --image=busybox -- sleep 3600
kubectl exec busybox -- wget -O- http://nginx
```

You should see the HTML content of the Nginx welcome page, confirming proper networking and DNS functionality.

## Architecture Compatibility

This setup automatically detects whether you're running on ARM64 (Apple Silicon) or AMD64/x86_64 architecture and installs the appropriate CNI plugins, making it compatible with both architectures.

## CKA Exam Preparation Resources

While practicing in this environment, focus on the following key areas covered in the CKA exam:

- Cluster architecture, installation, and configuration
- Workloads & Scheduling
- Services & Networking
- Storage
- Troubleshooting

## License

This project is licensed under the MIT License - see the LICENSE file for details.