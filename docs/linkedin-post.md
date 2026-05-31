# LinkedIn Post — MLOps Platform

## Main Post

🚀 Built an end-to-end MLOps platform from scratch — running 100% on a self-hosted homelab. Zero cloud costs. Real Kubernetes. Automated pipelines.

After weeks of design, coding, and debugging, I'm sharing my most complete DevOps/MLOps project to date. Here's the full breakdown:

━━━━━━━━━━━━━━━━━━━━━━━━━━━

🎯 THE GOAL

Build a production-grade MLOps platform that covers the full machine learning lifecycle — from experimentation to production monitoring — without depending on any cloud provider. Everything runs on a single Intel N150 mini-PC (16GB RAM) using Proxmox virtualization.

No AWS SageMaker. No Databricks. No managed services. Just infrastructure as code, Kubernetes, and open-source tools.

━━━━━━━━━━━━━━━━━━━━━━━━━━━

🏗️ ARCHITECTURE

Layer 1 — Infrastructure as Code
• Terraform provisions a K3s VM on Proxmox with cloud-init
• Static IP, SSH key injection, kernel tuning for Kubernetes
• Single `terraform apply` → fully reproducible environment
• The entire stack can be destroyed and recreated in minutes

Layer 2 — GitOps with ArgoCD
• 6 ArgoCD applications managed via app-of-apps pattern
• Auto-sync with self-healing and auto-pruning enabled
• Every change to k8s/ in the repo triggers automatic reconciliation
• Connected directly to GitHub — the repo IS the source of truth

Layer 3 — ML Platform
• MLflow: experiment tracking, parameter logging, metrics (RMSE, MAE, R²), model registry with stage transitions (Staging → Production)
• MinIO: S3-compatible object storage for artifacts, datasets, and models
• PostgreSQL: relational backend for MLflow metadata
• XGBoost pipeline: feature engineering (StandardScaler + OneHotEncoder), training, evaluation, automatic model registration

Layer 4 — Model Serving
• BentoML 1.4: class-based service with Pydantic input validation
• Preprocessor (sklearn pipeline) bundled inside the serving container
• REST API with structured endpoints: /predict, /healthcheck
• Kubernetes deployment with HPA (1-3 replicas, CPU-based auto-scaling)
• TCP health probes for reliability

Layer 5 — Observability & Monitoring
• Prometheus: metrics collection with Kubernetes pod auto-discovery
• Grafana: 2 pre-built dashboards (MLOps Platform Overview, Model Health & Drift)
• Evidently AI: daily CronJob for data drift detection, generates HTML reports and JSON summaries
• All metrics scraped from application pods via annotations

Layer 6 — CI/CD/CT Pipeline (GitHub Actions)
• train.yml: full training → evaluation → model promotion pipeline
• build-deploy.yml: Docker build + GHCR push + ArgoCD sync trigger
• continuous-training.yml: automated weekly retraining with model comparison
• evidently.yml: scheduled drift monitoring with artifact uploads
• 6 GitHub Secrets configured (MLflow URI, MinIO keys, ArgoCD token, etc.)

━━━━━━━━━━━━━━━━━━━━━━━━━━━

📊 RESULTS

Model Performance:
• Algorithm: XGBoost Regressor (200 estimators, max_depth=6)
• RMSE: 1.48 minutes | MAE: 1.19 minutes | R²: 0.53
• 111-dimensional feature vector from 8 raw features
• 50,000 synthetic NYC taxi trip samples

Infrastructure:
• 17 Kubernetes pods running across 6 namespaces
• 100% uptime over 15+ hours of development
• Memory usage well within 12GB budget

Automation:
• 33 automated smoke test checks (30 pass, 3 manual)
• GitOps sync latency: < 30 seconds
• Model serving latency: < 10ms per prediction

━━━━━━━━━━━━━━━━━━━━━━━━━━━

🛠️ TECH STACK

Infrastructure: Terraform · Proxmox · K3s · Linux · cloud-init
GitOps: ArgoCD · app-of-apps · auto-sync · self-healing
ML Platform: MLflow · MinIO · PostgreSQL · XGBoost · scikit-learn
Serving: BentoML · Pydantic · Docker · Kubernetes HPA
Observability: Prometheus · Grafana · Evidently AI
CI/CD: GitHub Actions · GHCR · workflow_dispatch
Security: Kubernetes Secrets · .gitignore · env vars over hardcoded values

