#!/bin/bash
set -euo pipefail

echo "=== Installing K3s on mlops-k3s ==="

export INSTALL_K3S_EXEC="--disable=traefik \
  --disable=servicelb \
  --disable=local-storage \
  --node-name=mlops-node \
  --write-kubeconfig-mode=644"

curl -sfL https://get.k3s.io | sh -

echo "Waiting for K3s to be ready..."
sleep 10

until kubectl get nodes &>/dev/null; do
  echo "Waiting for kubeconfig..."
  sleep 5
done

kubectl wait --for=condition=Ready node/mlops-node --timeout=120s

echo ""
echo "=== K3s installed successfully ==="
kubectl get nodes
echo ""

echo "=== Installing Helm ==="
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

echo ""
echo "=== Setting up kubeconfig for local use ==="
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
sed -i '' 's/127.0.0.1/'"$(hostname -I | awk '{print $1}')"'/g' ~/.kube/config 2>/dev/null || \
  sed -i 's/127.0.0.1/'"$(hostname -I | awk '{print $1}')"'/g' ~/.kube/config

echo ""
echo "=== Installing NGINX Ingress Controller ==="
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.0/deploy/static/provider/baremetal/deploy.yaml

echo ""
echo "=== Installing cert-manager ==="
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.16.0/cert-manager.yaml

echo ""
echo "=== Waiting for cert-manager to be ready ==="
kubectl wait --for=condition=Available deployment/cert-manager -n cert-manager --timeout=120s
kubectl wait --for=condition=Available deployment/cert-manager-webhook -n cert-manager --timeout=120s

echo ""
echo "=== Installing ArgoCD ==="
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo ""
echo "=== Waiting for ArgoCD to be ready ==="
kubectl wait --for=condition=Available deployment/argocd-server -n argocd --timeout=180s

ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo ""
echo "============================================"
echo " K3s cluster ready!"
echo " ArgoCD admin password: $ARGOCD_PASSWORD"
echo " ArgoCD URL: https://$(hostname -I | awk '{print $1}'):$(kubectl -n argocd get svc argocd-server -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}')"
echo "============================================"

echo ""
echo "=== To get kubeconfig on your local machine ==="
echo "scp ubuntu@$(hostname -I | awk '{print $1}'):~/.kube/config ~/.kube/mlops-config"
echo "export KUBECONFIG=~/.kube/mlops-config"
