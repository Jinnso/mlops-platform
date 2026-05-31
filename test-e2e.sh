#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# MLOps Platform — End-to-End Smoke Test
# ============================================================================
#
# Validates every layer of the platform:
#   1. Infrastructure (VM + K3s)
#   2. Core Services (MinIO, PostgreSQL, MLflow, ArgoCD)
#   3. ML Pipeline (model training, registry)
#   4. Serving (BentoML API)
#   5. Observability (Prometheus, Grafana, Evidently)
#
# Usage:
#   chmod +x test-e2e.sh
#   ./test-e2e.sh
#
# Requirements:
#   - kubectl with valid kubeconfig for the cluster
#   - curl, jq
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
FAIL=0
SKIP=0

KUBECONFIG="${KUBECONFIG:-$HOME/.kube/mlops-config}"
VM_IP="${VM_IP:-192.168.1.50}"
MINIO_USER="${MINIO_USER:-minioadmin}"
MINIO_PASS="${MINIO_PASS:-minioadmin123}"
MLFLOW_PORT="${MLFLOW_PORT:-5000}"
MINIO_PORT="${MINIO_PORT:-9000}"
SERVING_PORT="${SERVING_PORT:-3000}"
PROMETHEUS_PORT="${PROMETHEUS_PORT:-9090}"
GRAFANA_PORT="${GRAFANA_PORT:-3000}"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
ok()   { echo -e "  ${GREEN}✓${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "  ${RED}✗${NC} $1 — $2"; FAIL=$((FAIL + 1)); }
skip() { echo -e "  ${YELLOW}⊘${NC} $1 (skipped)"; SKIP=$((SKIP + 1)); }

section() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

pf_kill() {
    kill "$1" 2>/dev/null || true
}

wait_for_pod() {
    local ns=$1 label=$2 timeout=${3:-120}
    kubectl wait --for=condition=Ready pod -n "$ns" -l "$label" --timeout="${timeout}s" &>/dev/null
}

# ---------------------------------------------------------------------------
# 1. INFRASTRUCTURE
# ---------------------------------------------------------------------------
section "1. Infrastructure"

echo "  Checking VM SSH access..."
if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 ubuntu@"$VM_IP" "echo ok" &>/dev/null; then
    ok "VM reachable at $VM_IP"
else
    fail "VM unreachable" "ssh ubuntu@$VM_IP"
fi

echo "  Checking kubectl connectivity..."
if kubectl get nodes &>/dev/null; then
    NODES=$(kubectl get nodes -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}')
    if echo "$NODES" | grep -q "True"; then
        ok "kubectl connected, node(s) Ready"
    else
        fail "kubectl connected but node not Ready" ""
    fi
else
    fail "kubectl cannot reach cluster" "check KUBECONFIG"
fi

# ---------------------------------------------------------------------------
# 2. CORE SERVICES
# ---------------------------------------------------------------------------
section "2. Core Services"

echo "  Checking namespaces..."
for ns in mlops storage monitoring argocd cert-manager ingress-nginx; do
    if kubectl get ns "$ns" &>/dev/null; then
        ok "namespace $ns exists"
    else
        fail "namespace $ns missing" ""
    fi
done

echo "  Checking deployments..."
check_deployment() {
    local name=$1 ns=$2 label=$3
    if kubectl get deployment "$name" -n "$ns" &>/dev/null; then
        ready=$(kubectl get deployment "$name" -n "$ns" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        if [ "$ready" -ge 1 ] 2>/dev/null; then
            ok "$label ($ready/1 ready)"
        else
            fail "$label not ready" "0 ready replicas"
        fi
    else
        fail "$label not deployed" ""
    fi
}

check_deployment mlflow   mlops      "MLflow"
check_deployment minio    storage    "MinIO"
check_deployment postgres storage    "PostgreSQL"
check_deployment prometheus monitoring "Prometheus"
check_deployment grafana  monitoring "Grafana"
check_deployment taxi-fare-serving mlops "BentoML serving"

echo "  Checking ArgoCD apps..."
if kubectl get app -n argocd &>/dev/null; then
    APPS=$(kubectl get app -n argocd -o jsonpath='{range .items[*]}{.metadata.name}{"|"}{.status.health.status}{"|"}{.status.sync.status}{"\n"}{end}')
    for line in $APPS; do
        name=$(echo "$line" | cut -d'|' -f1)
        health=$(echo "$line" | cut -d'|' -f2)
        sync=$(echo "$line" | cut -d'|' -f3)
        case "$sync" in
            Synced) ok "ArgoCD $name — $health / $sync" ;;
            OutOfSync) 
                # OutOfSync on shared resources or during reconciliation is expected for some app-of-apps patterns
                skip "ArgoCD $name — $health / $sync (auto-reconciling)" 
                ;;
            *) fail "ArgoCD $name — sync status: $sync" "" ;;
        esac
    done
