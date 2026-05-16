# Homelab Infrastructure as Code

**Owner:** Grayson Meyer  
**Purpose:** Document, automate, and version-control my entire Proxmox homelab.  
**Stack:** Proxmox VE, K3s, Terraform, Ansible, GitHub Actions  

---

## What's Here

```
homelab-infra/
├── terraform/          # All Terraform configurations
│   ├── provider.tf    # Proxmox provider setup
│   ├── ct/           # Container definitions
│   └── variables.tf  # Shared variables
├── ansible/          # Ansible playbooks
│   ├── playbooks/    # Individual playbooks
│   └── roles/       # Reusable roles
├── k8s/              # Kubernetes manifests (K3s)
│   ├── apps/        # Application deployments
│   └── core/        # Core services (Traefik, MetalLB, etc.)
├── scripts/          # Utility scripts
├── github-actions/  # CI/CD workflows
└── .github/
    └── workflows/   # GitHub Actions pipelines
```

---

## Quick Start

### Prerequisites
- Proxmox VE 8+ with API token
- Terraform ≥ 1.5
- Ansible ≥ 2.15
- kubectl ≥ 1.28

### Deploy Everything
```bash
# 1. Initialize Terraform
cd terraform
terraform init

# 2. Plan changes
terraform plan -var-file="prod.tfvars"

# 3. Apply
terraform apply -var-file="prod.tfvars"

# 4. Run Ansible for configuration
cd ../ansible
ansible-playbook playbooks/site.yml
```

### K3s Access
```bash
# Copy kubeconfig from K3s server
scp root@<k3s-host>:/etc/rancher/k3s/k3s.yaml ./kubeconfig
export KUBECONFIG=./kubeconfig
kubectl get nodes
```

---

## Current Infrastructure

| Service | CT/VM | IP | Port |
|---------|--------|-----|------|
| Jellyfin | 104 | 192.168.50.104:8096 | External |
| Radarr | 100 | 192.168.50.100 | 7878 |
| Sonarr | 101 | 192.168.50.101 | 8989 |
| Prowlarr | 102 | 192.168.50.102 | 9696 |
| qBittorrent | 103 | 192.168.50.103 | 8080 |
| Bazarr | 105 | 192.168.50.105 | 6767 |
| Jellyseerr | 106 | 192.168.50.106 | 5056 |
| NPM | 107 | 192.168.50.107 | 81 |
| Homepage | 108 | 192.168.50.108 | 3000 |
| Plex | 110 | 192.168.50.110 | 32400 |
| Nginx Proxy Manager | NPM | *.meyernet.xyz |
| Prometheus | Host | 192.168.50.104:9091 |
| Grafana | Host | 192.168.50.104:3000 |

---

## Architecture

```
Internet → UniFi (192.168.50.1) → Proxmox Host (192.168.50.104)
                                              │
                           ┌──────────────────┼──────────────────┐
                           │                  │                  │
                        CT 100-132       CT 140-160         CT 165+
                     (Media Stack)     (App Stack)      (Desktop VM)
```

---

## Network

- **LAN:** 192.168.50.0/24
- **Gateway:** 192.168.50.1 (UniFi)
- **Host:** 192.168.50.104
- **DNS:** Cloudflare (cloudflared tunnel)

---

## Security

- UFW on host: SSH (LAN only), PVE UI (LAN only)
- SMB disabled (445, 139 blocked)
- Cloudflare for all external traffic
- Secrets in 1Password, not in git
