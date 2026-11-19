#!/bin/bash
set -euo pipefail

if ! kubectl get service payments -n cka-service -o json | jq -e '
  .spec.selector == {"app":"payments"}
' > /dev/null; then
  echo "payments Service must select Pods with app=payments."
  exit 1
fi

if ! kubectl get endpoints payments -n cka-service -o json | jq -e '
  [.subsets[]?.addresses[]?] | length == 2
' > /dev/null; then
  echo "payments Service must have both Ready Pods as endpoints."
  exit 1
fi
echo "The Service selects both Ready Pods."
