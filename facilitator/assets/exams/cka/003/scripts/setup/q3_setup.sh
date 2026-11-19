#!/bin/bash
set -euo pipefail

kubectl create namespace cka-service --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payments
  namespace: cka-service
spec:
  replicas: 2
  selector:
    matchLabels:
      app: payments
  template:
    metadata:
      labels:
        app: payments
    spec:
      containers:
        - name: web
          image: nginx:1.27.5
          ports:
            - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: payments
  namespace: cka-service
spec:
  selector:
    app: payment
  ports:
    - port: 80
      targetPort: 80
EOF
