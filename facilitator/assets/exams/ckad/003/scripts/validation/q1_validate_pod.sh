#!/bin/bash
set -euo pipefail

if ! kubectl get pod web-pod -n quick-pods -o json | jq -e '
  .metadata.labels.app == "web" and
  .metadata.labels.env == "practice" and
  any(.spec.containers[]; .image == "nginx:1.27.5") and
  .status.phase == "Running" and
  any(.status.conditions[]?; .type == "Ready" and .status == "True")
' > /dev/null; then
  echo "web-pod must use nginx:1.27.5, have app=web and env=practice, and be Running and Ready."
  exit 1
fi
echo "Pod configuration and readiness are correct."
