# MLOps Platform — End-to-End Self-Hosted

[![ArgoCD](https://img.shields.io/badge/ArgoCD-Ready-blue?logo=argo)](https://argoproj.github.io/cd/)
[![K3s](https://img.shields.io/badge/K3s-v1.35-yellow?logo=kubernetes)](https://k3s.io/)
[![MLflow](https://img.shields.io/badge/MLflow-2.19-blue?logo=mlflow)](https://mlflow.org/)
[![BentoML](https://img.shields.io/badge/BentoML-1.4-orange?logo=bentoml)](https://bentoml.com/)
[![GitHub Actions](https://img.shields.io/badge/CI/CD-GitHub_Actions-2088FF?logo=github)](https://github.com/Jinnso/mlops-platform/actions)

**A production-ready MLOps pipeline running entirely on a self-hosted homelab — zero cloud costs.**

From model experimentation to production serving with automated monitoring, drift detection, and GitOps-driven deployments. Built on an Intel N150 mini-PC (16GB RAM) using Proxmox + K3s.

---

## Architecture

```
┌──────────────────────────────────────────────────────────────────────────┐
│                          Proxmox VE (Intel N150)                          │
│                                                                          │
│  ┌─── VM: mlops-k3s (12GB RAM, 4vCPU, 100GB) ────────────────────────┐  │
│  │                                                                     │  │
│  │  ┌───────────┐   ┌───────────┐   ┌───────────┐   ┌──────────────┐ │  │
│  │  │  ArgoCD   │   │  MLflow   │   │  BentoML  │   │  Prometheus  │ │  │
│  │  │  (GitOps) │   │  (Track)  │   │  (Serve)  │   │  + Grafana   │ │  │
│  │  └─────┬─────┘   └─────┬─────┘   └─────┬─────┘   └──────┬───────┘ │  │
│  │        │               │               │                │         │  │
│  │        │       ┌───────┴───────┐       │                │         │  │
│  │        │       │  PostgreSQL   │       │                │         │  │
│  │        │       └───────────────┘       │                │         │  │
│  │        │       ┌───────────────┐       │                │         │  │
│  │        │       │    MinIO      │◄──────┘                │         │  │
│  │        │       │  (S3 Store)   │                        │         │  │
│  │        │       └───────────────┘                        │         │  │
│  │        │                                                │         │  │
│  │        │       ┌───────────────┐                        │         │  │
│  │        │       │  Evidently AI │                        │         │  │
│  │        │       │   (CronJob)   │                        │         │  │
│  │        │       └───────────────┘                        │         │  │
│  └────────┼────────────────────────────────────────────────┼─────────┘  │
│           │                                                │            │
└───────────┼────────────────────────────────────────────────┼────────────┘
            │                                                │
      ┌─────▼──────────────────────────┐              ┌──────▼──────────┐
      │      GitHub Actions             │              │  GitHub Repo    │
      │  ┌────┐  ┌───────┐  ┌────────┐ │              │  (Source +      │
      │  │ CI │  │  CD   │  │  CT    │ │              │   Manifests)    │
      │  └────┘  └───────┘  └────────┘ │              └─────────────────┘
      └────────────────────────────────┘
```

## Tech Stack

| Layer | Tool | Purpose |
|-------|------|---------|
| **Infrastructure as Code** | Terraform + Proxmox | VM provisioning, cloud-init |
| **Container Orchestration** | K3s (single-node) | Lightweight Kubernetes |
| **GitOps** | ArgoCD | Declarative app sync from GitHub |
| **Experiment Tracking** | MLflow | Parameters, metrics, artifacts |
| **Model Registry** | MLflow Model Registry | Version control for models |
| **Object Storage** | MinIO | S3-compatible artifact store |
| **Database** | PostgreSQL | Relational storage (optional) |
| **ML Framework** | XGBoost | Gradient-boosted regression |
| **Model Serving** | BentoML | Production inference API |
| **Data Monitoring** | Evidently AI | Data drift, quality reports |
| **Observability** | Prometheus + Grafana | Metrics, dashboards, alerting |
| **CI/CD/CT** | GitHub Actions | Training, build, deploy, retrain |
| **Ingress** | NGINX Ingress Controller | HTTP routing |
| **TLS** | cert-manager | Certificate management |

## Project Structure

```
mlops-platform/
├── terraform/                    # Infrastructure as Code
│   ├── proxmox/                  # Proxmox VM + cloud-init
│   │   ├── main.tf               # Provider config
│   │   ├── variables.tf          # Input variables
│   │   ├── vm.tf                 # VM resource definition
│   │   └── cloud-init.yaml.tftpl # Cloud-init bootstrap template
│   └── k3s/
│       └── install.sh            # K3s + Helm + ArgoCD installer
├── k8s/                          # Kubernetes manifests
│   ├── argocd/                   # ArgoCD app-of-apps
│   ├── base/                     # MinIO, PostgreSQL, MLflow, Ingress
│   ├── bentoml/                  # BentoML serving deployment + HPA
│   └── namespaces/               # Namespace definitions
├── ml-flow/                      # ML training pipeline
│   ├── src/
│   │   ├── train.py              # XGBoost training + MLflow logging
│   │   ├── evaluate.py           # Model evaluation with thresholds
│   │   ├── promote_model.py      # CI/CD model promotion logic
│   │   ├── feature_engineering.py# Scikit-learn preprocessing pipeline
│   │   └── data/download_data.py # Synthetic dataset generator
│   └── tests/                    # Pipeline unit tests
├── serving/                      # BentoML model serving
│   ├── service.py                # Inference API (class-based BentoML 1.4)
│   ├── bentofile.yaml            # Bento build configuration
│   └── preprocessor/             # Bundled sklearn preprocessor
├── monitoring/                   # Observability stack
│   ├── evidently/
│   │   ├── monitor.py            # Drift detection script
│   │   └── cronjob.yaml          # Kubernetes CronJob (daily at 2am)
│   └── grafana/
│       ├── deployment.yaml       # Prometheus + Grafana deployment
│       └── dashboards.yaml       # Pre-built dashboards
├── .github/workflows/            # CI/CD pipelines
│   ├── train.yml                 # Model training pipeline
│   ├── build-deploy.yml          # Docker build + push + ArgoCD sync
│   ├── continuous-training.yml   # Automated weekly retraining
│   └── evidently.yml             # Scheduled drift monitoring
├── Makefile                      # Development shortcuts
└── README.md
```

## Key Features

### 1. Infrastructure as Code (Terraform + Proxmox)
- Single `terraform apply` provisions the entire VM with cloud-init
- Static IP, SSH key injection, kernel tuning for Kubernetes
- Fully reproducible — destroy and recreate in minutes

### 2. GitOps with ArgoCD
- 6 ArgoCD applications managed via `app-of-apps` pattern
- Auto-sync with `selfHeal` and `autoPrune` enabled
- Every change to `k8s/` in the repo triggers automatic reconciliation

### 3. ML Experiment Tracking (MLflow)
- Self-hosted MLflow server with SQLite backend + MinIO artifact store
- Automatic experiment creation and run tracking
- Model registry with staged transitions (Staging → Production)
- All parameters, metrics, and artifacts logged automatically

```bash
# Training run produces:
🏃 View run at: http://mlflow.local/#/experiments/1/runs/<run-id>
📊 Metrics: RMSE=1.48, MAE=1.19, R²=0.53
```

### 4. Model Serving (BentoML)
- Class-based BentoML 1.4 service with type-safe Pydantic models
- Preprocessor (sklearn ColumnTransformer + OneHotEncoder) bundled in the bento
- REST API with structured input/output validation
- Kubernetes Deployment with HPA (1-3 replicas, CPU-based scaling)

```json
POST /predict
{
  "trip": {
    "passenger_count": 2,
    "trip_distance": 3.5,
    "pickup_hour": 14,
    "PULocationID": 100,
    "DOLocationID": 200,
    "rate_code": 1
  }
}
→ { "predicted_duration_min": 4.91 }
```

### 5. Model Monitoring (Evidently AI)
- Daily Kubernetes CronJob runs drift detection
- Generates HTML report + JSON summary
- Detects data drift, data quality issues, and feature distribution changes
- Triggers alerts if drift exceeds threshold

### 6. Observability (Prometheus + Grafana)
- Pre-built dashboards: MLOps Overview, Model Health & Drift
- Metrics: prediction rate, latency (p99), error rate, model count
- Kubernetes pod auto-discovery via annotations

### 7. CI/CD/CT Pipeline (GitHub Actions)

| Workflow | Trigger | Description |
|----------|---------|-------------|
| `train.yml` | Manual | Full training → evaluate → promote pipeline |
| `build-deploy.yml` | Manual | Docker build → GHCR push → ArgoCD sync |
| `continuous-training.yml` | Manual | Retrain → compare → auto-promote if better |
| `evidently.yml` | Manual | Run drift detection → upload report artifact |

## Quick Start

### Prerequisites
- Proxmox VE node with API access
- SSH access to Proxmox host (root)
- GitHub account

### 1. Provision Infrastructure

```bash
# Copy and edit variables
cp terraform/proxmox/terraform.tfvars.example terraform/proxmox/terraform.tfvars
# Edit with your Proxmox URL, API token, SSH key path, etc.

# Enable Snippets on Proxmox local storage (Datacenter → Storage → local → Edit → Snippets)

# Create VM
cd terraform/proxmox
terraform init
terraform apply
```

### 2. Install K3s

```bash
# SSH into the new VM and install K3s
scp terraform/k3s/install.sh ubuntu@<VM_IP>:/tmp/
ssh ubuntu@<VM_IP> "sudo bash /tmp/install.sh"

# Get kubeconfig
ssh ubuntu@<VM_IP> "sudo cat /etc/rancher/k3s/k3s.yaml" | \
  sed 's/127.0.0.1/<VM_IP>/g' > ~/.kube/mlops-config
export KUBECONFIG=~/.kube/mlops-config
```

### 3. Deploy Applications

```bash
# Deploy core services
kubectl apply -f k8s/namespaces/
kubectl apply -f k8s/base/

# Wait for services to be ready
kubectl wait --for=condition=Available deployment/minio -n storage --timeout=120s
kubectl wait --for=condition=Available deployment/postgres -n storage --timeout=120s
kubectl wait --for=condition=Available deployment/mlflow -n mlops --timeout=120s

# Create MinIO buckets
kubectl -n storage exec -i deploy/minio -- sh -c \
  "mc alias set local http://localhost:9000 minioadmin minioadmin123 && \
   mc mb local/mlflow-artifacts && mc mb local/datasets && mc mb local/models"

# Connect ArgoCD to your fork
argocd login localhost:8080 --username admin --password <argocd-password> --insecure
argocd repo add https://github.com/<your-username>/mlops-platform
argocd app create root-app \
  --repo https://github.com/<your-username>/mlops-platform \
  --path k8s/argocd/apps \
  --dest-server https://kubernetes.default.svc \
  --sync-policy auto
```

### 4. Run Training Pipeline

```bash
# Install dependencies
pip install -r ml-flow/requirements.txt

# Port-forward MLflow and MinIO
kubectl port-forward svc/mlflow -n mlops 5000:5000 &
kubectl port-forward svc/minio -n storage 9000:9000 &

# Run training
export MLFLOW_TRACKING_URI=http://localhost:5000
export MLFLOW_S3_ENDPOINT_URL=http://localhost:9000
export AWS_ACCESS_KEY_ID=minioadmin
export AWS_SECRET_ACCESS_KEY=minioadmin123
python ml-flow/src/train.py
```

### 5. Deploy Model Serving

```bash
# Import model into BentoML
python -c "
import mlflow, bentoml
mlflow.set_tracking_uri('http://localhost:5000')
model = mlflow.xgboost.load_model('models:/taxi_fare_predictor/Staging')
bentoml.xgboost.save_model('taxi_fare_predictor', model)
"

# Build and containerize
cd serving
bentoml build
bentoml containerize taxi_fare_predictor:latest --platform linux/amd64

# Transfer to K3s node and deploy
docker save taxi_fare_predictor:latest -o /tmp/taxi.tar
scp /tmp/taxi.tar ubuntu@<VM_IP>:/tmp/
ssh ubuntu@<VM_IP> "sudo ctr -n k8s.io image import /tmp/taxi.tar"
kubectl apply -f k8s/bentoml/serving.yaml
```

### 6. Test Inference

```bash
kubectl port-forward svc/taxi-fare-serving -n mlops 3000:3000 &

curl -X POST http://localhost:3000/predict \
  -H "Content-Type: application/json" \
  -d '{
    "trip": {
      "passenger_count": 2,
      "trip_distance": 3.5,
      "pickup_hour": 14,
      "pickup_day": 3,
      "pickup_month": 6,
      "PULocationID": 100,
      "DOLocationID": 200,
      "rate_code": 1
    }
  }'
# → {"predicted_duration_min": 4.91, "features": {...}}
```

## ML Pipeline Details

### Dataset
Synthetic NYC taxi trip data (50,000 samples) with 8 features:
- `passenger_count`, `trip_distance`, `pickup_hour`, `pickup_day`, `pickup_month`
- `PULocationID`, `DOLocationID`, `rate_code`
- Target: `trip_duration_min` (minutes)

### Feature Engineering
- **Numeric features**: StandardScaler normalization
- **Categorical features**: OneHotEncoder (max 50 categories)
- Output: 111-dimensional feature vector
- Preprocessor serialized with `joblib` and bundled with the BentoML service

### Model
- **Algorithm**: XGBoost Regressor
- **Hyperparameters**: 200 estimators, max_depth=6, learning_rate=0.1
- **Performance**: RMSE=1.48, MAE=1.19, R²=0.53

### Model Registry Flow
```
Training → Evaluate → Register in MLflow → Stage: "None"
                                              ↓
                                         Promote to "Staging"
                                              ↓
                                    (manual or auto-promotion)
                                              ↓
                                        Promote to "Production"
                                              ↓
                                    BentoML picks up latest
```

## GitHub Actions Secrets

The following secrets are configured for CI/CD:

| Secret | Purpose |
|--------|---------|
| `MLFLOW_TRACKING_URI` | MLflow server URL |
| `MLFLOW_S3_ENDPOINT_URL` | MinIO S3 endpoint |
| `MINIO_ACCESS_KEY` | MinIO access key |
| `MINIO_SECRET_KEY` | MinIO secret key |
| `ARGOCD_SERVER` | ArgoCD API server address |
| `ARGOCD_TOKEN` | ArgoCD API token |

## Skills Demonstrated

| Category | Skills |
|----------|--------|
| **DevOps** | Terraform, K3s, Docker, Linux administration, Proxmox, cloud-init |
| **GitOps** | ArgoCD, app-of-apps, auto-sync, self-healing |
| **MLOps** | MLflow, experiment tracking, model registry, staged transitions |
| **Model Serving** | BentoML, REST API design, Pydantic validation, containerization |
| **CI/CD** | GitHub Actions, multi-stage pipelines, Docker build & push |
| **Observability** | Prometheus, Grafana, metrics collection, dashboard design |
| **Data Monitoring** | Evidently AI, drift detection, data quality, scheduled reporting |
| **ML Engineering** | XGBoost, scikit-learn, feature engineering, model evaluation |
| **Kubernetes** | Deployments, Services, CronJobs, HPA, PV/PVC, ConfigMaps, Secrets |
| **Platform Engineering** | Self-service infrastructure, internal developer platform patterns |
| **Security** | Secrets management, IAM patterns, least-privilege |

## License

MIT

---

**Built by [Nicolás Jarpa](https://github.com/Jinnso)** — DevOps & MLOps Engineer
