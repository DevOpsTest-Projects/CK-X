#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/../common.sh"
create_namespace cka-net-gateway
create_backend cka-net-gateway
create_client cka-net-gateway
