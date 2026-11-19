#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/../common.sh"
check_json pod dns-client cka-net-dns '
  .spec.dnsPolicy == "ClusterFirst" and
  (.spec.dnsConfig == null) and (.spec.hostNetwork != true) and
  .spec.containers[0].image == "busybox:1.37.0" and
  .spec.containers[0].command == ["sh","-c","sleep 3600"] and
  any(.status.conditions[]?; .type == "Ready" and .status == "True")
'
