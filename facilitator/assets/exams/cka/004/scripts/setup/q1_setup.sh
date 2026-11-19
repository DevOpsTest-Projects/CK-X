#!/bin/bash
set -euo pipefail
<<<<<<< HEAD
source "$(dirname "$0")/../common.sh"
create_namespace cka-net-services
create_backend cka-net-services web 2
create_client cka-net-services
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: web-svc
  namespace: cka-net-services
spec:
  selector:
    app: broken
  ports:
    - port: 8080
      targetPort: 81
      protocol: TCP
=======

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
>>>>>>> 353749d2a249621e7ff601bdb32a3c02f9d587e1
EOF
