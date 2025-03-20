# Kezie Iroha
# Kubernetes Setup the Hard Way (Manual Configuration Steps)

## Phase 1: Create Virtual Machines

Start by creating three VMs using Vagrant, but without any provisioning:

```ruby
# Basic Vagrantfile without provisioning
Vagrant.configure("2") do |config|
  nodes = {
    "k8s-master" => { cpus: 2, memory: 4096 },
    "k8s-worker1" => { cpus: 2, memory: 4096 },
    "k8s-worker2" => { cpus: 2, memory: 4096 }
  }

  nodes.each do |hostname, options|
    config.vm.define hostname do |node|
      node.vm.box = "almalinux/9"
      node.vm.hostname = hostname
      node.vm.network "private_network", type: "dhcp"

      node.vm.provider "vmware_desktop" do |v|
        v.vmx["memsize"] = options[:memory]
        v.vmx["numvcpus"] = options[:cpus]
      end
    end
  end
end
```

Run this to start the VMs:
```bash
vagrant up --provider=vmware_desktop
```

## Phase 2: Configure All Nodes (Master and Workers)

Perform these steps on **all nodes** (master and workers):

### Step 1: Disable Swap
```bash
# SSH into each VM
vagrant ssh k8s-master  # Repeat for each node

# Disable swap
sudo swapoff -a
sudo sed -i '/swap/d' /etc/fstab
```

### Step 2: Set Up System Requirements
```bash
# Enable IP forwarding
echo "net.ipv4.ip_forward = 1" | sudo tee /etc/sysctl.d/99-k8s.conf
sudo sysctl --system

# Enable required kernel modules
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter

# Configure system settings for Kubernetes
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system
```

### Step 3: Install Dependencies
```bash
# Install basic utilities
sudo dnf install -y epel-release yum-utils wget

# Add Docker repository
sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

# Add Kubernetes repository
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.32/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.32/rpm/repodata/repomd.xml.key
EOF
```

### Step 4: Install Container Runtime
```bash
# Install containerd
sudo dnf install -y containerd.io

# Configure containerd
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo sed -i 's|registry.k8s.io/pause:3.8|registry.k8s.io/pause:3.10|g' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd
```

### Step 5: Install Kubernetes Components
```bash
# Install kubeadm, kubelet, and kubectl
sudo dnf install -y kubeadm kubelet kubectl
sudo systemctl enable --now kubelet
```

### Step 6: Install CNI Plugins
```bash
# Detect architecture
ARCH=$(uname -m)
echo "Detected architecture: $ARCH"

# Create CNI directory
sudo mkdir -p /opt/cni/bin

# Download and install appropriate CNI plugins
if [ "$ARCH" == "aarch64" ] || [ "$ARCH" == "arm64" ]; then
  # ARM64 architecture
  sudo wget https://github.com/containernetworking/plugins/releases/download/v1.3.0/cni-plugins-linux-arm64-v1.3.0.tgz -O cni-plugins.tgz
else
  # Default to AMD64
  sudo wget https://github.com/containernetworking/plugins/releases/download/v1.3.0/cni-plugins-linux-amd64-v1.3.0.tgz -O cni-plugins.tgz
fi

sudo tar -C /opt/cni/bin -xzf cni-plugins.tgz
sudo rm -f cni-plugins.tgz
```

## Phase 3: Initialize the Master Node

Perform these steps only on the **master node**:

### Step 1: Pull Required Images
```bash
sudo kubeadm config images pull
```

### Step 2: Initialize the Control Plane
```bash
# Get the IP address to use for the API server
MASTER_IP=$(ip -4 addr show eth1 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')

# Initialize the cluster
sudo kubeadm init --apiserver-advertise-address=$MASTER_IP --pod-network-cidr=10.244.0.0/16

# Note: Save the 'kubeadm join' command output for worker nodes!
```

### Step 3: Set Up kubeconfig
```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Verify the cluster is running
kubectl get nodes
```

### Step 4: Install Flannel CNI
```bash
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml

# Verify Flannel pods are running
kubectl get pods -n kube-flannel
```

### Step 5: Generate Join Command for Worker Nodes
```bash
# Create a token that doesn't expire immediately
kubeadm token create --print-join-command
```

## Phase 4: Join Worker Nodes to the Cluster

Perform these steps on each **worker node**:

### Step 1: Join the Cluster
```bash
# Run the 'kubeadm join' command you saved from the master initialization
sudo kubeadm join <master-ip>:6443 --token <token> --discovery-token-ca-cert-hash <hash>
```

### Step 2: Verify Nodes on Master
Back on the master node, check if all nodes have joined:
```bash
kubectl get nodes
```

## Phase 5: Verify Cluster Functionality

Perform these steps on the **master node**:

### Step 1: Verify System Components
```bash
kubectl get pods -n kube-system
kubectl get pods -n kube-flannel
```

### Step 2: Test with a Deployment
```bash
# Create an nginx deployment
kubectl create deployment nginx --image=nginx
kubectl scale deployment nginx --replicas=3

# Expose the deployment
kubectl expose deployment nginx --port=80 --type=NodePort

# Check pods and service
kubectl get pods -o wide
kubectl get svc nginx
```

### Step 3: Test Network Connectivity
```bash
# Create a test pod
kubectl run busybox --image=busybox -- sleep 3600

# Wait for it to be ready
kubectl wait --for=condition=Ready pod/busybox

# Test connectivity to nginx
kubectl exec busybox -- wget -O- http://nginx
```

## Phase 6: Advanced Components (Optional)

### Step 1: Install Metrics Server
```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

### Step 2: Install NGINX Ingress Controller
```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml
```

### Step 3: Install MetalLB
```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.12/config/manifests/metallb-native.yaml

# Configure IP address pool (adjust the range to match your network)
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: first-pool
  namespace: metallb-system
spec:
  addresses:
  - 192.168.171.197-192.168.171.199
EOF

cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: l2-advert
  namespace: metallb-system
spec:
  ipAddressPools:
  - first-pool
EOF
```
