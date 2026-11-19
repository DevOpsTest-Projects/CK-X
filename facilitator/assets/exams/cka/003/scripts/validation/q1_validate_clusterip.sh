#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/../common.sh"
check_service web-svc ClusterIP 8080
expected=$(kubectl get pods -n cka-net-services -l app=web -o json |
  jq -c '[.items[] | select(.status.phase == "Running") | .status.podIP] | sort')
[[ $(jq 'length' <<< "$expected") == 2 ]] || fail "Expected two backend Pod IPs."
actual=$(kubectl get endpointslices -n cka-net-services -l kubernetes.io/service-name=web-svc -o json |
  jq -c '[.items[].endpoints[] | select(.conditions.ready == true) | .addresses[]] | unique | sort')
[[ "$actual" == "$expected" ]] || fail "web-svc must have both ready backend Pod IPs in its EndpointSlices."
check_http cka-net-services client http://web-svc:8080 cka-net-services
