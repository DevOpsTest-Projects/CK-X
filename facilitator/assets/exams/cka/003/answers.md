# CKA Services & Networking — Solutions

**Duration:** 30 minutes for the entire test. **Questions:** 5.
**Marks:** 20 per question, 100 total, with partial credit per verification step.

The namespaces, backend Deployments, and client Pods are prepared during warm-up.
IngressClass and GatewayClass `cka-net-traefik` are also prepared automatically.
The suggested question times total 30 minutes; there are no individual timers.

## Question 1: Service types and ready endpoints — 6 minutes

Repair the Service selector and target port without altering the backend:

```bash
kubectl patch service web-svc -n cka-net-services --type=merge -p \
  '{"spec":{"selector":{"app":"web"},"ports":[{"port":8080,"targetPort":80,"protocol":"TCP"}]}}'

kubectl get pods -n cka-net-services -l app=web -o wide
kubectl get endpointslices -n cka-net-services \
  -l kubernetes.io/service-name=web-svc -o yaml
kubectl exec client -n cka-net-services -- wget -q -O - http://web-svc:8080
```

The ready EndpointSlice addresses should match both backend Pod IPs.
The HTTP response should contain `cka-net-services`.

Create the NodePort and LoadBalancer Services:

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: web-nodeport
  namespace: cka-net-services
spec:
  type: NodePort
  selector:
    app: web
  ports:
    - port: 8081
      targetPort: 80
      nodePort: 30090
      protocol: TCP
---
apiVersion: v1
kind: Service
metadata:
  name: web-lb
  namespace: cka-net-services
spec:
  type: LoadBalancer
  selector:
    app: web
  ports:
    - port: 8082
      targetPort: 80
      protocol: TCP
EOF
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
kubectl exec client -n cka-net-services -- wget -q -O - "http://$NODE_IP:30090"
kubectl exec client -n cka-net-services -- wget -q -O - http://web-lb:8082
```

ClusterIP exposes a Service within the cluster. NodePort also exposes the port
on node addresses. LoadBalancer requests the cluster's configured external
load-balancer integration. This local test grades its Service configuration and
internal connectivity, not cloud provisioning or public-IP assignment.

## Question 2: Enforce same-namespace Pod connectivity — 7 minutes

Leave the existing `default-deny` policy in place and add an explicit allowance:

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-client
  namespace: cka-net-policy
spec:
  podSelector:
    matchLabels:
      app: api
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              access: allowed
      ports:
        - protocol: TCP
          port: 80
EOF
API_IP=$(kubectl get pods -n cka-net-policy -l app=api -o jsonpath='{.items[0].status.podIP}')
kubectl exec allowed -n cka-net-policy -- wget -q -T 5 -O - "http://$API_IP"
kubectl exec denied -n cka-net-policy -- wget -q -T 5 -O - "http://$API_IP"
kubectl exec outsider -n cka-net-outsider -- wget -q -T 5 -O - "http://$API_IP"
```

Only the first request should succeed and return `cka-net-policy`. A standalone
`podSelector` in an ingress peer matches Pods in the policy's own namespace.
Adding `namespaceSelector: {}` would admit matching Pods from other namespaces
and violate the question. Policies are additive: a separate permissive policy
can accidentally undo the intended isolation. The grader checks actual traffic.

## Question 3: Repair Pod DNS and use CoreDNS — 4 minutes

Inspect the broken DNS settings, then recreate only the client. Pod DNS fields
are not generally mutable in place, so recreation is appropriate here.

```bash
kubectl get pod dns-client -n cka-net-dns -o yaml
kubectl delete pod dns-client -n cka-net-dns --wait=true
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: dns-client
  namespace: cka-net-dns
spec:
  dnsPolicy: ClusterFirst
  containers:
    - name: client
      image: busybox:1.37.0
      command: ["sh", "-c", "sleep 3600"]
EOF
kubectl wait -n cka-net-dns --for=condition=Ready pod/dns-client --timeout=120s
kubectl exec dns-client -n cka-net-dns -- cat /etc/resolv.conf
kubectl exec dns-client -n cka-net-dns -- nslookup web.cka-net-dns.svc.cluster.local
kubectl get service web -n cka-net-dns -o jsonpath='{.spec.clusterIP}{"\n"}'
kubectl exec dns-client -n cka-net-dns -- wget -q -O - http://web.cka-net-dns.svc.cluster.local
```

Compare the DNS answer with the Service ClusterIP. The HTTP response should
contain `cka-net-dns`. `ClusterFirst` sends cluster-local queries to the cluster
DNS service; the exercise repairs the client rather than modifying global
CoreDNS settings and disrupting other questions.

## Question 4: Route HTTP through an Ingress controller — 6 minutes

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web-ingress
  namespace: cka-net-ingress
spec:
  ingressClassName: cka-net-traefik
  rules:
    - host: ingress.cka.test
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: web
                port:
                  number: 80
EOF
kubectl describe ingress web-ingress -n cka-net-ingress
kubectl exec client -n cka-net-ingress -- wget -q -T 5 -O - \
  --header 'Host: ingress.cka.test' \
  http://cka-net-traefik.cka-net-system.svc.cluster.local
```

The response should contain `cka-net-ingress`. The `Host` header selects the
Ingress rule while the URL reaches the prepared controller's internal Service.
An Ingress resource alone does not forward traffic; a matching controller must
process it.

## Question 5: Manage ingress traffic using Gateway API — 7 minutes

```bash
kubectl apply -f - <<'EOF'
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: web-gateway
  namespace: cka-net-gateway
spec:
  gatewayClassName: cka-net-traefik
  listeners:
    - name: http
      hostname: gateway.cka.test
      protocol: HTTP
      port: 8000
      allowedRoutes:
        namespaces:
          from: Same
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: web-route
  namespace: cka-net-gateway
spec:
  parentRefs:
    - name: web-gateway
      sectionName: http
  hostnames:
    - gateway.cka.test
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: web
          port: 80
EOF
kubectl wait -n cka-net-gateway --for=condition=Programmed gateway/web-gateway --timeout=120s
kubectl get httproute web-route -n cka-net-gateway -o yaml
kubectl exec client -n cka-net-gateway -- wget -q -T 5 -O - \
  --header 'Host: gateway.cka.test' \
  http://cka-net-traefik.cka-net-system.svc.cluster.local
```

Check the HTTPRoute parent status for `Accepted=True` and `ResolvedRefs=True`
at the current resource generation. The HTTP response should contain
`cka-net-gateway`. The Gateway uses the controller entrypoint port `8000`;
the controller's Service exposes that entrypoint as port `80`.

GatewayClass identifies the implementation, Gateway defines the listener and
route attachment policy, and HTTPRoute defines hostname/path matching and
backend forwarding. This division differs from a single Ingress resource.
