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
cd my-k8-lab-easy
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

## Post-Installation Verification

After setting up your Kubernetes cluster with Vagrant, you should verify that all components are working correctly. Follow these steps to confirm your cluster is healthy and properly configured.

### 1. Verify Node Status

First, check that all nodes are in the `Ready` state:

```bash
vagrant ssh k8s-master
kubectl get nodes
```

Expected output (the ages will differ):
```
NAME          STATUS   ROLES           AGE     VERSION
k8s-master    Ready    control-plane   10m     v1.28.15
k8s-worker1   Ready    <none>          8m      v1.28.15
k8s-worker2   Ready    <none>          6m      v1.28.15
```

Verify detailed node information including IP addresses:
```bash
kubectl get nodes -o wide
```

Expected output:
```
NAME          STATUS   ROLES           AGE    VERSION    INTERNAL-IP     EXTERNAL-IP   OS-IMAGE                      KERNEL-VERSION                  CONTAINER-RUNTIME
k8s-master    Ready    control-plane   10m    v1.28.15   192.168.56.10   <none>        AlmaLinux 9.5 (Teal Serval)   5.14.0-503.15.1.el9_5.aarch64   containerd://1.7.25
k8s-worker1   Ready    <none>          8m     v1.28.15   192.168.56.11   <none>        AlmaLinux 9.5 (Teal Serval)   5.14.0-503.15.1.el9_5.aarch64   containerd://1.7.25
k8s-worker2   Ready    <none>          6m     v1.28.15   192.168.56.12   <none>        AlmaLinux 9.5 (Teal Serval)   5.14.0-503.15.1.el9_5.aarch64   containerd://1.7.25
```

### 2. Verify Control Plane Components

Check that all control plane components are running:

```bash
kubectl get pods -n kube-system | grep -E 'etcd|apiserver|controller|scheduler'
```

Expected output:
```
etcd-k8s-master                      1/1     Running   0          10m
kube-apiserver-k8s-master            1/1     Running   0          10m
kube-controller-manager-k8s-master   1/1     Running   0          10m
kube-scheduler-k8s-master            1/1     Running   0          10m
```

### 3. Verify Network Components

Check that the Flannel CNI is properly deployed:

```bash
kubectl get pods -n kube-flannel
```

Expected output:
```
NAME                    READY   STATUS    RESTARTS        AGE
kube-flannel-ds-fv2j4   1/1     Running   0               10m
kube-flannel-ds-hc29r   1/1     Running   1 (8m ago)      8m
kube-flannel-ds-mprlz   1/1     Running   0               6m
```

### 4. Verify etcd Health

Check the health of the etcd cluster:

```bash
# Use the convenient alias set up in the lab environment
etcd-status
```

Expected output:
```
==== ETCD Health Status ====
https://127.0.0.1:2379 is healthy: successfully committed proposal: took = 4.69289ms

==== ETCD Endpoints ====
+------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
|        ENDPOINT        |        ID        | VERSION | DB SIZE | IS LEADER | IS LEARNER | RAFT TERM | RAFT INDEX | RAFT APPLIED INDEX | ERRORS |
+------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
| https://127.0.0.1:2379 | f0e4577804b51494 |  3.5.15 |  1.7 MB |      true |      false |         2 |       1097 |               1097 |        |
+------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+

==== ETCD Members ====
+------------------+---------+------------+----------------------------+----------------------------+------------+
|        ID        | STATUS  |    NAME    |         PEER ADDRS         |        CLIENT ADDRS        | IS LEARNER |
+------------------+---------+------------+----------------------------+----------------------------+------------+
| f0e4577804b51494 | started | k8s-master | https://192.168.56.10:2380 | https://192.168.56.10:2379 |      false |
+------------------+---------+------------+----------------------------+----------------------------+------------+
```

### 5. Verify Container Runtime (containerd)

Check that containerd is running correctly on all nodes:

