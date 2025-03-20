# Kezie Iroha
# Kubernetes Hands-On Lab on macOS for CKA Preparation

## Key Engineering Goals
- **Real-world Kubernetes setup** (not `kind`, not minikube).
- **Multi-node cluster** (1 Master, 1 Worker).
- **Uses `kubeadm`** (just like in production).
- **Container Runtime:** `containerd` (CKA-compliant).
- **Networking:** `Calico` (CNI for pod networking).
- **Ingress Controller:** `NGINX`.
- **Monitoring & Logging:** `Prometheus`, `Metrics Server`, `Fluentd`.
- **Security:** **RBAC, Network Policies, Pod Security Contexts**.
- **Storage:** **Persistent Volumes (PVs), Persistent Volume Claims (PVCs)**.
- **Troubleshooting focus** (systemd logs, etcd health, pod debugging).

---

## 1 Install Prerequisites on macOS
```sh
# Install Rancher Desktop
brew install --cask rancher

# Install Multipass for VM-based Kubernetes nodes
brew install multipass

# Install CLI tools
brew install kubectl helm kubectx stern jq yq
```

---

## 2️ Create Kubernetes Nodes Using Multipass
We'll use Multipass to create two VMs:  
✅ `k8s-master` (Control Plane)  
✅ `k8s-worker1` (Worker Node)

```sh
# Create master node
multipass launch --name k8s-master --cpus 2 --memory 4G --disk 20G 22.04

# Create worker node
multipass launch --name k8s-worker1 --cpus 2 --memory 4G --disk 20G 22.04
```

Verify the VMs:
```sh
multipass list
```

---

## 3️ Configure Master Node
### Step 1: Access the Master Node
```sh
multipass shell k8s-master
```

### Step 2: Install Container Runtime (`containerd`)
```sh
# Install containerd
sudo apt update
sudo apt install -y containerd.io

# Configure containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sudo systemctl restart containerd
```

### Step 3: Install Kubernetes Components
```sh
# Install kubeadm, kubelet, kubectl
sudo apt install -y apt-transport-https ca-certificates curl
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | sudo tee /etc/apt/keyrings/kubernetes-archive-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-archive-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt update
sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
```

### Step 4: Initialize Kubernetes Master
```sh
sudo kubeadm init --pod-network-cidr=10.244.0.0/16
```

**After initialization, set up `kubectl` access:**
```sh
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

Verify:
```sh
kubectl get nodes
```

 **Step 5: Install Calico CNI**
```sh
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
```

---

## 4️ Configure Worker Node
### Step 1: Get Join Command on Master
```sh
kubeadm token create --print-join-command
```

Copy the output, then **log in to the worker node**:
```sh
multipass shell k8s-worker1
```

### Step 2: Install Kubernetes Components
```sh
sudo apt update
sudo apt install -y containerd.io
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sudo systemctl restart containerd

# Install kubeadm, kubelet, kubectl
sudo apt install -y apt-transport-https ca-certificates curl
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | sudo tee /etc/apt/keyrings/kubernetes-archive-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-archive-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt update
sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
```

### Step 3: Join Worker Node to the Cluster
Paste the join command from the master:
```sh
sudo kubeadm join <master-ip>:6443 --token <token> --discovery-token-ca-cert-hash <hash>
```

Verify on the **master node**:
```sh
kubectl get nodes
```

---

## 5️ Install Core Kubernetes Tools
### Install Metrics Server
```sh
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

Verify:
```sh
kubectl get deployment metrics-server -n kube-system
```

### Install Prometheus & Fluentd (Monitoring & Logging)
```sh
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack

helm repo add fluent https://fluent.github.io/helm-charts
helm install fluentd fluent/fluentd
```

---

## 6️ Install Ingress Controller
```sh
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install ingress-nginx ingress-nginx/ingress-nginx
```

---

## 7️ Storage (PVs & PVCs)
```sh
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-example
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF
```

---

## 8️ Security (RBAC & Network Policies)
```sh
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: default
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "watch", "list"]
EOF
```

```sh
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
  namespace: default
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
EOF
```

---

## 9️ Troubleshooting (Critical for CKA)
```sh
# Check logs of failing pods
kubectl describe pod <pod-name>
kubectl logs -f <pod-name>

# Debug a pod
kubectl exec -it <pod-name> -- /bin/sh

# Check systemd logs (etcd, kubelet)
journalctl -u kubelet -f
```
