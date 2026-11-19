#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/../common.sh"
check_json networkpolicy default-deny cka-net-policy '
  .spec.podSelector == {"matchLabels":{"app":"api"}} and
  .spec.policyTypes == ["Ingress"] and ((.spec.ingress // []) | length) == 0
'
check_json networkpolicy allow-client cka-net-policy '
  .spec.podSelector == {"matchLabels":{"app":"api"}} and
  .spec.policyTypes == ["Ingress"] and
  .spec.ingress == [{
    "from":[{"podSelector":{"matchLabels":{"access":"allowed"}}}],
    "ports":[{"protocol":"TCP","port":80}]
  }]
'
echo "Same-namespace ingress policy is correct."
