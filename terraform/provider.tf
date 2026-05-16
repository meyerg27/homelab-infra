#────────────────────────────────────────────
# Proxmox Provider Configuration
#────────────────────────────────────────────

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "~> 3.0"
    }
  }

  backend "local" {
    path = "terraform.tfstate"
  }
}

#────────────────────────────────────────────
# Provider Configuration
#────────────────────────────────────────────

provider "proxmox" {
  pm_api_url          = var.proxmox_api_url
  pm_api_token_id    = var.proxmox_api_token_id
  pm_api_token_secret = var.proxmox_api_token_secret
  pm_tls_insecure     = true  # Self-signed cert on PVE
  pm_log_levels = {
    _default = "debug"
    _capture = "debug"
  }
}

#────────────────────────────────────────────
# Required Variables
#────────────────────────────────────────────

variable "proxmox_api_url" {
  description = "Proxmox API URL (e.g., https://192.168.50.104:8006/api2/json/)"
  type        = string
  sensitive   = true
}

variable "proxmox_api_token_id" {
  description = "Proxmox API token ID (format: root@pam!tokenname)"
  type        = string
  sensitive   = true
}

variable "proxmox_api_token_secret" {
  description = "Proxmox API token secret"
  type        = string
  sensitive   = true
}

#────────────────────────────────────────────
# Shared Variables
#────────────────────────────────────────────

variable "proxmox_node" {
  description = "Proxmox node name"
  type        = string
  default     = "pve"
}

variable "proxmox_storage" {
  description = "Default storage for CT disks"
  type        = string
  default     = "local-lvm"  # Thin-provisioned LVM on OS SSD
}

variable "proxmox_storage_large" {
  description = "Storage with larger capacity (for data)"
  type        = string
  default     = "main"  # ZFS pool with 960GB SSD
}

variable "network_bridge" {
  description = "Proxmox network bridge"
  type        = string
  default     = "vmbr0"
}

variable "network_gateway" {
  description = "Network gateway"
  type        = string
  default     = "192.168.50.1"
}
