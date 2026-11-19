#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/../common.sh"
check_service web-nodeport NodePort 8081 30090
ip=$(kubectl get nodes -o json | jq -r '[.items[].status.addresses[] | select(.type == "InternalIP")][0].address')
[[ -n "$ip" && "$ip" != null ]] || fail "No node InternalIP is available."
check_http cka-net-services client "http://$ip:30090" cka-net-services
