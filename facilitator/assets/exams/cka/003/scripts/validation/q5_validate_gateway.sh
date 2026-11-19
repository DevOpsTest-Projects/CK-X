#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/../common.sh"
check_json gateway web-gateway cka-net-gateway '
  .metadata.generation as $generation |
  .spec.gatewayClassName == "cka-net-traefik" and
  any(.spec.listeners[];
    .name == "http" and .port == 8000 and .protocol == "HTTP" and
    .hostname == "gateway.cka.test" and
    (.allowedRoutes.namespaces.from // "Same") == "Same") and
  any(.status.conditions[]?;
    .type == "Programmed" and .status == "True" and .observedGeneration == $generation)
'
