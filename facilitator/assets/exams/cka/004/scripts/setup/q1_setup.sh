#!/bin/bash
set -euo pipefail
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
EOF
