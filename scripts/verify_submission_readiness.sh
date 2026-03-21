#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

./scripts/verify_docs_readiness.sh
./scripts/capture_public_runtime_evidence.sh

echo "Submission readiness checks passed."
echo "- Docs: PASS"
echo "- Runtime evidence: PASS"
