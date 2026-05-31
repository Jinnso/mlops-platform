# MLOps Platform — Architecture Diagram

```mermaid
graph TB
    subgraph EXTERNAL["External"]
        USER["👤 User / API Consumer"]
        DEV["💻 Developer"]
        GH["🐙 GitHub<br/>Source + Actions"]
    end

    subgraph PROXMOX["Proxmox VE — Intel N150"]
        subgraph VM["VM: mlops-k3s — 12GB RAM / 4vCPU / 100GB"]
            
            subgraph K3S["K3s Single-Node Cluster"]
                
                subgraph INGRESS["Ingress Layer"]
                    NGINX["NGINX Ingress<br/>Controller"]
                    CM["cert-manager"]
                end

                subgraph GITOPS["GitOps Layer"]
                    ARGOCD["ArgoCD<br/>App-of-Apps"]
                end

                subgraph ML["ML Platform — namespace: mlops"]
                    MLFLOW["MLflow<br/>Tracking + Registry"]
                    BENTOML["BentoML<br/>Model Serving"]
                    EVIDENTLY["Evidently AI<br/>Drift CronJob"]
                end

                subgraph STORAGE["Storage — namespace: storage"]
                    MINIO["MinIO<br/>S3-compatible"]
                    POSTGRES["PostgreSQL<br/>(optional)"]
                end

                subgraph OBS["Observability — namespace: monitoring"]
                    PROM["Prometheus"]
                    GRAFANA["Grafana<br/>Dashboards"]
                end
            end
        end
    end

    subgraph GHA["GitHub Actions Pipelines"]
        CI["CI<br/>train.py"]
        CD["CD<br/>build + push"]
        CT["CT<br/>continuous training"]
        EV["Monitor<br/>evidently"]
    end

    %% Connections
    DEV -->|"git push"| GH
    GH -->|"GitOps sync"| ARGOCD
    CI -->|"log metrics"| MLFLOW
    CI -->|"store artifacts"| MINIO
    CD -->|"push image"| GH
    GH -->|"deploy manifests"| ARGOCD
    ARGOCD -->|"sync"| BENTOML
    ARGOCD -->|"sync"| MLFLOW
    ARGOCD -->|"sync"| MINIO
    ARGOCD -->|"sync"| EVIDENTLY
    ARGOCD -->|"sync"| PROM
    ARGOCD -->|"sync"| GRAFANA
    
    USER -->|"REST API"| NGINX
    NGINX --> BENTOML
    BENTOML -->|"load model"| MLFLOW
    BENTOML -->|"load artifacts"| MINIO
    MLFLOW -->|"metadata"| POSTGRES
    MLFLOW -->|"artifacts"| MINIO
    EVIDENTLY -->|"report"| GRAFANA
    PROM -->|"scrape metrics"| BENTOML
    PROM -->|"scrape metrics"| MLFLOW
    PROM -->|"scrape metrics"| MINIO
    GRAFANA -->|"query"| PROM
    
    style EXTERNAL fill:#1a1a2e,stroke:#16213e,color:#eee
    style PROXMOX fill:#0f3460,stroke:#16213e,color:#eee
    style VM fill:#16213e,stroke:#533483,color:#eee
    style K3S fill:#1a1a2e,stroke:#533483,color:#eee
    style INGRESS fill:#16213e,stroke:#e94560,color:#eee
    style GITOPS fill:#16213e,stroke:#e94560,color:#eee
    style ML fill:#16213e,stroke:#0f3460,color:#eee
    style STORAGE fill:#16213e,stroke:#0f3460,color:#eee
    style OBS fill:#16213e,stroke:#0f3460,color:#eee
    style GHA fill:#1a1a2e,stroke:#e94560,color:#eee
```

## Key Components

| Component | Tool | Purpose |
|-----------|------|---------|
| **Provisioning** | Terraform + Proxmox | VM creation, cloud-init, reproducible infra |
| **Orchestration** | K3s | Lightweight Kubernetes cluster |
| **GitOps** | ArgoCD | Declarative sync from GitHub, auto-heal |
| **Tracking** | MLflow | Experiment tracking, parameter logging, metrics |
| **Registry** | MLflow Model Registry | Model versioning, stage transitions |
| **Storage** | MinIO | S3-compatible object store for artifacts |
| **Serving** | BentoML | Production inference API with HPA |
| **Monitoring** | Evidently AI | Data drift detection, data quality reports |
| **Observability** | Prometheus + Grafana | Metrics, dashboards, alerting |
| **CI/CD/CT** | GitHub Actions | Train, build, deploy, continuous training |
| **Database** | PostgreSQL | MLflow metadata store (optional) |
| **Ingress** | NGINX + cert-manager | HTTP routing, TLS certificates |

## Data Flow

```
1. Developer pushes code → GitHub
2. GitHub Actions triggers CI pipeline → trains model → logs to MLflow
3. MLflow stores artifacts in MinIO, metadata in PostgreSQL
4. ArgoCD detects manifest changes → syncs cluster state
5. BentoML loads model from MLflow → serves predictions
6. User calls REST API → NGINX routes to BentoML
7. Prometheus scrapes metrics from all services
8. Grafana displays dashboards with real-time metrics
9. Evidently CronJob runs daily → checks for data drift
10. Continuous Training pipeline retrains if drift detected
```
