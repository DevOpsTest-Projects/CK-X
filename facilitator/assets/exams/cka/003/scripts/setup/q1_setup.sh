#!/bin/bash
set -euo pipefail

kubectl create namespace cka-crashloop --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: api-crash
  namespace: cka-crashloop
spec:
  containers:
    - name: app
      image: busybox:1.37.0
      command: ["sh", "-c", "exit 1"]
EOF
