#!/bin/bash
#────────────────────────────────────────────
# Cloudflare DNS Setup for K3s Subdomains
# Run this to add DNS records for K3s services
# Requires: CF_API_TOKEN or CF_EMAIL + CF_GLOBAL_KEY
#────────────────────────────────────────────

set -e

# Configuration
CF_ZONE_ID="fcc3ebc588ec0608aa2538aa7bb89039"  # mngdetailing.com zone
K3S_INGRESS_IP="192.168.50.200"

# Authentication (use API token OR global key)
CF_API_TOKEN="${CF_API_TOKEN:-}"  # API Token
CF_EMAIL="${CF_EMAIL:-Solestingray459@gmail.com}"  # For global key
CF_GLOBAL_KEY="${CF_GLOBAL_KEY:-}"  # Global API Key

# Auth headers
if [[ -n "$CF_API_TOKEN" ]]; then
  AUTH_HEADER="Authorization: Bearer ${CF_API_TOKEN}"
else
  AUTH_HEADER="X-Auth-Email: ${CF_EMAIL}"
  if [[ -z "$CF_GLOBAL_KEY" ]]; then
    echo "ERROR: Need either CF_API_TOKEN or CF_EMAIL + CF_GLOBAL_KEY"
    exit 1
  fi
fi

# Function to create DNS record
create_record() {
  local name="$1"
  local result
  result=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records" \
    -H "$AUTH_HEADER" \
    ${CF_GLOBAL_KEY:+-H "X-Auth-Key: ${CF_GLOBAL_KEY}"} \
    -H "Content-Type: application/json" \
    -d "{\"type\":\"A\",\"name\":\"${name}\",\"content\":\"${K3S_INGRESS_IP}\",\"ttl\":300,\"proxied\":false}")
  
  if echo "$result" | grep -q '"success":true'; then
    echo "✅ ${name} → ${K3S_INGRESS_IP}"
  else
    echo "❌ ${name}: $(echo "$result" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['errors'][0]['message'])" 2>/dev/null || echo "unknown error")"
  fi
}

echo "Creating K3s DNS records in Cloudflare..."
echo "Zone: mngdetailing.com"
echo "IP: ${K3S_INGRESS_IP}"
echo ""

create_record "umami.k3s.meyernet.xyz"
create_record "status.k3s.meyernet.xyz"
create_record "portainer.k3s.meyernet.xyz"
create_record "test.k3s.meyernet.xyz"
create_record "k3s.meyernet.xyz"

echo ""
echo "Done! Records will propagate in ~60 seconds."
echo "Then access via: https://umami.k3s.meyernet.xyz"
