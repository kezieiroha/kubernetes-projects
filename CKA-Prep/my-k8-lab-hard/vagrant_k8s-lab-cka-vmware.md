# Kezie Iroha
# Kubernetes Hands-On Lab on macOS for CKA Preparation (Vagrant with VMware Fusion)

## Key Engineering Goals
- **Real-world Kubernetes setup** (not `kind`, not minikube).
- **Multi-node cluster** (1 Control Plane, 2 Workers for practical setup).
- **Uses `kubeadm`** (just like in production).
- **Container Runtime:** `containerd` (CKA-compliant).
- **Networking:** `Flannel` (Simple and reliable CNI for pod networking).
- **Ingress Controller:** `NGINX` + **MetalLB Load Balancer**.
- **Monitoring & Logging:** `Prometheus`, `Metrics Server`, `Fluentd`.
- **Storage:** **Dynamic Provisioning via Rook-Ceph**.
- **GitOps Deployment:** **ArgoCD for CI/CD automation**.
- **Security:** **RBAC, Network Policies, Pod Security Admission (PSA), OPA/Gatekeeper**.
- **Cluster Autoscaling:** **Cluster Autoscaler for Node Auto-Scaling**.
- **Troubleshooting focus** (systemd logs, etcd health, pod debugging).

---

## 1️ Install Prerequisites on macOS
```sh
# Install Vagrant & VMware Fusion
brew install vagrant
brew install --cask vmware-fusion

# Install the Vagrant VMware provider plugin
vagrant plugin install vagrant-vmware-desktop

# Install CLI tools
brew install kubectl helm kubectx stern jq yq
```

---

## 2️ Create Kubernetes Cluster Using Vagrant

