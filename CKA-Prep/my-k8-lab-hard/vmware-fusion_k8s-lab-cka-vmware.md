# Kezie Iroha
# Kubernetes Hands-On Lab on macOS for CKA Preparation (VMware Fusion)

##  Key Engineering Goals
- **Real-world Kubernetes setup** (not `kind`, not minikube).
- **Multi-node cluster** (3 Control Planes, 2 Workers for HA Setup).
- **Uses `kubeadm`** (just like in production).
- **Container Runtime:** `containerd` (CKA-compliant).
- **Networking:** `Calico` (CNI for pod networking, Multi-NIC Support).
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
# Install VMware Fusion
# Ensure VMware Fusion is installed and licensed

# Install CLI tools
brew install kubectl helm kubectx stern jq yq
```

---

## 2️ Create High-Availability Kubernetes Cluster Using VMware Fusion

### Get the IP Address of Each VM
To retrieve the IP address of a VM in VMware Fusion, run:
```sh
vmrun -T fusion getGuestIPAddress "<VM_NAME>"
```
Example:
```sh
vmrun -T fusion getGuestIPAddress "k8s-master-1"
```


### Step 1: Download AlmaLinux ISO
- [AlmaLinux 9](https://mirrors.almalinux.org/isos.html)
- [AlmaLinux 8](https://mirrors.almalinux.org/isos.html)

### Step 2: Create Virtual Machines
#### Configure VM Settings:
- **Control Plane 1:** 2 vCPUs, 4GB RAM, 20GB Disk
- **Control Plane 2:** 2 vCPUs, 4GB RAM, 20GB Disk
- **Control Plane 3:** 2 vCPUs, 4GB RAM, 20GB Disk
- **Worker Node 1:** 2 vCPUs, 4GB RAM, 20GB Disk
- **Worker Node 2:** 2 vCPUs, 4GB RAM, 20GB Disk
- **Networking:** **Bridged Adapter** (to allow inter-node communication)
- **Install VMware Tools** inside each VM:
```sh
sudo yum install -y open-vm-tools
```

---

## 3️ Configure Control Plane Nodes

### Step 1: Install Container Runtime (`containerd`)
```sh
# Install containerd
sudo yum install -y epel-release
sudo yum install -y containerd

# Configure containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sudo systemctl restart containerd
```

### Step 2: Install Kubernetes Components
```sh
# Add Kubernetes repository
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.29/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.29/rpm/Release.key
EOF

# Install kubeadm, kubelet, kubectl
sudo yum install -y kubelet kubeadm kubectl
sudo systemctl enable --now kubelet
```

### Step 3: Initialize Kubernetes Master with High Availability
```sh
sudo kubeadm init --control-plane --pod-network-cidr=10.244.0.0/16
```

Join additional control planes:
```sh
sudo kubeadm join <master-ip>:6443 --token <token> --discovery-token-ca-cert-hash <hash> --control-plane
```

### Step 4: Configure `kubectl`
```sh
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
kubectl get nodes
```

### Step 5: Install Calico CNI
```sh
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
```

### Step 6: Install MetalLB Load Balancer
```sh
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/main/config/manifests/metallb-native.yaml
```

---

## 4️ Configure Worker Nodes

### Step 1: Get Join Command on Master
```sh
kubeadm token create --print-join-command
```

Copy the output, then **log in to the worker node**.

### Step 2: Install Kubernetes Components on Worker
```sh
sudo yum install -y kubelet kubeadm kubectl
sudo systemctl enable --now kubelet
```

### Step 3: Join Worker Nodes to the Cluster
```sh
sudo kubeadm join <master-ip>:6443 --token <token> --discovery-token-ca-cert-hash <hash>
```

Verify on the **master node**:
```sh
kubectl get nodes
```

---

## 5️ Install GitOps with ArgoCD
```sh
helm repo add argo https://argoproj.github.io/argo-helm
helm install argo-cd argo/argo-cd --namespace argocd --create-namespace
```

---

## 6️ Install Cluster Autoscaler
```sh
helm repo add autoscaler https://kubernetes.github.io/autoscaler
helm install cluster-autoscaler autoscaler/cluster-autoscaler
```

---

## 7️ Install Rook-Ceph for Dynamic Storage
```sh
helm repo add rook-release https://charts.rook.io/release
helm install rook-ceph rook-release/rook-ceph
```

---

## 8️ Install OPA/Gatekeeper for Policy Enforcement
```sh
helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts
helm install gatekeeper gatekeeper/gatekeeper
```

---

## 9️ Troubleshooting Enhancements
```sh
# Simulate control plane failure
sudo systemctl stop kube-apiserver

# Debug failing pod scheduling
kubectl describe pod <pod-name>
kubectl logs -f <pod-name>

# Check etcd status
kubectl exec -it etcd-master -- etcdctl endpoint health
```

