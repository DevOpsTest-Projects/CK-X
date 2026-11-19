#!/bin/bash
set -euo pipefail

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
