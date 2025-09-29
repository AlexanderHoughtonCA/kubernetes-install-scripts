NODE_HOSTNAME="k8sworker1.acme.com"
NODE_IP_ADDRESS="K8S_WORKER1_IP_ADDRESS"

MASTER_NODE_HOSTNAME="k8smaster.acme.com"
MASTER_NODE_IP_ADDRESS="K8S_MASTER_IP_ADDRESS"

NETWORK_INTERFACE="ens33"
DNS_SERVER_1="8.8.8.8";
DNS_SERVER_2="8.8.4.4";

echo "Using node ip address: $NODE_IP_ADDRESS";

echo  "$(tput setaf 2) $(tput sgr0)"
echo  "$(tput setaf 2) $(tput sgr0)"
echo  "$(tput setaf 2)Setting hostname...$(tput sgr0)"

sudo rm /etc/hostname
sudo touch /etc/hostname
sudo echo "Setting hostname: $NODE_HOSTNAME"
sudo hostnamectl set-hostname "$NODE_HOSTNAME"


echo  "$(tput setaf 2) $(tput sgr0)"
echo  "$(tput setaf 2)Editing hosts...$(tput sgr0)"
sudo rm /etc/hosts
sudo touch /etc/hosts
sudo echo "127.0.0.1 localhost"

cat <<EOF | sudo tee /etc/hosts
127.0.0.1 localhost
::1 ip6-localhost ip6-loopback
fe00::0 ip6-localnet
fe00::0 ip6-mcastprefix
fe00::0 ip6-allnodes
fe00::0 ip6-allrouters
$NODE_IP_ADDRESS $NODE_HOSTNAME
$MASTER_NODE_IP_ADDRESS $MASTER_NODE_HOSTNAME
EOF

# Ensure hosts have unique product_uuid by running the below command.
# If two nodes have the same product_uuid, the Kubernetes cluster installation will fail.
sudo cat /sys/class/dmi/id/product_uuid


cat <<EOF | sudo tee /etc/netplan/00-installer-config.yaml
network:
  version: 2
  ethernets:
    $NETWORK_INTERFACE:
      addresses:
        - $NODE_IP_ADDRESS/24
      routes:
        - to: default
          via: 192.168.0.1
          on-link: true
      nameservers:
        addresses:
          - $DNS_SERVER_1
          - $DNS_SERVER_2
      dhcp4: false
      optional: false
EOF
sudo netplan apply


echo  "$(tput setaf 2) $(tput sgr0)"
echo  "$(tput setaf 2)Disabling swap...$(tput sgr0)"
sudo swapoff -a
sudo sed -i '/swap/d' /etc/fstab
sudo rm /swap.img

echo  "$(tput setaf 2) $(tput sgr0)"
echo  "$(tput setaf 2)Configuring /etc/modules-load.d/containerd.conf...$(tput sgr0)"

# Load the following kernel modules on all the nodes,
sudo touch /etc/modules-load.d/containerd.conf
sudo echo 'overlay' | sudo tee -a /etc/modules-load.d/containerd.conf
sudo echo 'br_netfilter' | sudo tee -a /etc/modules-load.d/containerd.conf

sudo modprobe overlay
sudo modprobe br_netfilter

echo  "$(tput setaf 2) $(tput sgr0)"
echo  "$(tput setaf 2)Configuring /etc/sysctl.d/kubernetes.conf...$(tput sgr0)"
sudo touch /etc/sysctl.d/kubernetes.conf
sudo echo 'net.bridge.bridge-nf-call-ip6tables = 1' | sudo tee -a /etc/sysctl.d/kubernetes.conf
sudo echo 'net.bridge.bridge-nf-call-iptables = 1' | sudo tee -a /etc/sysctl.d/kubernetes.conf
sudo echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.d/kubernetes.conf

sudo sysctl --system

echo  "$(tput setaf 2) $(tput sgr0)"
echo  "$(tput setaf 2)Installing containerd...$(tput sgr0)"

# Containerd Dependencies
sudo apt install -y curl gnupg2 software-properties-common apt-transport-https ca-certificates

# Repo key (modern path)
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Containerd Repo
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list

sudo apt -y update
sudo apt install -y containerd.io

# Containerd Config
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

# Enable containerd service
sudo systemctl restart containerd
sudo systemctl enable containerd


echo  "$(tput setaf 2) $(tput sgr0)"
echo  "$(tput setaf 2)Enabling ufw...$(tput sgr0)"
sudo ufw allow OpenSSH
sudo ufw --force enable

# Kubernetes control plane API server
sudo ufw allow 6443/tcp

# etcd (only if running stacked control plane)
sudo ufw allow 2379:2380/tcp

# Kubelet API
sudo ufw allow 10250/tcp

# kube-scheduler
sudo ufw allow 10259/tcp

# kube-controller-manager
sudo ufw allow 10257/tcp

# Flannel
sudo ufw allow 8472/udp

# Ingress controller / general web traffic
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# (Optional) NodePort Services
sudo ufw allow 30000:32767/tcp


echo  "$(tput setaf 2) $(tput sgr0)"
echo  "$(tput setaf 2)Getting Kubernetes GPG...$(tput sgr0)"
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
sudo apt -y update

echo  "$(tput setaf 2) $(tput sgr0)"
echo  "$(tput setaf 2)Installing kubelet kubeadm kubectl...$(tput sgr0)"
sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
sudo systemctl enable kubelet && systemctl start kubelet

# Used for checking node taints
sudo apt install -y jq


echo  "$(tput setaf 2) $(tput sgr0)"
echo  "$(tput setaf 2)Installing MySQL client...$(tput sgr0)"
sudo apt install -y mysql-client-core-8.0

sudo apt -y install socat

mkdir -p $HOME/.kube
