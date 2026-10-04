cluster := "langfuse"
ctx := "kind-langfuse"
ns := "langfuse"

default:
    @just --list

# Create the cluster, install everything, wait until ready
up: cluster operators install wait

# Create the kind cluster (idempotent). Restores your previous kubectl context afterwards.
cluster:
    #!/usr/bin/env bash
    set -euo pipefail
    kind get clusters | grep -qx {{cluster}} && exit 0
    prev=$(kubectl config current-context 2>/dev/null || true)
    kind create cluster --config kind-config.yaml
    [ -z "$prev" ] || kubectl config use-context "$prev"

# cert-manager + ClickHouse operator (chart prerequisites, once per cluster)
operators:
    helm --kube-context {{ctx}} upgrade --install cert-manager oci://quay.io/jetstack/charts/cert-manager \
      --version v1.20.2 -n cert-manager --create-namespace --set crds.enabled=true --wait
    helm --kube-context {{ctx}} upgrade --install clickhouse-operator oci://ghcr.io/clickhouse/clickhouse-operator-helm \
      --version 0.0.5 -n clickhouse-operator --create-namespace --wait
    kubectl --context {{ctx}} wait --for=condition=Established \
      crd/certificates.cert-manager.io crd/clickhouseclusters.clickhouse.com crd/keeperclusters.clickhouse.com --timeout=120s

install:
    helm --kube-context {{ctx}} upgrade --install langfuse oci://ghcr.io/langfuse/langfuse-k8s/charts/langfuse \
      --version 2.0.0 -n {{ns}} --create-namespace -f values.yaml

wait:
    kubectl --context {{ctx}} -n {{ns}} rollout status deploy/langfuse-web --timeout=600s
    kubectl --context {{ctx}} -n {{ns}} rollout status deploy/langfuse-worker --timeout=600s
    until curl -fsS localhost:3000/api/public/health >/dev/null; do sleep 3; done
    @echo "Langfuse ready: http://localhost:3000  (admin@local.dev / localpassword)"

# Create .env from .env.example (if missing); then add your OPENAI_API_KEY to it
env:
    #!/usr/bin/env bash
    set -euo pipefail
    [ -f .env ] && echo ".env already exists, leaving it alone" || { cp .env.example .env; echo "created .env - set OPENAI_API_KEY in it"; }

# Run the demo app (sends traces to local Langfuse)
demo *args:
    uv run demo.py {{args}}

status:
    kubectl --context {{ctx}} get pods -A

logs svc="langfuse-web":
    kubectl --context {{ctx}} -n {{ns}} logs deploy/{{svc}} --tail=100 -f

down:
    kind delete cluster --name {{cluster}}
