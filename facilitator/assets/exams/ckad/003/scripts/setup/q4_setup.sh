#!/bin/bash
set -euo pipefail

kubectl create namespace quick-config --dry-run=client -o yaml | kubectl apply -f -
echo "Question 4 namespace is ready."
