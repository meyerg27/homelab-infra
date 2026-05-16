# I Provisioned My Entire Homelab with Terraform — Here's What I Learned

*Published: TBD | Reading time: 7 min*

---

## Why Terraform for a Homelab?

Everyone talks about Terraform for AWS and GCP. Nobody talks about using it for your homelab.

But it makes perfect sense. When you have 42 containers to manage, a text file that describes your entire infrastructure becomes invaluable.

**The problem I had:** I could never remember what was running where. CT 116 was Nextcloud? Or was that 118? What IP did I give Plex?

**The solution:** Everything as code. `terraform plan` shows me exactly what will change before it changes.

---

## The Setup

I use the [Telmate Proxmox provider](https://github.com/Telmate/terraform-provider-proxmox) for Terraform.

```hcl
provider "proxmox" {
  pm_api_url          = "https://192.168.50.104:8006/api2/json/"
  pm_api_token_id    = "root@pam!terraform"
  pm_api_token_secret = "your-token-here"
  pm_tls_insecure     = true
}
```

Generate a Proxmox token specifically for Terraform:

```bash
# On Proxmox
pveum user add root@pam!terraform
pveum role modify Kubernetes -permissions VM.Allocate VM.Audit ...
pveum auth add token root@pam!terraform --role Kubernetes
```

---

## Creating a Container

The most common task in my homelab:

```hcl
resource "proxmox_lxc" "nextcloud" {
  count       = 1
  description = "Nextcloud - managed by Terraform"
  target_node = "pve"

  hostname = "nextcloud"
  ostype   = "debian"
  template = "local:vztmpl/debian-12-standard_12.12-1_amd64.tar.zst"

  # Compute
  cores  = 4
  memory = 4096
  swap   = 512

  # Network
  network {
    name   = "eth0"
    bridge = "vmbr0"
    ip     = "dhcp"
  }

  # Storage
  rootfs_storage = "local-lvm"
  rootfs_size   = "16"

  # Features for nesting (Docker, etc.)
  unprivileged = true
  features {
    nesting = true
    keyctl  = true
  }

  on_boot = true

  # Auto-mount ZFS storage
  mount {
    target = "/data"
    source = "main"
    prio   = 500
    type   = "mpath"
    file   = "/mnt/pve/main"
  }
}
```

Then:

```bash
terraform plan   # See what will happen
terraform apply  # Create the CT
```

---

## The Best Part: Import Existing Resources

Had a CT already running? Import it:

```bash
terraform import proxmox_lxc.nextcloud 100
```

Now Terraform manages it. Delete the HCL file and `terraform apply` destroys it.

---

## Variables and Reusability

```hcl
variable "proxmox_node" {
  default = "pve"
}

variable "ct_defaults" {
  description = "Default settings for CTs"
  type = object({
    cores  = number
    memory = number
    storage = string
  })
  default = {
    cores  = 2
    memory = 2048
    storage = "local-lvm"
  }
}
```

Module system for reusable patterns:

```hcl
module "docker_ct" {
  source  = "./modules/docker-ct"
  version = "1.0.0"
  
  hostname = "plex"
  ip       = "192.168.50.110"
  storage  = var.proxmox_storage_large
}
```

---

## State Management

**Critical:** Terraform state contains sensitive data. Never commit it to git.

```bash
# Local state (fine for homelab)
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}

# For team environments
terraform {
  backend "s3" {
    bucket = "my-homelab-tfstate"
    key    = "prod/terraform.tfstate"
  }
}
```

My `.gitignore`:
```
*.tfstate
*.tfstate.*
```

---

## The GitOps Flow

Every infrastructure change follows this flow:

```
1. Edit .tf file
2. git add . && git commit -m "Add Nextcloud CT"
3. terraform plan     # Review changes
4. terraform apply    # Apply
5. git push           # Sync to GitHub
```

ArgoCD watches the git repo and applies changes automatically on other nodes.

---

## What I'd Do Differently

### 1. Start with Terraform earlier
I managed 42 CTs manually for months. Terraform would have saved hours.

### 2. Use modules from the start
Instead of copy-pasting CT definitions, define a `base_ct` module.

### 3. Separate staging and prod
Use workspaces for different environments:
```bash
terraform workspace new prod
terraform workspace new staging
```

---

## The Result

| Metric | Before | After |
|--------|--------|-------|
| Time to create a new CT | 15 min | 2 min |
| Documentation | None | Auto-generated from code |
| Disaster recovery | "I hope I remember" | `terraform apply` |
| Reproducibility | Zero | Full |

---

## Getting Started

1. Install Terraform: `brew install terraform`
2. Generate Proxmox API token
3. Write your first `.tf` file
4. Run `terraform init && terraform plan`
5. Start small — migrate one CT, then expand

The hardest part is starting. Once you have one CT managed by Terraform, you'll never go back to `pct create` manually.
