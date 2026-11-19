#!/bin/bash
set -euo pipefail
<<<<<<< HEAD
source "$(dirname "$0")/../common.sh"
create_namespace cka-net-ingress
create_backend cka-net-ingress
create_client cka-net-ingress
=======

kubectl create namespace cka-scheduling --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: worker-check
  namespace: cka-scheduling
spec:
  replicas: 1
  selector:
    matchLabels:
      app: worker-check
  template:
    metadata:
      labels:
        app: worker-check
    spec:
      nodeSelector:
        cka-x-schedule: missing
      containers:
        - name: web
          image: nginx:1.27.5
EOF
>>>>>>> 353749d2a249621e7ff601bdb32a3c02f9d587e1
