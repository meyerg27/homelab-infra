#!/bin/bash
#────────────────────────────────────────────
# K3s Single-Node Install Script
# Run on Proxmox host or dedicated VM
#────────────────────────────────────────────

set -euo pipefail

K3S_VERSION="${K3S_VERSION:-v1.30.0+k3s1}"
INSTALL_SCRIPT="${INSTALL_SCRIPT:-https://get.k3s.io}"

echo ">>> Installing K3s ${K3S_VERSION}..."

# Check resources
CPU=$(nproc)
RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
RAM_GB=$((RAM_KB / 1024 / 1024))

echo "    CPU: ${CPU} cores"
echo "    RAM: ${RAM_GB} GB"

if [[ ${RAM_GB} -lt 4 ]]; then
    echo "ERROR: K3s requires at least 4GB RAM"
    exit 1
fi

# Install K3s (single-node, no Traefik bundled, use Flannel)
curl -sfL "${INSTALL_SCRIPT}" | \
    INSTALL_K3S_VERSION="${K3S_VERSION}" \
    K3S_KUBECONFIG_MODE="0644" \
    K3S_FLAGS="--disable traefik --write-kubeconfig-mode 0644 --tls-san 192.168.50.104" \
    sh -

echo ">>> K3s installed!"
echo ""

# Get node token for worker joins
if [[ -f /var/lib/rancher/k3s/server/node-token ]]; then
    echo "Node token:"
    cat /var/lib/rancher/k3s/server/node-token
fi

# Get kubeconfig
echo ""
echo "Kubeconfig at: /etc/rancher/k3s/k3s.yaml"
echo "Copy to local: scp root@192.168.50.104:/etc/rancher/k3s/k3s.yaml ~/.kube/config"

# Wait for node to be ready
echo ""
echo ">>> Waiting for node to be ready..."
kubectl get nodes --wait=true --timeout=120s || true

echo ""
echo ">>> Status:"
kubectl get nodes
kubectl get pods -A
