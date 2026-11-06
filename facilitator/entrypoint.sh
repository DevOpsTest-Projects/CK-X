#!/bin/sh
set -eu

find /usr/src/app/assets/exams -type d -name scripts | while IFS= read -r scripts_dir; do
    exam_dir=$(dirname "$scripts_dir")
    echo "Creating tar archive of scripts in $exam_dir"
    tar -czf "$exam_dir/assets.tar.gz" -C "$exam_dir" scripts/
done

echo "Assets created"

# Keep source scripts for repeatable container restarts, then run Node as PID 1.
exec node /usr/src/app/src/app.js
