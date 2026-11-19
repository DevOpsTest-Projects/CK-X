#!/bin/bash
set -euo pipefail

if ! kubectl get deployment web-check -n cka-readiness -o json | jq -e '
  .spec.template.spec.containers[0].readinessProbe.httpGet.path == "/" and
  .status.readyReplicas == 1 and
  .status.availableReplicas == 1
' > /dev/null; then
  echo "web-check must probe / and have a Ready replica."
  exit 1
fi
echo "The readiness probe and Deployment status are correct."
