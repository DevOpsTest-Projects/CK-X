# CKAD Quick Practice Test — Solutions

**Duration:** 30 minutes. **Questions:** 5. **Total marks:** 100 (20 per question).

All five namespaces are prepared automatically. The questions are independent.
The suggested times total 30 minutes; the timer applies to the whole test, not
to individual questions. Each question receives its 20 marks when all of its
requirements pass validation.

## Question 1: Create a labeled Pod

```bash
kubectl run web-pod -n quick-pods \
  --image=nginx:1.27.5 --labels=app=web,env=practice
kubectl wait -n quick-pods --for=condition=Ready pod/web-pod --timeout=120s
```

Labels identify the Pod; the readiness check confirms that it is ready before grading.

## Question 2: Create a Deployment with three replicas

```bash
kubectl create deployment frontend -n quick-deployments \
  --image=nginx:1.27.5 --replicas=3
kubectl rollout status deployment/frontend -n quick-deployments --timeout=120s
```

The generated Deployment uses `app=frontend` for its selector and Pod template
label. Waiting for the rollout ensures all three replicas are ready.

## Question 3: Expose the existing backend

```bash
kubectl expose deployment backend -n quick-services \
  --name=backend-svc --type=ClusterIP --port=8080 --target-port=80
kubectl get service backend-svc -n quick-services -o yaml
```

The Service uses the Deployment's `app=backend` selector. Clients connect to
Service port `8080`, which forwards TCP traffic to port `80` on the backend Pods.

## Question 4: Consume a ConfigMap as an environment variable

```bash
kubectl create configmap app-config -n quick-config --from-literal=APP_MODE=practice
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: config-pod
  namespace: quick-config
spec:
  containers:
    - name: app
      image: busybox:1.37.0
      command: ["sh", "-c", "sleep 3600"]
      env:
        - name: APP_MODE
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: APP_MODE
EOF
kubectl wait -n quick-config --for=condition=Ready pod/config-pod --timeout=120s
kubectl exec config-pod -n quick-config -- printenv APP_MODE
```

The final command should print `practice`. `configMapKeyRef` references the
ConfigMap rather than embedding a literal environment value in the Pod.

## Question 5: Run a Job to completion

```bash
kubectl apply -f - <<'EOF'
apiVersion: batch/v1
kind: Job
metadata:
  name: batch-check
  namespace: quick-jobs
spec:
  completions: 1
  parallelism: 1
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: batch
          image: busybox:1.37.0
          command: ["sh", "-c", "echo job-complete"]
EOF
kubectl wait -n quick-jobs --for=condition=Complete job/batch-check --timeout=120s
kubectl logs job/batch-check -n quick-jobs
```

The Job requires one successful completion and runs one Pod at a time.
Keep the completed Job and Pod so the grader can check the status and logs.
