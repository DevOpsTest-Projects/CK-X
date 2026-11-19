#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/../common.sh"
check_json httproute web-route cka-net-gateway '
  .metadata.generation as $generation |
  any(.spec.hostnames[]?; . == "gateway.cka.test") and
  any(.spec.parentRefs[];
    .name == "web-gateway" and .sectionName == "http" and
    (.namespace // "cka-net-gateway") == "cka-net-gateway" and
    (.group // "gateway.networking.k8s.io") == "gateway.networking.k8s.io" and
    (.kind // "Gateway") == "Gateway") and
  any(.spec.rules[];
    any(.matches[]?; .path.type == "PathPrefix" and .path.value == "/") and
    ((.filters // []) | length) == 0 and
    (.backendRefs | length) == 1 and
    .backendRefs[0].name == "web" and .backendRefs[0].port == 80 and
    (.backendRefs[0].namespace // "cka-net-gateway") == "cka-net-gateway" and
    (.backendRefs[0].kind // "Service") == "Service" and
    (.backendRefs[0].group // "") == "" and
    (.backendRefs[0].weight // 1) > 0) and
  any(.status.parents[]?;
    .parentRef.name == "web-gateway" and .parentRef.sectionName == "http" and
    .controllerName == "traefik.io/gateway-controller" and
    any(.conditions[]; .type == "Accepted" and .status == "True" and .observedGeneration == $generation) and
    any(.conditions[]; .type == "ResolvedRefs" and .status == "True" and .observedGeneration == $generation))
'
