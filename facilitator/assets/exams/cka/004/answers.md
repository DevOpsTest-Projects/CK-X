<<<<<<< HEAD
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
=======
# CKA Quick Troubleshooting Test — Solutions

**Duration:** 30 minutes. **Questions:** 5. **Total marks:** 100 (20 per question).

The scenarios are independent and focus on common Kubernetes troubleshooting
tasks: diagnosing Pod failures, Deployment images, Service endpoints, scheduling,
and readiness probes. The suggested times total 30 minutes.

## Question 1: Recover a crashing Pod

```bash
kubectl describe pod api-crash -n cka-crashloop
kubectl logs api-crash -n cka-crashloop
kubectl delete pod api-crash -n cka-crashloop
kubectl run api-crash -n cka-crashloop \
  --image=busybox:1.37.0 --command -- sh -c 'sleep 3600'
kubectl wait -n cka-crashloop --for=condition=Ready pod/api-crash --timeout=120s
```

The original command exits immediately, so the kubelet restarts the container.
Pod commands cannot be changed in place; recreate the Pod with a long-running
command.

## Question 2: Fix an image pull failure

```bash
kubectl describe pods -n cka-image
kubectl set image deployment/catalog web=nginx:1.27.5 -n cka-image
kubectl rollout status deployment/catalog -n cka-image --timeout=120s
```

The Pod events show that the configured image tag cannot be pulled. Updating the
Deployment template replaces the failing Pods and restores both replicas.

## Question 3: Restore Service endpoints

```bash
kubectl get deployment payments -n cka-service --show-labels
kubectl get service payments -n cka-service -o yaml
kubectl patch service payments -n cka-service \
  --type=merge -p '{"spec":{"selector":{"app":"payments"}}}'
kubectl get endpoints payments -n cka-service
```

The Service selector must match the Pods' `app=payments` label. The Endpoints
resource should then list both Ready Pods.

## Question 4: Fix an unschedulable Deployment

```bash
kubectl describe pods -n cka-scheduling
kubectl patch deployment worker-check -n cka-scheduling \
  --type=merge -p '{"spec":{"template":{"spec":{"nodeSelector":null}}}}'
kubectl rollout status deployment/worker-check -n cka-scheduling --timeout=120s
```

The Pod events report that no node matches the Deployment's node selector.
Removing the invalid selector allows the replacement Pod to schedule normally.

## Question 5: Correct a failing readiness probe

```bash
kubectl describe pods -n cka-readiness
kubectl patch deployment web-check -n cka-readiness --type=strategic \
  -p '{"spec":{"template":{"spec":{"containers":[{"name":"web","readinessProbe":{"httpGet":{"path":"/","port":80}}}]}}}}'
kubectl rollout status deployment/web-check -n cka-readiness --timeout=120s
```

The nginx container serves its default page at `/`, not `/healthz`. The updated
probe receives a successful HTTP response, allowing the Pod to become Ready.
>>>>>>> 353749d2a249621e7ff601bdb32a3c02f9d587e1