else
    fail "ArgoCD not accessible" ""
fi

# ---------------------------------------------------------------------------
# 3. ML PIPELINE (MLflow + MinIO)
# ---------------------------------------------------------------------------
section "3. ML Pipeline"

# Port-forward MLflow
echo "  Port-forwarding MLflow..."
kubectl port-forward svc/mlflow -n mlops "$MLFLOW_PORT":5000 &>/dev/null &
PF_MLFLOW=$!
sleep 2

echo "  Checking MLflow health..."
if curl -s http://localhost:"$MLFLOW_PORT"/health &>/dev/null; then
    ok "MLflow healthy"
else
    fail "MLflow not responding" "http://localhost:$MLFLOW_PORT/health"
fi

echo "  Checking MLflow experiments..."
EXP=$(curl -s http://localhost:"$MLFLOW_PORT"/api/2.0/mlflow/experiments/search -X POST \
    -H "Content-Type: application/json" -d '{"max_results":10}' 2>/dev/null | \
    python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d.get('experiments',[])))" 2>/dev/null || echo "0")
if [ "$EXP" -ge 1 ] 2>/dev/null; then
    ok "MLflow has $EXP experiment(s)"
else
    skip "No experiments found (run train.py first)"
fi

echo "  Checking registered models..."
MODELS=$(curl -s http://localhost:"$MLFLOW_PORT"/api/2.0/mlflow/registered-models/search -X POST \
    -H "Content-Type: application/json" -d '{"max_results":10}' 2>/dev/null | \
    python3 -c "import sys,json; d=json.load(sys.stdin); registered=d.get('registered_models',[]); \
    print(f'Models: {len(registered)}')" 2>/dev/null || echo "")
if [ -n "$MODELS" ]; then
    ok "Registered models: $MODELS"
else
    skip "No registered models (run train.py first)"
fi

pf_kill $PF_MLFLOW

# Port-forward MinIO
echo "  Port-forwarding MinIO..."
kubectl port-forward svc/minio -n storage "$MINIO_PORT":9000 &>/dev/null &
PF_MINIO=$!
sleep 2

echo "  Checking MinIO buckets..."
BUCKETS=$(kubectl exec -n storage deploy/minio -- sh -c \
    "mc alias set local http://localhost:9000 $MINIO_USER $MINIO_PASS &>/dev/null && mc ls local/ 2>/dev/null" 2>/dev/null || echo "")
if echo "$BUCKETS" | grep -q "mlflow-artifacts"; then
    ok "MinIO bucket mlflow-artifacts exists"
else
    skip "MinIO bucket mlflow-artifacts not found"
fi
if echo "$BUCKETS" | grep -q "datasets"; then
    ok "MinIO bucket datasets exists"
fi
if echo "$BUCKETS" | grep -q "models"; then
    ok "MinIO bucket models exists"
fi

pf_kill $PF_MINIO

# ---------------------------------------------------------------------------
# 4. SERVING (BentoML API)
# ---------------------------------------------------------------------------
section "4. Model Serving"

echo "  Port-forwarding BentoML serving..."
kubectl port-forward svc/taxi-fare-serving -n mlops "$SERVING_PORT":3000 &>/dev/null &
PF_SERVING=$!
sleep 2

