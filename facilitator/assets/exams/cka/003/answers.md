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
