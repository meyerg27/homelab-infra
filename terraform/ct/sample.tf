#────────────────────────────────────────────
# Example: Base CT Template
#────────────────────────────────────────────

resource "proxmox_lxc" "base_ct" {
  count       = 1
  description = "Base Debian CT - managed by Terraform"
  target_node = var.proxmox_node

  # OS Template (from local storage)
  ostype  = "debian"
  template = "local:vztmpl/debian-12-standard_amd64.tar.gz"

  # Compute
  cores   = 2
  memory  = 2048
  swap    = 512

  # Network
  network {
    name   = "eth0"
    bridge = var.network_bridge
    ip     = "dhcp"
  }

  # Storage
  rootfs_storage = var.proxmox_storage
  rootfs_size   = "8"

  # Privileged (needed for nesting Docker, ZFS, etc.)
  # For unprivileged containers, use nesting=1 feature flag
  unprivileged = true

  # Features for nesting
  features {
    nesting = true  # Required for Docker inside LXC
    keyctl  = true  # Required for some systemd features
  }

  # Auto-start
  on_boot = true

  # Provisioning hook (runs on first boot)
  # provisioning "local" {
  #   type = "start"
  #   files = [
  #     {
  #       key   = "/etc/apt/sources.list"
  #       type  = "file"
  #       source = "./files/sources.list"
  #     }
  #   ]
  # }

  provisioner "remote-exec" {
    inline = [
      "apt-get update",
      "apt-get install -y curl wget git",
    ]
  }
}

#────────────────────────────────────────────
# Example: Docker CT
#────────────────────────────────────────────

resource "proxmox_lxc" "docker_ct" {
  count       = 1
  description = "Docker CT - managed by Terraform"
  target_node = var.proxmox_node

  hostname = "docker-${count.index + 1}"

  ostype  = "debian"
  template = "local:vztmpl/debian-12-standard_amd64.tar.gz"

  cores   = 4
  memory  = 4096
  swap    = 1024

  network {
    name   = "eth0"
    bridge = var.network_bridge
    ip     = "dhcp"
  }

  rootfs_storage = var.proxmox_storage
  rootfs_size   = "16"

  unprivileged = true

  features {
    nesting = true
    keyctl  = true
  }

  on_boot = true

  # Mount ZFS storage for Docker
  mount {
    target   = "/data"
    source   = "main"
    prio     = 500
    type     = "mpath"
    file     = "/mnt/pve/main"
  }

  provisioner "remote-exec" {
    inline = [
      "curl -fsSL https://get.docker.com | sh",
      "usermod -aG docker root",
      "systemctl enable docker",
    ]
  }
}
