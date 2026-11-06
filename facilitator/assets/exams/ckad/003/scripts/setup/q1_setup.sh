#!/bin/bash
set -euo pipefail

kubectl create namespace quick-pods --dry-run=client -o yaml | kubectl apply -f -
echo "Question 1 namespace is ready."
