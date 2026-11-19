#!/bin/bash
# Shared setup and grading helpers. Sourced, never executed by the exam runner.
set -euo pipefail

create_namespace() {
  kubectl create namespace "$1" --dry-run=client -o yaml | kubectl apply -f -
}

create_backend() {
  local namespace=$1 name=${2:-web} replicas=${3:-1}
  kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${name}-content
  namespace: $namespace
data:
  index.html: "$namespace"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $name
  namespace: $namespace
spec:
  replicas: $replicas
  selector:
    matchLabels:
      app: $name
  template:
    metadata:
      labels:
        app: $name
    spec:
      containers:
        - name: web
          image: nginx:1.27.5
          ports:
            - containerPort: 80
          readinessProbe:
            httpGet:
              path: /
              port: 80
            periodSeconds: 2
          volumeMounts:
            - name: content
              mountPath: /usr/share/nginx/html
      volumes:
        - name: content
          configMap:
            name: ${name}-content
---
apiVersion: v1
kind: Service
metadata:
  name: $name
  namespace: $namespace
spec:
  selector:
    app: $name
  ports:
    - port: 80
      targetPort: 80
      protocol: TCP
EOF
  kubectl rollout status "deployment/$name" -n "$namespace" --timeout=180s
}

create_client() {
  local namespace=$1 name=${2:-client} access=${3:-client}
  kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: $name
  namespace: $namespace
  labels:
    access: $access
spec:
  containers:
    - name: client
      image: busybox:1.37.0
      command: ["sh", "-c", "sleep 3600"]
EOF
  kubectl wait -n "$namespace" --for=condition=Ready "pod/$name" --timeout=120s
}

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

check_json() {
  local resource=$1 name=$2 namespace=$3 predicate=$4
  kubectl get "$resource" "$name" -n "$namespace" -o json |
    jq -e "$predicate" > /dev/null || fail "$resource/$name does not meet the required configuration."
}

check_service() {
  local name=$1 type=$2 port=$3 node_port=${4:-0}
  check_json service "$name" cka-net-services "
    .spec.type == \"$type\" and
    .spec.clusterIP != null and .spec.clusterIP != \"None\" and
    .spec.selector == {\"app\":\"web\"} and
    any(.spec.ports[]; .port == $port and .targetPort == 80 and
      .protocol == \"TCP\" and ($node_port == 0 or .nodePort == $node_port))
  "
}

http_get() {
  local namespace=$1 client=$2 url=$3 host=${4:-}
  if [[ -n "$host" ]]; then
    kubectl exec "$client" -n "$namespace" -- wget -q -T 5 -O - --header "Host: $host" "$url"
  else
    kubectl exec "$client" -n "$namespace" -- wget -q -T 5 -O - "$url"
  fi
}

check_http() {
  local namespace=$1 client=$2 url=$3 token=$4 host=${5:-}
  local output
  # Controller reconciliation is asynchronous; allow a bounded retry window.
  for attempt in 1 2 3 4 5; do
    if output=$(http_get "$namespace" "$client" "$url" "$host") && [[ "$output" == *"$token"* ]]; then
      echo "HTTP response contains $token."
      return 0
    fi
    sleep 2
  done
  fail "HTTP request to $url did not return $token."
}
