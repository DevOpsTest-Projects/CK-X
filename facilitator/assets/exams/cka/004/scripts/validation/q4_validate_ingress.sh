#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/../common.sh"
check_json ingress web-ingress cka-net-ingress '
  .spec.ingressClassName == "cka-net-traefik" and
  any(.spec.rules[]; .host == "ingress.cka.test" and
    any(.http.paths[]; .path == "/" and .pathType == "Prefix" and
      .backend.service.name == "web" and .backend.service.port.number == 80))
'
