# I Replaced Google Workspace With My Homelab — Here's What Actually Works

*Published: TBD | Reading time: 10 min*

---

## The Goal

No more $12/user/month for Google Workspace. No more lock-in. Own your data.

I run a complete productivity suite from my server:

| Google Service | My Homelab Replacement |
|---------------|----------------------|
| Gmail | Self-hosted email (Postfix + Roundcube) |
| Google Drive | Nextcloud (file sync, docs, collaborative) |
| Google Calendar | Cal.com (self-hosted) |
| Google Photos | Immich (AI-powered photo backup) |
| Google Keep | Notesnook (encrypted notes) |
| Google Docs | Nextcloud + Collabora Online |
| YouTube | PeerTube (private video hosting) |

**Cost: $0** (hardware I already own)

---

## Architecture

```
Internet (Cloudflare Tunnel)
         │
         ▼
   ┌─────────────────────────────┐
   │     Nginx Proxy Manager     │
   │   (SSL termination + vhosts)│
   └─────────────────────────────┘
         │
    ┌────┴────┬──────┬──────┐
    ▼         ▼      ▼      ▼
Nextcloud  Immich  Cal.com  VaultWarden
 (Drive)  (Photos)(Calendar)(Passwords)
```

---

## The Stack

### Nextcloud (File Sync + Docs)

**What it does:** Google Drive + Google Docs replacement. File sync, collaborative editing, calendar sync, contacts.

**Setup:**
```bash
# CT 116 — Nextcloud AIO
docker run \
  --init \
  --sig-proxy=true \
  --env NEXTCLOUD_DATADIR=/data/nextcloud-data \
  --volume nextcloud_aio_master_container:/mnt/docker-aio-config \
  --volume /var/run/docker.sock:/var/run/docker.sock \
  --env APACHE_PORT=11000 \
  --publish 8080:8080 \
  nextcloud/all-in-one:latest
```

**Features I use:**
- File sync (desktop + mobile clients)
- Calendar (CalDAV)
- Contacts (CardDAV)
- Collaborative documents (Collabora Online)
- Talk (video calls)

---

### Immich (Photo Backup)

**What it does:** Google Photos replacement. Auto-backup from phone, AI-powered tagging, face detection.

**Why it's better than Google Photos:**
- You own the data
- No upload limits
- Self-hosted AI (actually works)
- Face detection works locally

**Setup:** Runs in CT 115, bound to ZFS for 25TB storage.

---

### Vaultwarden (Passwords)

**What it does:** Self-hosted Bitwarden. Passwords, secure notes, TOTP authenticator.

**Setup:** CT 118. I use it for everything.

---

### Cal.com (Calendar + Scheduling)

**What it does:** Calendly replacement. Shareable scheduling links, team calendars, video calls.

**Why better than Calendly:**
- Self-hosted
- No per-seat pricing
- Unlimited events

---

## The Authentication Layer

Everything behind **Authentik** (CT 114) — single sign-on for the whole homelab:

```
User → Authentik SSO → Nextcloud ✓
                   → Immich ✓
                   → Vaultwarden ✓
                   → Cal.com ✓
```

No separate passwords for each service. One login.

---

## What Actually Works

### What I'd Do Again
- **Authentik SSO** — Worth the setup time. One login everywhere.
- **Nextcloud** — Stable, full-featured, good mobile apps.
- **Vaultwarden** — Bitwarden-compatible, no subscription.
- **Immich** — Better than I expected. Auto-backup just works.

### What I'd Skip
- **Self-hosted email** — Still using Gmail for external. SPF/DKIM/DMARC is a nightmare.
- **Collabora Online** — Too slow on my hardware. Nextcloud's integrated PDF viewer is enough.

---

## Cost Breakdown

| Service | Hardware | Electricity | Total |
|---------|----------|-------------|-------|
| Everything | $3,000 server | ~$15/mo | ~$15/mo |

vs. Google Workspace: $72/year = $432 for 3 users... forever.

Actually it's not even close. Own your infrastructure.
