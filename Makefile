.PHONY: help init tf-plan tf-apply k3s-install argocd-sync train serve clean

help:
	@echo "MLOps Platform - Makefile"
	@echo ""
	@echo "Usage:"
	@echo "  make tf-plan       Terraform plan para la VM en Proxmox"
	@echo "  make tf-apply      Terraform apply para crear la VM"
	@echo "  make k3s-install   Instalar K3s en la VM"
	@echo "  make argocd-sync   Sincronizar apps vía ArgoCD"
	@echo "  make train         Ejecutar pipeline de entrenamiento local"
	@echo "  make serve         Levantar BentoML serving localmente"
	@echo "  make clean         Limpiar artifacts de entrenamiento"

# Terraform
tf-init:
	cd terraform/proxmox && terraform init

tf-plan: tf-init
	cd terraform/proxmox && terraform plan

tf-apply: tf-init
	cd terraform/proxmox && terraform apply -auto-approve

tf-destroy:
	cd terraform/proxmox && terraform destroy -auto-approve

# K3s
k3s-install:
	scp terraform/k3s/install.sh ubuntu@$$(cd terraform/proxmox && terraform output -raw vm_ip):/tmp/
	ssh ubuntu@$$(cd terraform/proxmox && terraform output -raw vm_ip) 'sudo bash /tmp/install.sh'

# ML Pipeline
train:
	cd ml-flow && python3 src/train.py

serve:
	cd serving && bentoml serve service:svc --reload

# Clean
clean:
	rm -rf mlruns/
	rm -rf ml-flow/src/data/processed/
	find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
