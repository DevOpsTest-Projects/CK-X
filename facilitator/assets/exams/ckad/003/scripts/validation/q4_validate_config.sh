#!/bin/bash
set -euo pipefail

if ! kubectl get configmap app-config -n quick-config -o json | jq -e '
  .data.APP_MODE == "practice"
' > /dev/null; then
  echo "app-config must contain APP_MODE=practice."
  exit 1
fi

pod=$(kubectl get pod config-pod -n quick-config -o json)
if ! jq -e '
  .status.phase == "Running" and
  any(.spec.containers[];
    .image == "busybox:1.37.0" and
    .command == ["sh", "-c", "sleep 3600"] and
    any(.env[]?;
      .name == "APP_MODE" and
      .valueFrom.configMapKeyRef.name == "app-config" and
      .valueFrom.configMapKeyRef.key == "APP_MODE"))
' <<< "$pod" > /dev/null; then
  echo "config-pod must use busybox:1.37.0, sleep 3600, and read APP_MODE through configMapKeyRef."
  exit 1
fi

container=$(jq -r '
  .spec.containers[] |
  select(.image == "busybox:1.37.0" and
    any(.env[]?; .name == "APP_MODE" and
      .valueFrom.configMapKeyRef.name == "app-config" and
      .valueFrom.configMapKeyRef.key == "APP_MODE")) | .name
' <<< "$pod" | head -n 1)
if [[ "$(kubectl exec config-pod -n quick-config -c "$container" -- printenv APP_MODE)" != "practice" ]]; then
  echo "APP_MODE inside config-pod must equal practice."
  exit 1
fi
echo "ConfigMap reference and container environment are correct."
