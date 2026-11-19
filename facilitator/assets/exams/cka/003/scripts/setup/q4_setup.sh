#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/../common.sh"
create_namespace cka-net-ingress
create_backend cka-net-ingress
create_client cka-net-ingress
