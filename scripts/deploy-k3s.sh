#!/bin/bash
#────────────────────────────────────────────
# Deploy full K3s homelab stack
# Run on K3s control plane node
#────────────────────────────────────────────

set -e

KUBECONFIG="${KUBECONFIG:-/root/.kube/config-k3s}"
export KUBECONFIG

echo ">>> Deploying Homelab K3s Stack"
echo "    Kubeconfig: $KUBECONFIG"

# 1. Wait for K3s to be fully ready
echo ""
echo ">>> [1/6] Waiting for K3s node to be Ready..."
kubectl wait --for=condition=ready nodes --all --timeout=120s

# 2. Apply MetalLB
echo ""
echo ">>> [2/6] Deploying MetalLB..."
kubectl apply -f /opt/k8s-manifests/core/metallb.yaml
kubectl wait --namespace metallb-system \
  --for=condition=ready pod \
  --selector=app=metallb \
  --timeout=120s

# 3. Create namespace
echo ""
echo ">>> [3/6] Creating homelab namespace..."
kubectl apply -f /opt/k8s-manifests/apps/namespace.yaml

# 4. Deploy PostgreSQL
echo ""
echo ">>> [4/6] Deploying PostgreSQL..."
kubectl apply -f /opt/k8s-manifests/core/postgres.yaml
kubectl rollout status deployment/postgres -n homelab --timeout=120s

# 5. Deploy Umami
echo ""
echo ">>> [5/6] Deploying Umami..."
kubectl apply -f /opt/k8s-manifests/apps/umami.yaml
kubectl rollout status deployment/umami -n homelab --timeout=120s

# 6. Deploy ArgoCD (GitOps)
echo ""
echo ">>> [6/6] Deploying ArgoCD..."
kubectl apply -f /opt/k8s-manifests/core/argocd.yaml || true
# ArgoCD takes a while, don't block on it

echo ""
echo "=== DEPLOYMENT COMPLETE ==="
echo ""
kubectl get nodes -o wide
echo ""
kubectl get pods -A
echo ""
echo "Next steps:"
echo "  1. Get ArgoCD password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
echo "  2. Access ArgoCD: kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "  3. Push manifests to GitHub and configure GitOps"
