#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/../common.sh"
check_http cka-net-gateway client http://cka-net-traefik.cka-net-system.svc.cluster.local \
  cka-net-gateway gateway.cka.test
