#!/bin/bash
# Offline tests for the real grading scripts. Requires Bash and jq, not Kubernetes.
set -euo pipefail
validation="$(cd "$(dirname "$0")/../assets/exams/cka/004/scripts/validation" && pwd)"
export MOCK_FILTER='.' MOCK_RESOURCE='' MOCK_HTTP=good MOCK_NETWORK=isolated MOCK_FAILURE=''

# Mock only kubectl transport; use real jq and the production shell predicates.
kubectl() {
  local action=$1 resource=${2:-} name=${3:-} namespace='' arg previous=''
  for arg in "$@"; do
    if [[ "$previous" == -n ]]; then namespace=$arg; fi
    previous=$arg
  done
  if [[ "$action" == exec ]]; then
    local client=$resource
    if [[ "$MOCK_FAILURE" == exec ]]; then return 1; fi
    if [[ "$*" == *nslookup* ]]; then
      if [[ "$MOCK_HTTP" == wrong-dns ]]; then
        printf 'Server: 10.43.0.10\nAddress: 10.43.0.10:53\nName: web.cka-net-dns.svc.cluster.local\nAddress: 10.43.0.99\n'
      else
        printf 'Server: 10.43.0.10\nAddress: 10.43.0.10:53\nName: web.cka-net-dns.svc.cluster.local\nAddress: 10.43.0.20\n'
      fi
      return 0
    fi
    if [[ "$MOCK_NETWORK" == isolated && "$client" == denied || "$MOCK_NETWORK" == isolated && "$client" == outsider ]]; then
      return 1
    fi
    if [[ "$MOCK_HTTP" == wrong-body ]]; then echo wrong-backend; else echo "$namespace"; fi
    return 0
  fi
  [[ "$action" == get ]] || return 1
  [[ "$MOCK_FAILURE" != "$resource/$name" ]] || return 1
  local json
  case "$resource" in
    service)
      if [[ "$*" == *jsonpath* ]]; then echo 10.43.0.20; return 0; fi
      local type=ClusterIP port=8080 nodeport=0
      case "$name" in
        web-nodeport) type=NodePort; port=8081; nodeport=30090 ;;
        web-lb) type=LoadBalancer; port=8082 ;;
      esac
      json=$(jq -nc --arg type "$type" --argjson port "$port" --argjson nodeport "$nodeport" \
        '{spec:{type:$type,clusterIP:"10.43.0.20",selector:{app:"web"},ports:[{port:$port,targetPort:80,protocol:"TCP",nodePort:$nodeport}]}}')
      ;;
    pods)
      json='{"items":[{"status":{"phase":"Running","podIP":"10.42.0.10","conditions":[{"type":"Ready","status":"True"}]}},{"status":{"phase":"Running","podIP":"10.42.0.11","conditions":[{"type":"Ready","status":"True"}]}}]}'
      ;;
    endpointslices)
      json='{"items":[{"endpoints":[{"conditions":{"ready":true},"addresses":["10.42.0.10"]},{"conditions":{"ready":true},"addresses":["10.42.0.11"]}]}]}'
      ;;
    nodes)
      json='{"items":[{"status":{"addresses":[{"type":"InternalIP","address":"172.18.0.2"}]}}]}'
      ;;
    pod)
      local access=$name
      [[ "$name" != outsider ]] || access=allowed
      json=$(jq -nc --arg access "$access" \
        '{metadata:{labels:{access:$access}},spec:{dnsPolicy:"ClusterFirst",containers:[{image:"busybox:1.37.0",command:["sh","-c","sleep 3600"]}]},status:{phase:"Running",conditions:[{type:"Ready",status:"True"}]}}')
      ;;
    networkpolicy)
      if [[ "$name" == default-deny ]]; then
        json='{"spec":{"podSelector":{"matchLabels":{"app":"api"}},"policyTypes":["Ingress"],"ingress":[]}}'
      else
        json='{"spec":{"podSelector":{"matchLabels":{"app":"api"}},"policyTypes":["Ingress"],"ingress":[{"from":[{"podSelector":{"matchLabels":{"access":"allowed"}}}],"ports":[{"protocol":"TCP","port":80}]}]}}'
      fi
      ;;
    ingress)
      json='{"spec":{"ingressClassName":"cka-net-traefik","rules":[{"host":"ingress.cka.test","http":{"paths":[{"path":"/","pathType":"Prefix","backend":{"service":{"name":"web","port":{"number":80}}}}]}}]}}'
      ;;
    gateway)
      json='{"metadata":{"generation":2},"spec":{"gatewayClassName":"cka-net-traefik","listeners":[{"name":"http","port":8000,"protocol":"HTTP","hostname":"gateway.cka.test","allowedRoutes":{"namespaces":{"from":"Same"}}}]},"status":{"conditions":[{"type":"Programmed","status":"True","observedGeneration":2}]}}'
      ;;
    httproute)
      json='{"metadata":{"generation":2},"spec":{"hostnames":["gateway.cka.test"],"parentRefs":[{"name":"web-gateway","sectionName":"http"}],"rules":[{"matches":[{"path":{"type":"PathPrefix","value":"/"}}],"backendRefs":[{"name":"web","port":80}]}]},"status":{"parents":[{"parentRef":{"name":"web-gateway","sectionName":"http"},"controllerName":"traefik.io/gateway-controller","conditions":[{"type":"Accepted","status":"True","observedGeneration":2},{"type":"ResolvedRefs","status":"True","observedGeneration":2}]}]}}'
      ;;
    *) return 1 ;;
  esac
  if [[ "$MOCK_RESOURCE" == "$resource/$name" || "$MOCK_RESOURCE" == "$resource" ]]; then
    jq "$MOCK_FILTER" <<< "$json"
  else
    printf '%s\n' "$json"
  fi
}

