#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/../common.sh"
create_namespace cka-net-policy
create_namespace cka-net-outsider
create_backend cka-net-policy api
create_client cka-net-policy allowed allowed
create_client cka-net-policy denied denied
create_client cka-net-outsider outsider allowed
# Confirm the clients and server work before imposing isolation.
ip=$(kubectl get pods -n cka-net-policy -l app=api -o jsonpath='{.items[0].status.podIP}')
check_http cka-net-policy allowed "http://$ip" cka-net-policy
check_http cka-net-policy denied "http://$ip" cka-net-policy
check_http cka-net-outsider outsider "http://$ip" cka-net-policy
kubectl apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
  namespace: cka-net-policy
spec:
  podSelector:
    matchLabels:
      app: api
  policyTypes: [Ingress]
  ingress: []
EOF
# Fail setup on CNIs that expose the API but do not enforce NetworkPolicies.
for attempt in $(seq 1 15); do
  if ! http_get cka-net-policy denied "http://$ip" > /dev/null 2>&1; then
    echo "NetworkPolicy enforcement confirmed."
    exit 0
  fi
  sleep 2
done
fail "The cluster CNI is not enforcing the default-deny NetworkPolicy."
