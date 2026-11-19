#!/bin/bash
set -euo pipefail

# The repository's prepare-exam-env runs q*_setup.sh sequentially in glob order.
# q0 provisions shared ingress infrastructure before independent question setup.
source "$(dirname "$0")/../common.sh"
create_namespace cka-net-system
mkdir -p /tmp/exam
curl --fail --location --retry 3 \
  https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.1/config/crd/standard/gateway.networking.k8s.io_gatewayclasses.yaml \
  -o /tmp/exam/cka-net-gatewayclasses.yaml
curl --fail --location --retry 3 \
  https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.1/config/crd/standard/gateway.networking.k8s.io_gateways.yaml \
  -o /tmp/exam/cka-net-gateways.yaml
curl --fail --location --retry 3 \
  https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.1/config/crd/standard/gateway.networking.k8s.io_httproutes.yaml \
  -o /tmp/exam/cka-net-httproutes.yaml
curl --fail --location --retry 3 \
  https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.1/config/crd/standard/gateway.networking.k8s.io_referencegrants.yaml \
  -o /tmp/exam/cka-net-referencegrants.yaml
curl --fail --location --retry 3 \
  https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.1/config/crd/standard/gateway.networking.k8s.io_grpcroutes.yaml \
  -o /tmp/exam/cka-net-grpcroutes.yaml
kubectl apply --server-side -f /tmp/exam/cka-net-gatewayclasses.yaml \
  -f /tmp/exam/cka-net-gateways.yaml -f /tmp/exam/cka-net-httproutes.yaml \
  -f /tmp/exam/cka-net-referencegrants.yaml -f /tmp/exam/cka-net-grpcroutes.yaml
for crd in gatewayclasses gateways httproutes referencegrants grpcroutes; do
  kubectl wait --for=condition=Established "crd/$crd.gateway.networking.k8s.io" --timeout=60s
done

helm repo add cka-net-traefik https://traefik.github.io/charts --force-update
helm repo update cka-net-traefik
helm upgrade --install cka-net-traefik cka-net-traefik/traefik \
  --version 34.4.1 --namespace cka-net-system \
  --set providers.kubernetesCRD.enabled=false \
  --set providers.kubernetesIngress.enabled=true \
  --set providers.kubernetesIngress.ingressClass=cka-net-traefik \
  --set providers.kubernetesGateway.enabled=true \
  --set providers.kubernetesGateway.statusAddress.service.enabled=false \
  --set providers.kubernetesGateway.statusAddress.hostname=cka-net-traefik.cka-net-system.svc.cluster.local \
  --set ingressClass.enabled=true \
  --set ingressClass.isDefaultClass=false \
  --set ingressClass.name=cka-net-traefik \
  --set gateway.enabled=false \
  --set gatewayClass.enabled=true \
  --set gatewayClass.name=cka-net-traefik \
  --set service.type=ClusterIP \
  --set resources.requests.cpu=100m \
  --set resources.requests.memory=64Mi \
  --set resources.limits.memory=256Mi \
  --wait --timeout=240s
kubectl wait gatewayclass/cka-net-traefik --for=condition=Accepted --timeout=90s
echo "CKA networking Ingress and Gateway API controller is ready."
