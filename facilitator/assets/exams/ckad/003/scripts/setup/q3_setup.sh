#!/bin/bash
set -euo pipefail

kubectl create namespace quick-services --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: quick-services
spec:
  replicas: 1
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
        - name: nginx
          image: nginx:1.27.5
          ports:
            - containerPort: 80
EOF
kubectl rollout status deployment/backend -n quick-services --timeout=180s
echo "Question 3 backend is ready."
