#────────────────────────────────────────────
# Terraform: Umami Analytics CT
#────────────────────────────────────────────

resource "proxmox_lxc" "umami" {
  count       = 1
  description = "Umami Analytics - managed by Terraform"
  target_node = var.proxmox_node

  hostname = "umami"
  ostype   = "debian"
  template = "local:vztmpl/debian-12-standard_12.12-1_amd64.tar.zst"

  # Resources
  cores  = 2
  memory = 2048
  swap   = 512

  # Network — static IP
  network {
    name   = "eth0"
    bridge = var.network_bridge
    ip     = "dhcp"
  }

  # Storage
  rootfs_storage = var.proxmox_storage
  rootfs_size   = "8"

  unprivileged = true
  features {
    nesting = true
    keyctl  = true
  }

  on_boot = true

  # Mount ZFS for data
  mount {
    target = "/data"
    source = var.proxmox_storage_large
    prio   = 500
    type   = "mpath"
    file   = "/mnt/pve/main"
  }

  provisioner "remote-exec" {
    inline = [
      "apt-get update -qq",
      "apt-get install -y -qq curl wget git vim",
      "curl -fsSL https://get.docker.com | sh",
      "mkdir -p /data/umami",
    ]
  }
}
