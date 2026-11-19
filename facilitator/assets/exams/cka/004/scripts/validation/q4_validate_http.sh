#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/../common.sh"
check_http cka-net-ingress client http://cka-net-traefik.cka-net-system.svc.cluster.local \
  cka-net-ingress ingress.cka.test
