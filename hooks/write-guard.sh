#!/usr/bin/env bash
# PreToolUse Write/Edit guard. Blocks writes to protected paths.
# Allows .github/workflows/* explicitly.
# Exit 0 = allow, exit 2 = block.
# Set PIKO_HOOK_BYPASS=1 to override; logged.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=hooks/lib/audit.sh
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/audit.sh"

payload="$(cat)"

if ! command -v jq >/dev/null 2>&1; then
  echo "error: jq not found on PATH (required by Piko Claude hooks)." >&2
  exit 2
fi

file_path="$(printf '%s' "${payload}" | jq -r '.tool_input.file_path // empty')"
if [ -z "${file_path}" ]; then
  exit 0
fi

# Explicit allow: GitHub workflows stay editable.
case "${file_path}" in
  */.github/workflows/*|.github/workflows/*)
    exit 0
    ;;
esac

# Deny patterns. Each entry: "label:glob"
deny=(
  "env-file:*/.env"
  "env-file:*.env"
  "env-file:*/.env.*"
  "env-file:*.env.*"
  "pem-file:*.pem"
  "key-file:*.key"
  "p12-file:*.p12"
  "jks-file:*.jks"
  "mainnet-deploy:*/contracts/deployments/mainnet.json"
  "pulumi-prod:*/infra/pulumi/prod/*"
  "contract-keys:*/contracts/keys/*"
)

for entry in "${deny[@]}"; do
  label="${entry%%:*}"
  glob="${entry#*:}"
  # shellcheck disable=SC2053
  if [[ "${file_path}" == ${glob} ]]; then
    if [ "${PIKO_HOOK_BYPASS:-0}" = "1" ]; then
      piko_audit_log "BYPASS-WRITE" "label=${label} path=${file_path}"
      exit 0
    fi
    piko_audit_log "DENY-WRITE" "label=${label} path=${file_path}"
    {
      echo "error: blocked by PikoLabs Claude policy (write-guard)"
      echo "  rule: ${label}"
      echo "  path: ${file_path}"
      echo "  override: set PIKO_HOOK_BYPASS=1 if you have explicit authorization (audit-logged)."
    } >&2
    exit 2
  fi
done

exit 0
