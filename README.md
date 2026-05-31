# MLOps Platform — End-to-End Self-Hosted

MLOps pipeline completo corriendo sobre K3s en homelab (Proxmox).
Desde experimentación hasta monitoreo de modelos en producción.

## Arquitectura

```
GitHub Actions (CI/CD/CT)
        │
        ▼
┌─── K3s Cluster (Proxmox VM) ───────────────────────────┐
│                                                          │
│  ArgoCD (GitOps) ──▶ MLflow (Tracking + Registry)       │
│                  ──▶ MinIO (S3-compatible Artifacts)     │
│                  ──▶ PostgreSQL (MLflow Backend)         │
│                  ──▶ BentoML (Model Serving API)        │
│                  ──▶ Evidently AI (Model Monitoring)    │
│                  ──▶ Prometheus + Grafana (Observability)│
└──────────────────────────────────────────────────────────┘
```

## Stack

| Capa | Herramienta |
|------|------------|
| Infraestructura | Proxmox + Terraform + cloud-init |
| Orquestación | K3s (single-node) |
| GitOps | ArgoCD |
| Experiment Tracking | MLflow |
| Object Storage | MinIO |
| Database | PostgreSQL |
| Model Serving | BentoML |
| Model Monitoring | Evidently AI |
| Observabilidad | Prometheus + Grafana |
| CI/CD/CT | GitHub Actions |
| ML Framework | XGBoost / scikit-learn |

## Requisitos

- Proxmox VE con acceso API
- GitHub account
- kubectl instalado localmente

## Quickstart

```bash
# 1. Provisionar VM y K3s
cd terraform/proxmox
terraform init && terraform apply

# 2. Instalar K3s en la VM
ssh ubuntu@<vm-ip> 'bash -s' < ../k3s/install.sh

# 3. Deploy ArgoCD y apps base
kubectl apply -f ../k3s/manifests/

# 4. Conectar ArgoCD al repo
# Una vez que ArgoCD esté corriendo, configurar el repo Git
# y crear el app-of-apps
```
