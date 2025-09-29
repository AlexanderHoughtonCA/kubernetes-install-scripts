# Kubernetes Bare-Metal Install Scripts (Ubuntu 22.04, Non-Root, MetalLB)

This repository contains scripts and manifests to install a **bare-metal Kubernetes cluster** on Ubuntu 22.04.  
It is designed for static IP clusters where **MetalLB provides load balancing** and **ingress-nginx handles external traffic**.  
All scripts are built to run as a non-root user.

**This process requires a minimum of two computers/servers/virtual machines, with one master and one or more workers, each with a static IP address**

**Update values for NODE_HOSTNAME, NODE_IP_ADDRESS, DNS_SERVER_1, etc., prior to running the scripts!**

**Please note:** The Worker node install script may ask you to enter the sudo password more than once

## Contents

- **install-k8smaster-u22_AS_NON_ROOT.sh**  
  Prepares the Kubernetes **control plane (master node)**:  
  - Hostname and `/etc/hosts` setup  
  - Static IP via Netplan  
  - Disables swap  
  - Installs and configures containerd  
  - Enables required kernel modules and sysctl settings  
  - Firewall (ufw) rules for Kubernetes ports  
  - Installs kubelet, kubeadm, and kubectl (v1.28)  
  - Initializes the cluster with `kubeadm init`  
  - Applies Flannel CNI  
  - Prepares for MetalLB by enabling `strictARP`

- **install-k8sworker1-u22_AS_NON_ROOT.sh**  
  Prepares a **worker node**:  
  - Hostname and `/etc/hosts` setup (with master reference)  
  - Static IP via Netplan  
  - Disables swap  
  - Installs and configures containerd  
  - Firewall (ufw) rules for Kubernetes ports  
  - Installs kubelet, kubeadm, kubectl  
  - Enables kubelet  
  - Ready to join the cluster with `kubeadm join`

- **deploy-ingress-nginx-controller.yaml**  
  Deployment manifest for **ingress-nginx**, configured for use with MetalLB.

- **pool-config.yaml**  
  **MetalLB address pool configuration.** Defines the external IP range allocated to `LoadBalancer` services.

- **install-metallb.sh**  
  Installs **MetalLB** and deploys **ingress-nginx**:  
  - Creates the `ingress-nginx` namespace  
  - Applies the official MetalLB manifest  
  - Deploys ingress-nginx controller  
  - Removes validating webhook (avoids stuck jobs)  
  - Applies the MetalLB pool config

- **uninstall-metallb.sh**  
  Cleanly removes **MetalLB** and **ingress-nginx** from the cluster.

## Usage

1. **Master Node Setup**  
   ```bash
   chmod a+x ./install-k8smaster-u22_AS_NON_ROOT.sh
   ./install-k8smaster-u22_AS_NON_ROOT.sh
   reboot
   ```

2. **Worker Node Setup**  
   ```bash
   chmod a+x ./install-k8sworker1-u22_AS_NON_ROOT.sh
   ./install-k8sworker1-u22_AS_NON_ROOT.sh
   reboot
   ```

3. **On the Master Node - Set Static IP Address Pool in ./metallb/pool-config.yaml**  
e.g.
    ```yaml
    spec:
     addresses:
       - 192.168.0.20-192.168.0.40
    ```


4. **On the Master Node - Install MetalLB & Ingress (bare-metal load balancer)**  
   ```bash
   ./metallb/install-metallb.sh
   reboot
   ```

5. **On the Master Node - Get the Join Command**
   ```bash
   kubeadm token create --print-join-command
   ```
   Then copy the whole output, which should look something like this:  
   ```bash
   # EXAMPLE ONLY:
   kubeadm join testk8smaster.acme.com:6443 --token 70qyae.euc698bslt24k2ex --discovery-token-ca-cert-hash sha256:d44e6fbb35aba470f1b0ae5fc791c3e9603bed79c714887cb5b6520cbcf3013c 
   ```

6. **On the Worker Node - Join the Cluster**
   You must run the join command as root.
   Login as root, enter the join command copied in step 5
   ```bash
   su root

   # EXAMPLE ONLY:
   kubeadm join testk8smaster.acme.com:6443 --token 70qyae.euc698bslt24k2ex --discovery-token-ca-cert-hash sha256:d44e6fbb35aba470f1b0ae5fc791c3e9603bed79c714887cb5b6520cbcf3013c 
   ```

To add more workers, repeat this process by cloning the worker install script and updating NODE_HOSTNAME, NODE_IP_ADDRESS etc. as appropriate.

### How To Run pods on the Worker Node

**On the Master Node - Label the Worker**  
   Use the following command to get the status of the worker node:
   ```bash
   kubectl get nodes
   ```
   Once the worker is ready:
   ```bash
   kubectl label nodes k8sworker1.acme.com role=worker
   ```


**Edit K8S Deployment for Worker Role**
```yaml
    template:
        spec:
            nodeSelector:
                role: worker
```

See Movie Brain microservice deployments for examples of this, e.g.:  
[https://github.com/AlexanderHoughtonCA/moviebrain/blob/main/mb-api-gateway/deploy/deploy-mb-api-gateway.yaml](https://github.com/AlexanderHoughtonCA/moviebrain/blob/main/mb-api-gateway/deploy/deploy-mb-api-gateway.yaml)

**To Later Uninstall MetalLB & Ingress (optional)**  
   ```bash
   ./metallb/uninstall-metallb.sh
   ```

## Notes

- This setup is **for bare-metal clusters only**. MetalLB is required because cloud load balancers are not available.  
- Update the scripts with your **node hostnames, IP addresses, and network interface names** before running.  
- Edit `pool-config.yaml` to match the IP range available in your bare-metal network.  
- Reboot master and worker nodes before scheduling workloads.

License
MovieBrain is released under the MIT License. See the LICENSE file for details.
