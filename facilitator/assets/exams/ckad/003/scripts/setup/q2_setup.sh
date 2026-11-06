#!/bin/bash
set -euo pipefail

kubectl create namespace quick-deployments --dry-run=client -o yaml | kubectl apply -f -
echo "Question 2 namespace is ready."
