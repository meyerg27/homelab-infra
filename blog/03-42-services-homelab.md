# 42 Services on One Server: How My Homelab Actually Works

*Published: TBD | Reading time: 12 min*

---

## The Setup

One server. 42 services. Here's what I learned running a production-grade homelab.

**Hardware:**
- CPU: AMD Ryzen 9 5950X (16 cores, 32 threads)
- RAM: 128GB ECC
- Storage: 256GB OS SSD + 960GB data SSD + 14TB ZFS array
- Network: 10GbE
- GPU: NVIDIA RTX 4060 Ti (8GB VRAM)

**Software:**
- Proxmox VE 9.1 (hypervisor)
- 42 LXC containers + 2 VMs
- ZFS for storage
- Nginx Proxy Manager for reverse proxy
- Cloudflare for DNS + tunnels

**Cost to run:** ~$15/month electricity

---

## The Architecture

```
                    Internet
                        │
                 Cloudflare CDN
                        │
              ┌─────────┴──────────┐
              │   Cloudflared     │
              │   Tunnel (all     │
              │   subdomains)      │
              └─────────┬──────────┘
                        │
              ┌─────────▼──────────┐
              │  Nginx Proxy Mgr   │
              │  (SSL + vhosts)    │
              │  192.168.50.107   │
              └─────────┬──────────┘
                        │
        ┌───────────────┼───────────────┐
        │               │               │
   ┌────▼────┐   ┌─────▼────┐   ┌─────▼────┐
   │ Media   │   │ Apps    │   │ GPU      │
   │ Stack  │   │ Stack   │   │ Stack    │
   │ CT 100-│   │ CT 114- │   │ CT 128   │
   │ 113    │   │ 132     │   │ CT 144   │
   └─────────┘   └─────────┘   └──────────┘
```

---

## Media Stack (CTs 100-113)

**What it does:** Downloads, organizes, and streams all my media.

| CT | Service | Port |
|----|---------|------|
| 100 | Radarr | 7878 |
| 101 | Sonarr | 8989 |
| 102 | Prowlarr | 9696 |
| 103 | qBittorrent | 8080 |
| 104 | Jellyfin | 8096 |
| 105 | Bazarr | 6767 |
| 106 | Jellyseerr | 5056 |
| 110 | Plex | 32400 |
| 112 | Lidarr | 8686 |
| 113 | Threadfin | 34400 |

**VPN:** All download clients route through AirVPN (WireGuard). Kill switch ensures nothing leaks.

**GPU sharing:** The RTX 4060 Ti is passed through to CT 104 (Jellyfin) and CT 128 (Tdarr) for hardware transcoding.

---

## App Stack (CTs 114-132)

**What it does:** Productivity suite — SSO, storage, passwords, etc.

| CT | Service | Description |
|----|---------|-------------|
| 114 | Authentik | SSO for everything |
| 115 | Immich | Photo backup |
| 116 | Nextcloud | File sync + docs |
| 117 | OpenWebUI | Local AI (Ollama) |
| 118 | Vaultwarden | Passwords |
| 119 | Stirling-PDF | PDF tools |
| 120 | Audiobookshelf | Audiobooks |
| 121 | Mealie | Recipes |
| 122 | Paperless-NGX | Document scanning |
| 123 | Calibre-web | eBooks |
| 124 | Readarr | Audiobook downloads |
| 127 | AdGuard | DNS + ad blocking |
| 128 | Tdarr | Video transcoding |
| 131 | Gitea | Git repos |
| 132 | WireGuard | VPN server |

---

## GPU Stack (CTs 128, 144)

**CT 128 — Tdarr:** Batch video transcoding. Uses GPU for NVENC/NVDEC — 10x faster than CPU.

**CT 144 — ComfyUI:** AI image generation. Runs Stable Diffusion locally.

**GPU sharing via:** Toggle script (`/opt/gpu-toggle.sh`) that unbinds the GPU from one CT and passes it to another.

---

## The Reverse Proxy Layer

Every service is behind Nginx Proxy Manager at `https://*.meyernet.xyz`:

```
jellyfin.meyernet.xyz    → CT 104:8096
radarr.meyernet.xyz      → CT 100:7878
nextcloud.meyernet.xyz   → CT 116:80
vaultwarden.meyernet.xyz → CT 118:8080
```

SSL certs: Let's Encrypt wildcard `*.meyernet.xyz` — automatically renewed.

---

## The Monitoring Layer

I can see everything in Grafana:

- **42 container CPU/RAM/disk** at a glance
- **GPU utilization** when in use
- **ZFS pool health** (16.3TB used of 25.4TB)
- **Network throughput** per CT
- **SSL cert expiry** alerts

Built with: Prometheus + Grafana on the Proxmox host itself.

---

## What I'd Do Differently

### 1. Better Network Segmentation

Right now everything is on `192.168.50.0/24`. I'd use VLANs:
- `192.168.50.0/24` — Management
- `192.168.51.0/24` — Media stack
- `192.168.52.0/24` — App stack
- `192.168.53.0/24` — GPU workloads

### 2. Use K3s Earlier

I managed all 42 CTs manually for too long. Kubernetes would make:
- Service discovery automatic
- Rolling updates trivial
- Resource limits enforced

### 3. Proper Backup Strategy

I have `/HDDs/backups` but it's not automated well. Should use:
- Proxmox Backup Server (PBS)
- Offsite replication to another location

---

## The Cost

| Component | Cost |
|-----------|------|
| Electricity (~$0.12/kWh) | ~$15/month |
| Domain (meyernet.xyz) | $12/year |
| Total | ~$16/month |

vs. hosting 42 services in the cloud: $500+/month minimum.

---

## Key Takeaways

1. **Start simple.** Proxmox + LXC is the easiest way to run many services.
2. **Automate everything.** Ansible, Terraform, GitOps.
3. **Monitor everything.** You can't fix what you can't see.
4. **Use hardware you have.** A used server is better than no server.
5. **Document everything.** You'll forget.

The best homelab is the one you actually maintain.