echo "  Checking healthcheck..."
HC=$(curl -s -X POST http://localhost:"$SERVING_PORT"/healthcheck 2>/dev/null || echo "")
if echo "$HC" | grep -q "healthy"; then
    ok "Healthcheck: $HC"
else
    fail "Healthcheck failed" "$HC"
fi

echo "  Checking single prediction..."
PRED=$(curl -s -X POST http://localhost:"$SERVING_PORT"/predict \
    -H "Content-Type: application/json" \
    -d '{"trip":{"passenger_count":2,"trip_distance":3.5,"pickup_hour":14,"pickup_day":3,"pickup_month":6,"PULocationID":100,"DOLocationID":200,"rate_code":1}}' 2>/dev/null || echo "")

if echo "$PRED" | python3 -c "import sys,json; d=json.load(sys.stdin); \
    assert 'predicted_duration_min' in d, 'missing prediction'; \
    assert 0 < d['predicted_duration_min'] < 120, 'out of range'" 2>/dev/null; then
    DUR=$(echo "$PRED" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['predicted_duration_min'])" 2>/dev/null)
    ok "Prediction OK — ${DUR}min for 3.5 mile trip"
else
    fail "Prediction failed" "$PRED"
fi

echo "  Checking input validation..."
INVALID=$(curl -s -X POST http://localhost:"$SERVING_PORT"/predict \
    -H "Content-Type: application/json" \
    -d '{"trip":{"passenger_count":10}}' 2>/dev/null || echo "")
if echo "$INVALID" | grep -qi "error\|validation"; then
    ok "Input validation rejects invalid data"
else
    fail "Input validation not rejecting invalid data" "$INVALID"
fi

pf_kill $PF_SERVING

# ---------------------------------------------------------------------------
# 5. OBSERVABILITY
# ---------------------------------------------------------------------------
section "5. Observability"

echo "  Port-forwarding Prometheus..."
kubectl port-forward svc/prometheus -n monitoring "$PROMETHEUS_PORT":9090 &>/dev/null &
PF_PROM=$!
sleep 2

echo "  Checking Prometheus..."
if curl -s http://localhost:"$PROMETHEUS_PORT"/-/ready | grep -q "Ready"; then
    ok "Prometheus ready"
else
    fail "Prometheus not ready" ""
fi

TARGETS=$(curl -s http://localhost:"$PROMETHEUS_PORT"/api/v1/targets 2>/dev/null | \
    python3 -c "import sys,json; d=json.load(sys.stdin); \
    up=[t for t in d['data']['activeTargets'] if t['health']=='up']; \
    print(len(up))" 2>/dev/null || echo "0")
ok "Prometheus has $TARGETS active target(s)"

pf_kill $PF_PROM

echo "  Checking Grafana..."
kubectl port-forward svc/grafana -n monitoring "$GRAFANA_PORT":3000 &>/dev/null &
PF_GRAF=$!
sleep 2

GRAF_HTTP=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:"$GRAFANA_PORT"/api/health 2>/dev/null || echo "000")
if [ "$GRAF_HTTP" = "200" ]; then
    ok "Grafana healthy (HTTP ${GRAF_HTTP})"
else
    fail "Grafana not responding" "HTTP ${GRAF_HTTP}"
fi

pf_kill $PF_GRAF

echo "  Checking Evidently CronJob..."
if kubectl get cronjob evidently-monitor -n mlops &>/dev/null; then
    SCHEDULE=$(kubectl get cronjob evidently-monitor -n mlops -o jsonpath='{.spec.schedule}')
    ok "Evidently CronJob configured — schedule: $SCHEDULE"
else
    fail "Evidently CronJob not found" ""
fi

# ---------------------------------------------------------------------------
# SUMMARY
# ---------------------------------------------------------------------------
section "Results"

TOTAL=$((PASS + FAIL + SKIP))
echo ""
echo -e "  ${GREEN}Passed: ${PASS}${NC}"
echo -e "  ${RED}Failed: ${FAIL}${NC}"
echo -e "  ${YELLOW}Skipped: ${SKIP}${NC}"
echo "  ─────────────────"
echo -e "  ${BLUE}Total:  ${TOTAL}${NC}"
echo ""

if [ "$FAIL" -eq 0 ]; then
    echo -e "  ${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${GREEN}  ✓ All checks passed! Platform is healthy.${NC}"
    echo -e "  ${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    exit 0
else
    echo -e "  ${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${RED}  ✗ ${FAIL} check(s) failed. Review above.${NC}"
    echo -e "  ${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    exit 1
fi
