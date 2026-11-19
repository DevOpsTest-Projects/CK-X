#!/bin/bash
set -euo pipefail
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
