#!/bin/bash
set -euo pipefail

kubectl create namespace cka-readiness --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-check
  namespace: cka-readiness
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web-check
  template:
    metadata:
      labels:
        app: web-check
    spec:
      containers:
        - name: web
          image: nginx:1.27.5
          ports:
            - containerPort: 80
          readinessProbe:
            httpGet:
              path: /healthz
              port: 80
            periodSeconds: 2
            failureThreshold: 1
EOF
