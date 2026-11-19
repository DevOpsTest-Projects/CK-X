#!/bin/bash
set -euo pipefail

if ! kubectl get deployment catalog -n cka-image -o json | jq -e '
  .spec.replicas == 2 and
  .spec.template.spec.containers[0].image == "nginx:1.27.5" and
  .status.readyReplicas == 2 and
  .status.availableReplicas == 2
' > /dev/null; then
  echo "catalog must use nginx:1.27.5 and have two available replicas."
  exit 1
fi
echo "The image and Deployment replicas are correct."
