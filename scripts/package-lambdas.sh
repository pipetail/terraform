#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SRC_DIR="${PROJECT_ROOT}/src"

package_lambda() {
  local lambda_name=$1
  local lambda_dir="${SRC_DIR}/${lambda_name}"
  local output_zip="${SRC_DIR}/${lambda_name}.zip"

  if [ ! -d "${lambda_dir}" ]; then
    echo "Error: Lambda directory ${lambda_dir} does not exist"
    return 1
  fi

  echo "Packaging ${lambda_name}..."

  if [ -f "${output_zip}" ]; then
    rm -f "${output_zip}"
  fi

  cd "${lambda_dir}"

  # Install npm dependencies if package.json exists
  if [ -f "package.json" ]; then
    echo "  - Installing npm dependencies..."
    npm ci --omit=dev --quiet
  fi

  # Normalize timestamps to make zip reproducible (same content = identical zip)
  find . -exec touch -t 202001010000.00 {} +
  # Sort files to ensure deterministic ordering in zip
  find . -type f | LC_ALL=C sort | zip -X -q "${output_zip}" -@

  local size
  size=$(du -h "${output_zip}" | cut -f1)
  echo "  Created ${lambda_name}.zip (${size})"

  cd "${PROJECT_ROOT}"
}

if [ ! -d "${SRC_DIR}" ]; then
  echo "No src/ directory found, nothing to package"
  exit 0
fi

if [ $# -gt 0 ]; then
  for lambda_name in "$@"; do
    package_lambda "$lambda_name"
  done
else
  # Auto-discover all Lambda directories (any directory in src/ with index.mjs or index.js)
  found=false
  for lambda_dir in "${SRC_DIR}"/*/; do
    if [ -f "${lambda_dir}/index.mjs" ] || [ -f "${lambda_dir}/index.js" ]; then
      lambda_name=$(basename "${lambda_dir}")
      package_lambda "$lambda_name"
      found=true
    fi
  done

  if [ "$found" = false ]; then
    echo "No Lambda functions found in src/"
  fi
fi
