# CKA Services & Networking — 30-minute test

Lab ID: `cka-003`. Five questions, 20 marks each, 100 total.
The timer applies to the entire test; suggested times are 6 + 7 + 4 + 6 + 7 minutes.

## Syllabus alignment

Aligned with the **Services & Networking** objectives in the official
[CNCF CKA curriculum v1.37](https://github.com/cncf/curriculum/blob/main/CKA_Curriculum_v1.37.pdf),
reviewed November 18, 2026:

| Question | Curriculum objectives |
| --- | --- |
| 1 | ClusterIP, NodePort, LoadBalancer Service types and endpoints; Pod connectivity |
| 2 | Define and enforce NetworkPolicies; connectivity between Pods |
| 3 | Understand and use CoreDNS |
| 4 | Use Ingress controllers and Ingress resources |
| 5 | Use Gateway API to manage ingress traffic |

This is a domain-focused practice test, not a complete certification exam.
LoadBalancer configuration and internal traffic are graded; public/cloud IP
allocation is not. CoreDNS is exercised through service discovery and Pod DNS
troubleshooting, not through editing the cluster-wide Corefile.

## Environment and prerequisites

- One worker node, using the repository's k3d/K3s environment.
- CoreDNS and a CNI that **enforces** NetworkPolicies are required.
- `q0_setup.sh` installs a dedicated Traefik controller in `cka-net-system`,
  with separate IngressClass/GatewayClass `cka-net-traefik`, without making it
  the default IngressClass or modifying K3s's bundled controller.
- Gateway status advertises the controller's internal Service hostname rather
  than waiting for an external load-balancer address.
- Pinned dependencies: Gateway API standard CRDs **v1.2.1** and Traefik Helm
  chart **34.4.1**. These are lab infrastructure versions, not a claim that
  the simulator cluster runs the syllabus's Kubernetes version.
- Warm-up needs access to GitHub, the Traefik Helm repository, and container
  image registries. The 420-second warm-up estimate is separate from the
  30-minute exam and may vary with download speed.
- The existing `prepare-exam-env` runner invokes `q*_setup.sh` sequentially,
  so `q0_setup.sh` precedes question setup. Do not parallelize those scripts
  without preserving that prerequisite.
- Every question uses an isolated namespace. The additional outsider
  namespace belongs only to the NetworkPolicy question.
- Source helpers stay under `scripts/`, so they are included in the exam's
  generated `assets.tar.gz`. Temporary CRD files use `/tmp/exam`.

Setup checks real NetworkPolicy enforcement rather than merely the existence
of the Kubernetes API. Grading checks HTTP traffic, DNS results, ready
EndpointSlice addresses, and current Gateway/HTTPRoute conditions.

## Validation and deployment

From the repository root:

```powershell
node --test facilitator/tests/ckaNetworkingLab.test.cjs
docker compose up -d --build --no-deps facilitator
```

Then refresh the UI and choose **CKA → CKA Services & Networking - 30-Minute Test**.
Rebuilding the facilitator is required because assets are copied into its image.

For offline grading-script regression checks, execute
`facilitator/tests/ckaNetworkingValidators.test.sh` in Bash with `jq` installed.
These mocked checks do not replace an end-to-end run on a real cluster.
