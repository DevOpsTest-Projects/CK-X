#!/bin/bash
set -euo pipefail

if ! kubectl get pod api-crash -n cka-crashloop -o json | jq -e '
  .spec.containers[0].image == "busybox:1.37.0" and
  .spec.containers[0].command == ["sh", "-c", "sleep 3600"] and
  .status.phase == "Running" and
  any(.status.conditions[]?; .type == "Ready" and .status == "True")
' > /dev/null; then
  echo "api-crash must use the corrected command and be Running and Ready."
  exit 1
fi
echo "The crashing Pod was replaced with a healthy Pod."
