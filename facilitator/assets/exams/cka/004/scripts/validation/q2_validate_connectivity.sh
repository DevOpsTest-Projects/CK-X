#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/../common.sh"
for client in allowed denied; do
  check_json pod "$client" cka-net-policy ".status.phase == \"Running\" and
    .metadata.labels.access == \"$client\" and
    .spec.containers[0].image == \"busybox:1.37.0\" and
    .spec.containers[0].command == [\"sh\",\"-c\",\"sleep 3600\"] and
    any(.status.conditions[]?; .type == \"Ready\" and .status == \"True\")"
done
check_json pod outsider cka-net-outsider '
  .metadata.labels.access == "allowed" and .status.phase == "Running" and
  .spec.containers[0].image == "busybox:1.37.0" and
  .spec.containers[0].command == ["sh","-c","sleep 3600"] and
  any(.status.conditions[]?; .type == "Ready" and .status == "True")
'
ip=$(kubectl get pods -n cka-net-policy -l app=api -o json |
  jq -er '.items[] | select(any(.status.conditions[]?; .type == "Ready" and .status == "True")) | .status.podIP' | head -n 1)
check_http cka-net-policy allowed "http://$ip" cka-net-policy
for attempt in 1 2; do
  if http_get cka-net-policy denied "http://$ip" > /dev/null 2>&1; then
    fail "denied can still access the backend."
  fi
  if http_get cka-net-outsider outsider "http://$ip" > /dev/null 2>&1; then
    fail "Cross-namespace outsider can still access the backend."
  fi
done
echo "Allowed and denied Pod connectivity is correct."