━━━━━━━━━━━━━━━━━━━━━━━━━━━

💡 KEY LEARNINGS

1. Self-hosted MLOps IS viable. You don't need cloud credits to build a real platform. A $200 mini-PC can run the entire stack.

2. GitOps changes everything. Once ArgoCD is configured, you never run `kubectl apply` manually again. The repo is the control plane.

3. BentoML + MLflow is a powerful combo. The model registry feeds the serving layer seamlessly. Promotion from Staging to Production triggers automatic redeployment.

4. Observability must be built-in, not bolted on. Prometheus annotations on pods, pre-configured Grafana dashboards, and scheduled drift detection make the platform production-ready from day one.

5. Infrastructure as Code is non-negotiable. The ability to `terraform destroy && terraform apply` and be back online in minutes is the difference between a demo and a real platform.

━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔗 REPOSITORY

Everything is open source and documented in English:
→ github.com/Jinnso/mlops-platform

Includes:
• Full Terraform IaC for Proxmox
• Kubernetes manifests (ArgoCD, deployments, services, CronJobs)
• Python training pipeline with MLflow integration
• BentoML serving code with Pydantic validation
• Evidently AI drift monitoring
• Prometheus + Grafana dashboards
• 4 GitHub Actions workflows
• End-to-end smoke test script (33 checks)
• Architecture diagram (Mermaid)
• Comprehensive README with deployment guide

━━━━━━━━━━━━━━━━━━━━━━━━━━━

🎓 SKILLS DEMONSTRATED

DevOps: Terraform, K3s, Docker, Linux, Proxmox, cloud-init
GitOps: ArgoCD, declarative sync, app-of-apps
MLOps: MLflow tracking, model registry, stage transitions
Platform Engineering: internal developer platform patterns
Kubernetes: Deployments, Services, CronJobs, HPA, PV/PVC, ConfigMaps, Secrets
CI/CD: GitHub Actions, multi-stage pipelines, containerization
Observability: Prometheus, Grafana, metrics, dashboards
Data Monitoring: Evidently AI, drift detection, data quality
ML Engineering: XGBoost, scikit-learn, feature engineering, model evaluation
Security: Secrets management, least-privilege, credential isolation

━━━━━━━━━━━━━━━━━━━━━━━━━━━

I'm actively looking for opportunities in DevOps, MLOps, and Platform Engineering. If you're hiring or know someone who is, I'd love to connect.

Feedback, questions, and code reviews are more than welcome. What would you add or improve?

#MLOps #DevOps #Kubernetes #Terraform #ArgoCD #MLflow #BentoML #PlatformEngineering #GitOps #Homelab #Prometheus #Grafana #MachineLearning #Docker #GitHubActions #OpenSource #InfrastructureAsCode #DataScience

---

## Comment Thread (post this as your own comment right after publishing)

For those interested in the technical details:

→ Infrastructure: 1 Proxmox VM (12GB RAM, 4vCPU, 100GB SSD) running K3s single-node. Provisioned entirely via Terraform + cloud-init. The VM IP, SSH key, and gateway are parameterized — no hardcoded values.

→ CI/CD: All 4 GitHub Actions workflows use `workflow_dispatch` (manual trigger). The cluster isn't exposed to the internet, so training and monitoring run locally while image builds happen in CI. Secrets are managed via GitHub Secrets, never committed.

→ Model lifecycle: train.py → logs to MLflow → registers model → promotes to Staging → evaluate.py validates metrics → continuous-training.yml compares Staging vs Production → auto-promotes if RMSE improves by > 5%.

→ Security: All credentials are passed via environment variables or Kubernetes Secrets. Default values in source code are empty strings. The .gitignore excludes terraform.tfvars, .env files, and state files. No tokens, passwords, or IPs are exposed in the public repository.

→ Smoke test: `./test-e2e.sh` runs 33 automated checks across 5 layers — infrastructure, core services, ML pipeline, serving API, and observability. It validates SSH, kubectl, deployments, ArgoCD sync status, MLflow health, MinIO buckets, BentoML predictions, Prometheus readiness, Grafana HTTP, and Evidently CronJob configuration.

Happy to answer any questions about specific components!
