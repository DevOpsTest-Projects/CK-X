#!/bin/bash
set -euo pipefail

if ! kubectl get job batch-check -n quick-jobs -o json | jq -e '
  .spec.completions == 1 and
  .spec.parallelism == 1 and
  .spec.template.spec.restartPolicy == "Never" and
  any(.spec.template.spec.containers[]; .image == "busybox:1.37.0") and
  .status.succeeded == 1 and
  any(.status.conditions[]?; .type == "Complete" and .status == "True")
' > /dev/null; then
  echo "batch-check must use busybox:1.37.0, completions=1, parallelism=1, restartPolicy=Never, and complete successfully."
  exit 1
fi
if ! kubectl logs job/batch-check -n quick-jobs | grep -Fxq 'job-complete'; then
  echo "batch-check logs must include the line job-complete."
  exit 1
fi
echo "Job configuration, completion, and output are correct."
