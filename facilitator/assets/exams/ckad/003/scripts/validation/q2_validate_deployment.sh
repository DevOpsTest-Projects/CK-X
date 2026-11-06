#!/bin/bash
set -euo pipefail

if ! kubectl get deployment frontend -n quick-deployments -o json | jq -e '
  .spec.replicas == 3 and
  .spec.template.metadata.labels.app == "frontend" and
  any(.spec.template.spec.containers[]; .image == "nginx:1.27.5") and
  .status.observedGeneration >= .metadata.generation and
  .status.updatedReplicas == 3 and
  .status.readyReplicas == 3 and
  .status.availableReplicas == 3
' > /dev/null; then
  echo "frontend must have three updated, ready, available replicas using nginx:1.27.5 and app=frontend."
  exit 1
fi
echo "Deployment configuration and replicas are correct."
