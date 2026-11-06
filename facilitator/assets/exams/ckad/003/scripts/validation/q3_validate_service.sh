#!/bin/bash
set -euo pipefail

if ! kubectl get service backend-svc -n quick-services -o json | jq -e '
  .spec.type == "ClusterIP" and
  .spec.clusterIP != null and .spec.clusterIP != "None" and
  .spec.selector == {"app": "backend"} and
  any(.spec.ports[]; .port == 8080 and .targetPort == 80 and .protocol == "TCP")
' > /dev/null; then
  echo "backend-svc must be a ClusterIP Service with selector app=backend and TCP 8080 -> 80."
  exit 1
fi
echo "Service configuration is correct."
