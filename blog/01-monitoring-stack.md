# How I Monitor 42 Services with Prometheus + Grafana — For Free

*Published: TBD | Reading time: 8 min*

---

## The Problem

42 services. One server. How do you know what's running without checking 42 dashboards?

When I started my homelab, I checked services manually. I'd SSH in, run `systemctl status jellyfin`, move on. Repeat for every service. It worked until it didn't.

One day I noticed Jellyfin had been down for 6 hours. Nobody told me.

That's when I built this:

```
┌─────────────────────────────────────────────┐
│           Grafana Dashboard                 │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐ │
│  │ CPU: 18% │  │ RAM: 47G │  │ 42 CTs   │ │
│  │          │  │          │  │ running  │ │
│  └──────────┘  └──────────┘  └──────────┘ │
└─────────────────────────────────────────────┘
         ▲
         │ :9091
┌────────────────┐
│   Prometheus   │ ◄── node_exporter (every 30s)
│   v2.53.3     │
└────────────────┘
         ▲
         │ scrape
┌────────────────┐     ┌──────────────────────┐
│ Proxmox Host  │────►│ CTs (100-165)        │
│ 192.168.50.104│     │ 42 containers        │
└────────────────┘     └──────────────────────┘
```

**Cost: $0. Hardware I already had.**

---

## What I Monitor

| Service | CT | What I Track |
|---------|----|--------------|
| Jellyfin | 104 | CPU, RAM, transcode sessions |
| Radarr/Sonarr | 100-101 | Disk, download queue |
| Plex | 110 | Stream count, bandwidth |
| GPU CTs | 128, 144 | VRAM, temperature |
| Nginx Proxy Manager | 107 | Request rate, SSL certs |
| All CTs | 100-165 | CPU, RAM, disk I/O, network |

---

## The Stack

### 1. node_exporter (Prometheus)
Runs on the Proxmox host. Exports hardware metrics.

```bash
# Installed via apt on the Proxmox host
apt install prometheus-node-exporter
```

Key metrics:
- `node_cpu_seconds_total` — CPU usage per core
- `node_memory_MemTotal_bytes` — Total RAM
- `node_memory_MemAvailable_bytes` — Free RAM
- `node_filesystem_avail_bytes` — Disk space per mount
- `rate(node_network_receive_bytes_total[5m])` — Network throughput

### 2. Prometheus (the aggregator)
Scrape configs from the Proxmox host + targets:

```yaml
# /etc/prometheus/prometheus.yml
global:
  scrape_interval: 30s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9091']

  - job_name: 'node_exporter'
    static_configs:
      - targets: ['192.168.50.104:9100']
```

Started as a systemd service:
```ini
[Unit]
Description=Prometheus Server
After=network.target

[Service]
ExecStart=/usr/sbin/prometheus \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/var/lib/prometheus \
  --web.console.libraries=/usr/share/prometheus/console_libraries \
  --web.console.templates=/usr/share/prometheus/consoles

[Install]
WantedBy=multi-user.target
```

### 3. Grafana (the dashboard)
Runs on the Proxmox host at `http://192.168.50.104:3000`

```bash
# Installed via apt
apt install grafana
systemctl enable --now grafana-server
```

**Key panels I use:**

1. **System Overview** (home dashboard)
   - CPU % (gauge, color coded: green < 60%, yellow < 85%, red >= 85%)
   - RAM usage (gauge with available/used
   - Uptime
   - Load average (1/5/15 min)

2. **Container Grid**
   - All 42 CTs in a stat panel grid
   - Shows CPU + RAM per CT
   - Red if CPU > 80% or RAM > 90%

3. **Disk I/O**
   - Read/write bytes per second per disk
   - ZFS pool utilization

4. **Network**
   - Bandwidth in/out per CT
   - Top talkers

---

## How I Built It

### Step 1: Install Prometheus + node_exporter on Proxmox host

```bash
# Add Prometheus repo
apt install -y apt-transport-https curl gnupg
curl -fsSL https://apt.rometheus.io/GPG-KEY | gpg --dearmor -o /etc/apt/trusted.gpg.d/prometheus.gpg

echo "deb https://apt.rometheus.io stable main" > /etc/apt/sources.list.d/prometheus.list
apt update && apt install prometheus prometheus-node-exporter
```

### Step 2: Configure Prometheus

Create `/etc/prometheus/prometheus.yml` with targets for:
- node_exporter (`:9100`)
- Prometheus itself (`:9091`)
- Any other exporters you add

### Step 3: Install Grafana

```bash
apt install grafana
systemctl enable --now grafana-server
```

### Step 4: Add Prometheus data source

1. Open Grafana at `:3000`
2. → Connections → Data Sources → Add data source
3. Select Prometheus
4. URL: `http://localhost:9091`
5. Save & Test

### Step 5: Build your first dashboard

**Panel: CPU Usage**
```promql
100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
```

**Panel: Memory Usage**
```promql
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100
```

**Panel: Disk Space**
```promql
100 - (node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"} * 100)
```

---

## Pro Tips

### 1. Alerting (before something breaks)

I use Grafana's built-in alerting to catch problems early:

```yaml
# Example: CT using > 90% RAM
- alert: HighMemoryUsage
  expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 90
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "High memory usage on {{ $labels.instance }}"
```

Alert routing → Grafana's notification channels (I use Discord webhook).

### 2. GPU Monitoring

For my RTX 4060 Ti (passed through to different CTs):

```bash
# In each GPU CT, run nvidia-exporter or node_exporter with GPU metrics
nvidia-smi --query-gpu=utilization.gpu,utilization.memory,temperature.gpu --format=csv,noheader,nounits
```

I wrote a small script that exposes these as Prometheus metrics.

### 3. SSL Certificate Expiry

```promql
certificate_expiry_seconds{cert="/etc/letsencrypt/live/meyernet.xyz/fullchain.pem"} < 86400 * 30
```

30 days before expiry → alert.

---

## What I Learned

**The biggest lesson:** Start simple. My first monitoring setup had 15 different exporters, Kubernetes, and fancy service meshes. It was overkill. 

Now I have 3 components doing everything I need.

**Second lesson:** Scrape interval matters. 30s is fine for homelab. 10s is better for fast-changing metrics. 60s is fine for historical trends.

**Third lesson:** Dashboards are personal. Build what YOU need to see at a glance. Don't copy random dashboards — they'll have panels for services you don't run.

---

## What's Next

Right now I monitor everything. Next I'm adding:

- **ArgoCD** to auto-deploy changes to my monitoring config
- **Loki** for logs (currently using Grafana's built-in log panel with node_exporter logs)
- **Alertmanager** for deduplicated alerts across Discord + email

Eventually I want to migrate this to Kubernetes so I can use the full Prometheus Operator with ServiceMonitors and PodMonitors.

---

## The Numbers

| Metric | Value |
|--------|-------|
| Services monitored | 42 |
| Dashboards | 6 |
| Alert rules | 12 |
| Cost | $0 |
| Time to build | ~3 hours |
| Monthly maintenance | ~5 min |

Not bad for a Saturday afternoon.
