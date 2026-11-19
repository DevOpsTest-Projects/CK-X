#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/../common.sh"
check_service web-lb LoadBalancer 8082
# Public/cloud IP allocation is deliberately not required in this local lab.
check_http cka-net-services client http://web-lb:8082 cka-net-services