### Step 1: Create a `Vagrantfile`
```ruby
# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box_check_update = false

  # Master node configuration
  config.vm.define "k8s-master" do |master|
    master.vm.box = "almalinux/9"
    master.vm.hostname = "k8s-master"
    master.vm.network "private_network", type: "dhcp"
    master.vm.provider "vmware_desktop" do |v|
      v.memory = 4096
      v.cpus = 2
    end

    master.vm.provision "shell", inline: <<-SHELL
      echo "Disabling swap..."
      swapoff -a
      sed -i '/swap/d' /etc/fstab

      echo "Enabling IP forwarding..."
      echo "net.ipv4.ip_forward = 1" > /etc/sysctl.d/99-k8s.conf
      sysctl --system

      echo "Installing dependencies..."
      dnf install -y epel-release yum-utils wget
      dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
      dnf install -y containerd.io

      echo "Configuring containerd..."
      mkdir -p /etc/containerd
      containerd config default > /etc/containerd/config.toml
      sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
      sed -i 's|registry.k8s.io/pause:3.8|registry.k8s.io/pause:3.10|g' /etc/containerd/config.toml
      systemctl restart containerd
      systemctl enable containerd --now

      echo "Loading required kernel modules..."
      cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
      modprobe overlay
      modprobe br_netfilter

      echo "Applying sysctl settings for Kubernetes..."
      cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
      sysctl --system

      echo "Adding Kubernetes repository..."
      cat <<EOF | tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.32/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.32/rpm/repodata/repomd.xml.key
EOF

      echo "Installing Kubernetes components..."
      dnf install -y kubeadm kubelet kubectl
      systemctl enable --now kubelet

      # Detect architecture and use appropriate CNI plugins
      ARCH=$(uname -m)
      echo "Detected architecture: $ARCH"

      echo "Installing CNI plugins for $ARCH architecture..."
      mkdir -p /opt/cni/bin
      
      if [ "$ARCH" == "aarch64" ] || [ "$ARCH" == "arm64" ]; then
        # ARM64 architecture
        wget https://github.com/containernetworking/plugins/releases/download/v1.3.0/cni-plugins-linux-arm64-v1.3.0.tgz -O cni-plugins.tgz
      else
        # Default to AMD64
        wget https://github.com/containernetworking/plugins/releases/download/v1.3.0/cni-plugins-linux-amd64-v1.3.0.tgz -O cni-plugins.tgz
      fi
      
      tar -C /opt/cni/bin -xzf cni-plugins.tgz
      rm -f cni-plugins.tgz

      echo "Pulling Kubernetes images..."
      kubeadm config images pull

      echo "Initializing Kubernetes cluster..."
      # Use pod CIDR 10.244.0.0/16 which is the default for Flannel
      kubeadm init --apiserver-advertise-address=$(hostname -I | awk '{print $2}') --pod-network-cidr=10.244.0.0/16

      echo "Setting up kubeconfig for vagrant user..."
      mkdir -p /home/vagrant/.kube
      cp -i /etc/kubernetes/admin.conf /home/vagrant/.kube/config
      chown -R vagrant:vagrant /home/vagrant/.kube

      echo "Deploying Flannel CNI..."
      kubectl --kubeconfig=/etc/kubernetes/admin.conf apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml

      echo "Generating join command for worker nodes..."
      kubeadm token create --print-join-command > /vagrant/k8s-join-command.sh
      chmod +x /vagrant/k8s-join-command.sh
    SHELL
  end

  # Worker nodes configuration
  ["k8s-worker1", "k8s-worker2"].each do |worker_name|
    config.vm.define worker_name do |worker|
      worker.vm.box = "almalinux/9"
      worker.vm.hostname = worker_name
      worker.vm.network "private_network", type: "dhcp"
      worker.vm.provider "vmware_desktop" do |v|
        v.memory = 4096
        v.cpus = 2
      end

      worker.vm.provision "shell", inline: <<-SHELL
        timeout=300
        elapsed=0
        while [ ! -f /vagrant/k8s-join-command.sh ]; do
          echo "Waiting for join command file..."
          sleep 10
          elapsed=$((elapsed + 10))
          if [ $elapsed -ge $timeout ]; then
            echo "ERROR: Timeout waiting for join command. Exiting."
            exit 1
          fi
        done
        echo "Join command found, proceeding with setup..."

        echo "Setting up repositories..."
        dnf install -y epel-release yum-utils wget
        dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        
        echo "Adding Kubernetes repository..."
        cat <<EOF | tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.32/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.32/rpm/repodata/repomd.xml.key
EOF
        
        echo "Installing containerd..."
        dnf install -y containerd.io
        
        echo "Configuring containerd..."
        mkdir -p /etc/containerd
        containerd config default > /etc/containerd/config.toml
        sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
        sed -i 's|registry.k8s.io/pause:3.8|registry.k8s.io/pause:3.10|g' /etc/containerd/config.toml
        systemctl restart containerd
        systemctl enable --now containerd

        echo "Loading kernel modules..."
        cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
        modprobe overlay
        modprobe br_netfilter

        echo "Enabling IP forwarding..."
        echo "net.ipv4.ip_forward = 1" > /etc/sysctl.d/99-k8s.conf
        cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
        sysctl --system

        echo "Disabling swap..."
        swapoff -a
        sed -i '/swap/d' /etc/fstab

        # Detect architecture and use appropriate CNI plugins
        ARCH=$(uname -m)
        echo "Detected architecture: $ARCH"

        echo "Installing CNI plugins for $ARCH architecture..."
        mkdir -p /opt/cni/bin
        
        if [ "$ARCH" == "aarch64" ] || [ "$ARCH" == "arm64" ]; then
          # ARM64 architecture
          wget https://github.com/containernetworking/plugins/releases/download/v1.3.0/cni-plugins-linux-arm64-v1.3.0.tgz -O cni-plugins.tgz
        else
          # Default to AMD64
          wget https://github.com/containernetworking/plugins/releases/download/v1.3.0/cni-plugins-linux-amd64-v1.3.0.tgz -O cni-plugins.tgz
        fi
        
        tar -C /opt/cni/bin -xzf cni-plugins.tgz
        rm -f cni-plugins.tgz

        echo "Installing Kubernetes components..."
        dnf install -y kubeadm kubelet kubectl
        systemctl enable --now kubelet

        echo "Joining Kubernetes cluster..."
        bash /vagrant/k8s-join-command.sh
      SHELL
    end
  end
end
```

