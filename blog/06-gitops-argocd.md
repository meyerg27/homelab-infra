# GitOps in My Homelab: How ArgoCD Changed Everything

*Published: TBD | Reading time: 8 min*

---

## The Problem

Before GitOps, my deployment process looked like this:

1. SSH into the server
2. `kubectl apply -f deployment.yaml`
3. Hope it worked
4. No rollback plan if it didn't

Every deployment was manual. Every change was ephemeral. If I broke something, I'd have to remember what I did.

Then I discovered ArgoCD.

---

## What is GitOps?

GitOps = Git is the source of truth for your infrastructure.

```
GitHub (manifests)
     │
     │ push
     ▼
ArgoCD (watches repo)
     │
     │ detects change
     ▼
Kubernetes (applies manifests)
```

Every change to your infrastructure is a git commit. Every deployment is automatic. Every rollback is `git revert`.

---

## Setting Up ArgoCD

Install in 2 minutes:

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/master/manifests/install.yaml
```

Access the UI:

```bash
# Port forward
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Get password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```

Open `https://localhost:8080`, login with `admin` + password.

---

## The Application CRD

Connect ArgoCD to your git repo:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: homelab-apps
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/graysonmeyer/homelab-infra.git
    targetRevision: main
    path: k8s/apps
  destination:
    server: https://kubernetes.default.svc
    namespace: homelab
  syncPolicy:
    automated:
      prune: true    # Delete removed resources
      selfHeal: true # Fix drift automatically
```

Push to GitHub. ArgoCD syncs automatically.

---

## The App-of-Apps Pattern

One Application to rule them all:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: homelab-root
  namespace: argocd
spec:
  source:
    repoURL: https://github.com/graysonmeyer/homelab-infra.git
    path: k8s/core
  destination:
    server: https://kubernetes.default.svc
```

This single Application manages all your other Applications. One `kubectl apply` sets up your entire cluster.

---

## Sync Waves

Control the order of deployments:

```yaml
syncPolicy:
  syncOptions:
    - ApplyOutOfSyncOnly=true  # Only apply if drifted
  retry:
    limit: 5
    backoff:
      duration: 5s
      factor: 2
```

ArgoCD will retry failed syncs automatically.

---

## What GitOps Gives You

### 1. **Visibility**
Every change is visible in the ArgoCD UI. Green = synced, Yellow = drifted, Red = broken.

### 2. **Rollback**
Git revert = infrastructure rollback. `git revert abc123 && git push` → ArgoCD detects → K8s rolls back.

### 3. **Audit Trail**
Every change has a commit. Who changed what, when, why. All in git blame.

### 4. **Multi-Environment**
Different branches for different clusters:
- `main` → production
- `staging` → staging

### 5. **Self-Healing**
If someone manually changes something in the cluster, ArgoCD detects drift and reverts it.

---

## Real Example: Deploying Umami

Before GitOps:
```bash
kubectl apply -f umami.yaml
# Hope it works
```

With GitOps:
```bash
# Edit the manifest
vim k8s/apps/umami.yaml

# Commit and push
git add k8s/apps/umami.yaml
git commit -m "Update Umami image to latest"
git push
```

ArgoCD detects the change, syncs it, and shows you the deployment progress in the UI. 60 seconds later, Umami is updated.

---

## The GitHub Actions Pipeline

Automate testing before deployment:

```yaml
name: Homelab CI
on: [push, pull_request]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Validate YAML
        run: |
          find k8s -name "*.yaml" | xargs kubeval
      - name: Terraform Validate
        run: |
          terraform init && terraform validate
      - name: Helm Lint
        run: |
          for chart in k8s/*/Chart.yaml; do
            helm lint "$(dirname $chart)"
          done
```

Only merges to `main` trigger ArgoCD syncs.

---

## Secrets Management

Never commit secrets to git. Use:

1. **Sealed Secrets** — Encrypt secrets with a cluster key
2. **Vault** — HashiCorp Vault for dynamic secrets
3. **External Secrets Operator** — Pull from AWS/GCP secrets managers

My setup: ArgoCD + Sealed Secrets. Manifests have encrypted secrets, cluster decrypts them.

---

## What I Learned

### 1. GitOps isn't optional with Kubernetes
K8s has too many moving parts. Manual deployments are a disaster waiting to happen.

### 2. Start with one app
Don't try to migrate everything at once. Pick one app, get it working with ArgoCD, expand from there.

### 3. Sync waves are underrated
Defining deployment order (database → app → ingress) prevents race conditions.

### 4. Self-heal is powerful
If Prometheus breaks, ArgoCD fixes it. No 3am wake-up call.

---

## The Numbers

| Metric | Manual Deploys | GitOps |
|--------|----------------|--------|
| Deploy time | 5 min | 30 sec |
| Rollback time | 10 min | 30 sec |
| Visibility | `kubectl get pods` | ArgoCD dashboard |
| Audit trail | None | Full git history |
| Drift detection | None | Automatic |
| Cost | $0 | $0 |