# Avoid waiting for real controller reconciliation in offline negative fixtures.
sleep() { :; }
export -f kubectl sleep
count=0
run_case() {
  local expected=$1 script=$2 label=$3 status=0
  bash "$validation/$script" > /dev/null 2>&1 || status=$?
  if [[ "$expected" == pass && "$status" != 0 || "$expected" == fail && "$status" == 0 ]]; then
    echo "FAIL: $label ($script, expected $expected, exit $status)" >&2
    exit 1
  fi
  count=$((count + 1))
  echo "PASS: $label"
}
mutate() {
  MOCK_RESOURCE=$1 MOCK_FILTER=$2
}

for script in "$validation"/q*.sh; do
  run_case pass "$(basename "$script")" "Valid fixture: $(basename "$script")"
done

mutate service/web-svc '.spec.selector.app="broken"'
run_case fail q1_validate_clusterip.sh 'Incorrect ClusterIP selector is rejected'
mutate service/web-svc '.spec.ports[0].targetPort=81'
run_case fail q1_validate_clusterip.sh 'Incorrect target port is rejected'
mutate endpointslices '.items[0].endpoints[1].conditions.ready=false'
run_case fail q1_validate_clusterip.sh 'Missing ready backend endpoint is rejected'
mutate endpointslices '.items[0].endpoints[1].addresses=["10.42.0.99"]'
run_case fail q1_validate_clusterip.sh 'Wrong endpoint address is rejected'
mutate service/web-nodeport '.spec.ports[0].nodePort=30091'
run_case fail q1_validate_nodeport.sh 'Incorrect NodePort is rejected'
mutate service/web-lb '.spec.type="ClusterIP"'
run_case fail q1_validate_loadbalancer.sh 'Incorrect LoadBalancer type is rejected'
mutate networkpolicy/allow-client '.spec.ingress[0].from[0].namespaceSelector={}'
run_case fail q2_validate_policy.sh 'Cross-namespace policy allowance is rejected'
mutate networkpolicy/allow-client '.spec.ingress[0].ports[0].port=443'
run_case fail q2_validate_policy.sh 'Incorrect policy port is rejected'
mutate networkpolicy/default-deny '.spec.ingress=[{}]'
run_case fail q2_validate_policy.sh 'Modified default-deny policy is rejected'
mutate '' '.'
MOCK_NETWORK=open
run_case fail q2_validate_connectivity.sh 'A non-enforcing or permissive CNI fails traffic grading'
MOCK_NETWORK=isolated
mutate pod/denied '.status.conditions[0].status="False"'
run_case fail q2_validate_connectivity.sh 'An unready denied client cannot falsely prove isolation'
mutate pod/dns-client '.spec.dnsPolicy="None"'
run_case fail q3_validate_dns_config.sh 'Incorrect DNS policy is rejected'
mutate pod/dns-client '.spec.dnsConfig={nameservers:["127.0.0.1"]}'
run_case fail q3_validate_dns_config.sh 'Custom DNS overrides are rejected'
mutate '' '.'
MOCK_HTTP=wrong-dns
run_case fail q3_validate_dns_resolution.sh 'DNS answer with the wrong Service IP is rejected'
MOCK_HTTP=good
mutate ingress/web-ingress '.spec.ingressClassName="traefik"'
run_case fail q4_validate_ingress.sh 'Incorrect IngressClass is rejected'
mutate ingress/web-ingress '.spec.rules[0].http.paths[0].backend.service.port.number=81'
run_case fail q4_validate_ingress.sh 'Incorrect Ingress backend port is rejected'
mutate gateway/web-gateway '.spec.listeners[0].allowedRoutes.namespaces.from="All"'
run_case fail q5_validate_gateway.sh 'Cross-namespace Gateway attachment is rejected'
mutate gateway/web-gateway '.status.conditions[0].observedGeneration=1'
run_case fail q5_validate_gateway.sh 'Stale Gateway status is rejected'
mutate httproute/web-route '.status.parents[0].conditions[1].status="False"'
run_case fail q5_validate_route.sh 'Unresolved backend references are rejected'
mutate httproute/web-route '.spec.parentRefs[0].namespace="other"'
run_case fail q5_validate_route.sh 'Wrong route parent namespace is rejected'
mutate httproute/web-route '.status.parents[0].conditions[0].observedGeneration=1'
run_case fail q5_validate_route.sh 'Stale HTTPRoute status is rejected'
mutate httproute/web-route '.spec.rules[0].backendRefs[0].weight=0'
run_case fail q5_validate_route.sh 'Zero-weight backend is rejected'
mutate '' '.'
MOCK_HTTP=wrong-body
run_case fail q4_validate_http.sh 'Wrong Ingress HTTP backend is rejected'
run_case fail q5_validate_http.sh 'Wrong Gateway HTTP backend is rejected'
MOCK_HTTP=good MOCK_FAILURE=service/web-svc
run_case fail q1_validate_clusterip.sh 'Missing Kubernetes resource is rejected'
MOCK_FAILURE=exec
run_case fail q3_validate_dns_resolution.sh 'Failed DNS command is rejected'
echo "$count grading-script regression cases passed."
