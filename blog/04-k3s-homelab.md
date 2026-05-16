# From Docker Compose to Kubernetes in One Day — My Homelab K3s Journey

*Published: TBD | Reading time: 9 min*

---

## Why I Switched

Docker Compose was fine for 5 services. At 42 services, it broke down.

Every service had its own `docker-compose.yml`, its own restart logic, its own network config. Updating one thing meant SSHing into the host, `cd`-ing to the right directory, and running `docker-compose up -d`.

No visibility into what was running. No easy way to roll back. No automatic restarts across the whole stack.

So I installed Kubernetes.

---

## The Setup

```
Proxmox Host (192.168.50.104)
    └── K3s v1.35.4 (control plane + worker)
          ├── MetalLB (192.168.50.200-250 pool)
          ├── Traefik ingress controller
          ├── ArgoCD (GitOps)
          ├── PostgreSQL
          ├── Umami (analytics)
          ├── Uptime Kuma
          └── Portainer
```

No VMs. K3s installed directly on the Proxmox host. Total hardware: what I already had.

---

## The Hardest Part

**Installing K3s on Proxmox LXC containers doesn't work.**

I tried. K3s needs `br_netfilter` and `overlay` kernel modules. LXC containers can't load kernel modules.

**Solution:** Install K3s directly on the Proxmox host. It runs fine — Proxmox IS Debian underneath.

```bash
curl -sfL https://get.k3s.io | \
  K3S_KUBECONFIG_OUTPUT="/root/.kube/config-k3s" \
  sh -s - -- \
  --disable traefik \
  --write-kubeconfig-mode 0644 \
  --tls-san 192.168.50.104
```

That's it. 30 seconds. K3s is running.

---

## Load Balancing Without the Cloud

On cloud K8s, you get an external IP automatically from the cloud provider. In a homelab, you need MetalLB.

```yaml
# MetalLB L2 mode — gives LoadBalancer services an IP from your LAN
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: homelab-pool
  namespace: metallb-system
spec:
  addresses:
    - 192.168.50.200-192.168.50.250
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: homelab-l2
  namespace: metallb-system
spec:
  ipAddressPools:
    - homelab-pool
```

Now every `type: LoadBalancer` service gets an IP from that pool. No cloud provider needed.

---

## Deploying My First App

```bash
kubectl --kubeconfig=/root/.kube/config-k3s apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
  namespace: homelab
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: nginx
  namespace: homelab
spec:
  selector:
    app: nginx
  ports:
  - port: 80
    targetPort: 80
  type: LoadBalancer
EOF
```

And just like that — nginx was accessible at `192.168.50.201`.

---

## GitOps with ArgoCD

This is where it gets powerful.

I push YAML manifests to GitHub. ArgoCD watches the repo. Changes sync automatically.

```yaml
# ArgoCD Application
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: homelab-apps
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/graysonmeyer/homelab-infra.git
    targetRevision: main
    path: k8s/apps
  destination:
    server: https://kubernetes.default.svc
    namespace: homelab
  syncPolicy:
    automated:
      prune: true    # Remove deleted resources
      selfHeal: true # Auto-sync on drift
```

Now I can:
- See all 42 services in one dashboard
- Roll back any change with one click
- Deploy from my phone via ArgoCD mobile app

---

## What I Learned

### 1. LXC vs VM for K3s
Kernel modules required → K3s must be on bare metal or VM. LXC won't work.

### 2. MetalLB changes everything
LoadBalancer services get real IPs from your LAN. No cloud required.

### 3. GitOps isn't optional
Without ArgoCD, K8s is just a more complicated Docker Compose. With ArgoCD, it becomes a real platform.

### 4. Single-node is fine for homelab
You don't need 3 control planes for a homelab. One K3s server does everything.

---

## The Migration Plan

Moving from Docker Compose to K3s:

1. **Week 1:** K3s + MetalLB + Traefik (done ✓)
2. **Week 2:** Move stateless apps (nginx, dashboards)
3. **Week 3:** Move databases (PostgreSQL, SQLite)
4. **Week 4:** Move complex apps (Plex, Jellyfin with GPU)
5. **Week 5:** Set up ArgoCD, enable auto-sync
6. **Week 6:** Tear down Docker Compose

---

## What's Next

- **Migrate Jellyfin** to K8s with GPU passthrough
- **Set up cert-manager** for automatic TLS
- **Add monitoring** (Prometheus already on the host, need to scrape K8s)
- **Multi-node K3s** (when I have more hardware)

---

## The Numbers

| Metric | Docker Compose | K3s |
|--------|----------------|-----|
| Deploy time | 30s per service | 5s per app |
| Rollback | Manual | One click |
| Service discovery | Manual | Automatic DNS |
| Visibility | `docker ps` | ArgoCD dashboard |
| YAML files | 42 separate | 1 repo |
| Cost | $0 | $0 |
