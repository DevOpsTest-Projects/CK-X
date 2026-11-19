#!/bin/bash
set -euo pipefail
<<<<<<< HEAD
source "$(dirname "$0")/../common.sh"
create_namespace cka-net-dns
create_backend cka-net-dns
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: dns-client
  namespace: cka-net-dns
spec:
  dnsPolicy: None
  dnsConfig:
    nameservers: ["127.0.0.1"]
  containers:
    - name: client
      image: busybox:1.37.0
      command: ["sh", "-c", "sleep 3600"]
EOF
kubectl wait -n cka-net-dns --for=condition=Ready pod/dns-client --timeout=120s
=======

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
>>>>>>> 353749d2a249621e7ff601bdb32a3c02f9d587e1
