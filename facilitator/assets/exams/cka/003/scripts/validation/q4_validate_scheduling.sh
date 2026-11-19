#!/bin/bash
set -euo pipefail

if ! kubectl get deployment worker-check -n cka-scheduling -o json | jq -e '
  .spec.template.spec.nodeSelector == null and
  .status.readyReplicas == 1 and
  .status.availableReplicas == 1
' > /dev/null; then
  echo "worker-check must have no invalid node selector and its replica must be Ready."
  exit 1
fi
echo "The invalid scheduling constraint is removed and the replica is Ready."
