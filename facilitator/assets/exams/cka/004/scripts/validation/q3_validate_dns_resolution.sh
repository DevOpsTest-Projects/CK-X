#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/../common.sh"
ip=$(kubectl get service web -n cka-net-dns -o jsonpath='{.spec.clusterIP}')
[[ -n "$ip" && "$ip" != None ]] || fail "Service web has no ClusterIP."
lookup=$(kubectl exec dns-client -n cka-net-dns -- nslookup web.cka-net-dns.svc.cluster.local)
# Match a complete IP token, not a substring or a DNS server's address.
answer=$(printf '%s\n' "$lookup" | sed -n '/^Name:/,$p')
printf '%s\n' "$answer" | grep -Fwq "$ip" || fail "CoreDNS did not resolve web to its ClusterIP."
check_http cka-net-dns dns-client http://web.cka-net-dns.svc.cluster.local cka-net-dns