### Step 2: Deploy the VMs
```sh
vagrant up --provider=vmware_desktop
```

### Step 3: Verify Cluster Status
To check node status:
```sh
vagrant ssh k8s-master
kubectl get nodes
```

### Step 4: Check the Flannel Deployment
```sh
kubectl get pods -n kube-flannel
```

---

## 3️ Verify Network Connectivity

### Test Pod-to-Pod Communication
```sh
# Create a test deployment
kubectl create deployment nginx --image=nginx
kubectl scale deployment nginx --replicas=3

# Expose it as a service
kubectl expose deployment nginx --port=80 --type=NodePort

# Create a test pod for validation
kubectl run busybox --image=busybox -- sleep 3600

# Test connectivity
kubectl exec busybox -- wget -O- http://nginx
```

---

## 4️ Install Additional Components

### Step 1: Install NGINX Ingress Controller
```sh
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml
```

### Step 2: Install MetalLB Load Balancer
```sh
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.12/config/manifests/metallb-native.yaml
```

Configure MetalLB with the IP range from your private network:
```sh
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: first-pool
  namespace: metallb-system
spec:
  addresses:
  - 192.168.171.200-192.168.171.250
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

### Step 3: Install Metrics Server
```sh
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

### Step 4: Install Prometheus for Monitoring
```sh
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack --namespace monitoring --create-namespace
```

---

## 5️ Install GitOps with ArgoCD
```sh
helm repo add argo https://argoproj.github.io/argo-helm
helm install argo-cd argo/argo-cd --namespace argocd --create-namespace
```

---

## 6️ Install Storage with Rook-Ceph
```sh
kubectl create -f https://raw.githubusercontent.com/rook/rook/master/deploy/examples/crds.yaml
kubectl create -f https://raw.githubusercontent.com/rook/rook/master/deploy/examples/common.yaml
kubectl create -f https://raw.githubusercontent.com/rook/rook/master/deploy/examples/operator.yaml

# Create a Rook-Ceph cluster
kubectl create -f https://raw.githubusercontent.com/rook/rook/master/deploy/examples/cluster.yaml
```

---

## 7️ Install OPA/Gatekeeper for Policy Enforcement
```sh
kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/master/deploy/gatekeeper.yaml
```

---

## 8️ Troubleshooting Guide

### Check Node Status
```sh
kubectl get nodes
kubectl describe node <node-name>
```

### Check Pod Status
```sh
kubectl get pods --all-namespaces
kubectl describe pod <pod-name> -n <namespace>
```

### Check Logs
```sh
kubectl logs <pod-name> -n <namespace>
```

### Debug Networking Issues
```sh
# Test DNS resolution
kubectl run busybox --image=busybox -- sleep 3600
kubectl exec busybox -- nslookup kubernetes.default

# Check service connectivity
kubectl exec busybox -- wget -O- http://nginx
```

### Check System Logs
```sh
sudo journalctl -u kubelet
sudo journalctl -u containerd
```

### Check etcd Health
```sh
kubectl -n kube-system exec -it etcd-k8s-master -- etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  endpoint health
```

---

## 9️ CKA Practice Exercises

### RBAC Configuration
```sh
# Create a role for pod management
kubectl create role pod-manager --verb=get,list,watch,create,delete --resource=pods

# Create a role binding
kubectl create rolebinding dev-pod-manager --role=pod-manager --user=developer
```

### Network Policies
```sh
# Create a policy to deny all ingress traffic
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-ingress
spec:
  podSelector: {}
  policyTypes:
  - Ingress
EOF
```

### Pod Security Admission
```sh
# Enable Pod Security Standards
kubectl label namespace default pod-security.kubernetes.io/enforce=baseline
```

