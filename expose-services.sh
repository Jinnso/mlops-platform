#!/usr/bin/env bash
# ============================================================================
# MLOps Platform — Port Forward Keepalive
# ============================================================================
# Usage:
#   ./expose-services.sh          Start all tunnels (foreground keepalive)
#   ./expose-services.sh --once   Start once without monitoring
#   ./expose-services.sh --stop   Kill all port-forwards
# ============================================================================

KUBECONFIG="${KUBECONFIG:-$HOME/.kube/mlops-config}"

PORTS=(
    "8080:argocd:argocd-server:80"
    "5001:mlops:mlflow:5000"
    "9001:storage:minio:9001"
    "3001:monitoring:grafana:3000"
    "9090:monitoring:prometheus:9090"
    "3000:mlops:taxi-fare-serving:3000"
)

start_pf() {
    local local_port=$1 ns=$2 svc=$3 target_port=$4
    kubectl port-forward svc/"$svc" -n "$ns" "$local_port":"$target_port" --address 0.0.0.0 &>/dev/null &
    echo $!
}

do_stop() {
    echo "Stopping all port-forwards..."
    for entry in "${PORTS[@]}"; do
        IFS=":" read -r port _ _ _ <<< "$entry"
        lsof -ti :"$port" 2>/dev/null | xargs kill 2>/dev/null || true
    done
    echo "Done."
}

do_once() {
    for entry in "${PORTS[@]}"; do
        IFS=":" read -r port ns svc target <<< "$entry"
        pids=$(lsof -ti :"$port" 2>/dev/null) || true
        if [ -n "$pids" ]; then
            echo "  :$port already in use, skipping"
        else
            start_pf "$port" "$ns" "$svc" "$target"
            disown
            echo "  :$port → $svc.$ns:$target"
        fi
    done
}

banner() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  MLOps Platform — Local Access"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  ArgoCD     → http://localhost:8080"
    echo "  MLflow     → http://localhost:5001"
    echo "  MinIO      → http://localhost:9001"
    echo "  Grafana    → http://localhost:3001"
    echo "  Prometheus → http://localhost:9090"
    echo "  BentoML    → http://localhost:3000"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

case "${1:-}" in
    --stop)
        do_stop
        exit 0
        ;;
    --once)
        do_once
        banner
        exit 0
        ;;
    *)
        do_once
        banner
        echo ""
        echo "Keepalive running (checking every 10s). Ctrl+C to stop."
        while true; do
            for entry in "${PORTS[@]}"; do
                IFS=":" read -r port ns svc target <<< "$entry"
                pids=$(lsof -ti :"$port" 2>/dev/null) || true
                if [ -z "$pids" ]; then
                    echo "[$(date +%H:%M:%S)] Restarting :$port → $svc.$ns:$target"
                    start_pf "$port" "$ns" "$svc" "$target"
                    disown
                fi
            done
            sleep 10
        done
        ;;
esac
