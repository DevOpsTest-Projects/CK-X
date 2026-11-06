#!/bin/bash
set -euo pipefail

kubectl create namespace quick-jobs --dry-run=client -o yaml | kubectl apply -f -
echo "Question 5 namespace is ready."