```bash
# Check containerd service status on master
vagrant ssh k8s-master -c "sudo systemctl status containerd | grep Active"

# Check containerd service status on worker1
vagrant ssh k8s-worker1 -c "sudo systemctl status containerd | grep Active"

# Check containerd service status on worker2
vagrant ssh k8s-worker2 -c "sudo systemctl status containerd | grep Active"
```

Expected output for each command:
```
   Active: active (running) since [date and time]; [time] ago
```

You can also verify that containerd is functioning correctly by checking the container runtime version reported by kubectl:

```bash
kubectl get nodes -o wide
```

Look for the `CONTAINER-RUNTIME` column which should show `containerd://1.7.25` or similar.

To get more detailed information about the container runtime, run:

```bash
vagrant ssh k8s-master -c "sudo crictl info"
```

This should display detailed information about the container runtime configuration and status in JSON format.

Check that containerd can pull and run images:

```bash
vagrant ssh k8s-master -c "sudo crictl pull nginx:latest"
```

### 6. Verify CoreDNS

Check that CoreDNS is running:

```bash
kubectl get pods -n kube-system | grep coredns
```

Expected output:
```
coredns-5dd5756b68-abcde   1/1     Running   0          10m
coredns-5dd5756b68-fghij   1/1     Running   0          10m
```

### 6. Test Cluster Functionality

Deploy a simple test application to verify the cluster's functionality:

```bash
# Create a test deployment
kubectl create deployment nginx --image=nginx

# Scale the deployment to create multiple pods
kubectl scale deployment nginx --replicas=3

# Expose the deployment as a service
kubectl expose deployment nginx --port=80 --type=NodePort

# Verify pods are running
kubectl get pods -o wide

# Find the assigned NodePort
kubectl get services nginx
```

Test connectivity to the service:
```bash
# Get the NodePort assigned
NODE_PORT=$(kubectl get svc nginx -o jsonpath='{.spec.ports[0].nodePort}')

# Test accessing the service through any worker node
curl http://192.168.56.11:$NODE_PORT
curl http://192.168.56.12:$NODE_PORT
```

### 7. Verify Cross-Node Communication

Create a test pod to verify DNS resolution and pod connectivity:

```bash
# Create a busybox pod
kubectl run busybox --image=busybox -- sleep 3600

# Wait for the pod to be ready
kubectl wait --for=condition=Ready pod/busybox

# Test DNS resolution and pod connectivity
kubectl exec busybox -- wget -O- http://nginx
```

You should see the HTML content of the Nginx welcome page, confirming proper networking and DNS functionality.

### 8. Check Resource Utilization

Verify resource utilization on each node:

```bash
# On master node
kubectl top nodes

# For more detailed system information, SSH into each node and run:
vagrant ssh k8s-master -c "top -bn1 | head -15"
vagrant ssh k8s-worker1 -c "top -bn1 | head -15"
vagrant ssh k8s-worker2 -c "top -bn1 | head -15"
```

### 9. Verify kubectl Access from Worker Nodes

Test that kubectl is properly configured on worker nodes:

```bash
vagrant ssh k8s-worker1
kubectl get nodes
exit

vagrant ssh k8s-worker2
kubectl get nodes
exit
```

### 10. Check Logs for Any Issues

Review logs for any warnings or errors:

```bash
# On master node
kubectl logs -n kube-system kube-apiserver-k8s-master | grep -i error
kubectl logs -n kube-system kube-controller-manager-k8s-master | grep -i error
kubectl logs -n kube-system kube-scheduler-k8s-master | grep -i error
kubectl logs -n kube-system etcd-k8s-master | grep -i error

# Check flannel logs
kubectl logs -n kube-flannel $(kubectl get pods -n kube-flannel -o name | head -1) | grep -i error
```

## Architecture Compatibility

This setup automatically detects whether you're running on ARM64 (Apple Silicon) or AMD64/x86_64 architecture and installs the appropriate CNI plugins, making it compatible with both architectures.

## License

This project is licensed under the MIT License - see the LICENSE file for details.