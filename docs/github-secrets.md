# GitHub Actions — Secrets Setup

## Required Secrets

Set these in `https://github.com/graysonmeyer/homelab-infra/settings/secrets/actions`

### Proxmox
```
PM_API_URL        → https://192.168.50.104:8006/api2/json/
PM_API_TOKEN_ID   → root@pam!openclaw
PM_API_TOKEN_SECRET → 7023479f-f4b1-40ce-8555-baef3e93f357
```

### Cloudflare (for cert-manager DNS challenge)
```
CF_API_TOKEN      → Your Cloudflare API token with Zone:DNS:Edit
```

### Optional
```
K3S_TOKEN         → Node token for adding workers (if multi-node)
```

## Generate a New Proxmox Token

```bash
# On Proxmox host
pveum user add root@pam!github-action
pveum role modify Kubernetes -permissions VM.Allocate VM.Audit VM.Clone VM.Config.Disk VM.Config.Network VM.Config.Options VM.Config.System VM.Console VM.Monitor VM.PowerMgmt VM.Snapshot.Directory Datastore.Allocate Datastore.Audit Datastore.File.Download Datastore.File.Upload Sys.Audit Sys.Console Sys.Modify
pveum auth add token root@pam!github-action --role Kubernetes
```

## GitHub Repo Setup

1. Create repo: `https://github.com/new`
   - Name: `homelab-infra`
   - Private or Public

2. Enable GitHub Actions (Settings → Actions → Allow all actions)

3. Add secrets above

4. Push code:
```bash
git init
git add .
git commit -m "Initial commit: homelab infrastructure"
git branch -M main
git remote add origin https://github.com/graysonmeyer/homelab-infra.git
git push -u origin main
```
