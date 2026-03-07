#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  v2_company_pack.sh

Build a company-ready local handoff package for YNX v2.

Outputs:
  - release bundle
  - canonical English specs and runbooks
  - OpenAPI contracts
  - environment template
  - local orchestration scripts
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ROOT="$(cd "$ROOT_DIR/.." && pwd)"
STAMP="$(date +%Y%m%d_%H%M%S)"
OUT_DIR="${YNX_COMPANY_OUT_DIR:-$ROOT_DIR/.company-v2/ynx_v2_company_${STAMP}}"
DOCS_DIR="$OUT_DIR/docs"
OPENAPI_DIR="$OUT_DIR/openapi"
SCRIPTS_DIR="$OUT_DIR/scripts"

mkdir -p "$DOCS_DIR" "$OPENAPI_DIR" "$SCRIPTS_DIR"

"$ROOT_DIR/scripts/v2_testnet_release.sh"

LATEST_RELEASE_DIR="$(find "$ROOT_DIR/.release-v2" -maxdepth 1 -mindepth 1 -type d -name 'ynx_v2_*' | sort | tail -n1)"
if [[ -z "$LATEST_RELEASE_DIR" ]]; then
  echo "No v2 release bundle found under $ROOT_DIR/.release-v2" >&2
  exit 1
fi

cp -R "$LATEST_RELEASE_DIR" "$OUT_DIR/release"
cp "$PROJECT_ROOT/.env.v2.example" "$OUT_DIR/.env.v2.example"

cp "$PROJECT_ROOT/docs/en/YNX_v2_WEB4_SPEC.md" "$DOCS_DIR/"
cp "$PROJECT_ROOT/docs/en/YNX_v2_EXECUTION_PLAN.md" "$DOCS_DIR/"
cp "$PROJECT_ROOT/docs/en/YNX_v2_AI_SETTLEMENT_API.md" "$DOCS_DIR/"
cp "$PROJECT_ROOT/docs/en/YNX_v2_WEB4_API.md" "$DOCS_DIR/"
cp "$PROJECT_ROOT/docs/en/V2_PUBLIC_TESTNET_PLAYBOOK.md" "$DOCS_DIR/"
cp "$PROJECT_ROOT/docs/en/V2_LOCAL_COMPLETE_RUNBOOK.md" "$DOCS_DIR/"
cp "$PROJECT_ROOT/docs/en/V2_ALL_FILES_AND_FUNCTIONS.md" "$DOCS_DIR/"
cp "$PROJECT_ROOT/docs/en/V2_SECURITY_MODEL.md" "$DOCS_DIR/"
cp "$PROJECT_ROOT/docs/en/V2_COMPANY_HANDOFF.md" "$DOCS_DIR/"
cp "$PROJECT_ROOT/docs/en/V2_WEB4_STATUS_AND_NODE_ONBOARDING.md" "$DOCS_DIR/"

cp "$PROJECT_ROOT/infra/openapi/ynx-v2-ai.yaml" "$OPENAPI_DIR/"
cp "$PROJECT_ROOT/infra/openapi/ynx-v2-web4.yaml" "$OPENAPI_DIR/"

cp "$ROOT_DIR/scripts/v2_local_complete.sh" "$SCRIPTS_DIR/"
cp "$ROOT_DIR/scripts/v2_local_compose.sh" "$SCRIPTS_DIR/"
cp "$ROOT_DIR/scripts/v2_testnet_multinode.sh" "$SCRIPTS_DIR/"
cp "$ROOT_DIR/scripts/v2_public_testnet_deploy.sh" "$SCRIPTS_DIR/"
cp "$ROOT_DIR/scripts/v2_validator_bootstrap.sh" "$SCRIPTS_DIR/"
cp "$ROOT_DIR/scripts/v2_role_apply.sh" "$SCRIPTS_DIR/"

cat >"$OUT_DIR/MANIFEST.md" <<'EOF'
# YNX v2 Company Package

This package is the local company-ready handoff set for YNX v2 Web4 public testnet operations.

Contents:

- `release/` — bootstrap artifacts and endpoint snapshots
- `docs/` — canonical English specifications and operator runbooks
- `openapi/` — machine-readable API contracts
- `scripts/` — local orchestration, compose, deploy, and validator bootstrap entrypoints
- `.env.v2.example` — environment template
EOF

if command -v gtar >/dev/null 2>&1; then
  COPYFILE_DISABLE=1 gtar --no-xattrs --no-acls --warning=no-unknown-keyword -czf "${OUT_DIR}.tar.gz" -C "$OUT_DIR" .
else
  COPYFILE_DISABLE=1 tar -czf "${OUT_DIR}.tar.gz" -C "$OUT_DIR" .
fi
shasum -a 256 "${OUT_DIR}.tar.gz" > "${OUT_DIR}.tar.gz.sha256"

echo "DONE"
echo "OUT_DIR=$OUT_DIR"
echo "ARCHIVE=${OUT_DIR}.tar.gz"
echo "SHA256=${OUT_DIR}.tar.gz.sha256"
