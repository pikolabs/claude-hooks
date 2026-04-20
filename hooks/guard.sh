#!/usr/bin/env bash
# PreToolUse Bash guard. Blocks commands that match any pattern in policy/deny.json.
# Exit 0 = allow, exit 2 = block (Claude Code treats this as a blocking error).
# Set PIKO_HOOK_BYPASS=1 to override; the attempt is logged to ~/.piko/hook-audit.log.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# Sibling layout: hooks/guard.sh + hooks/lib/audit.sh + policy/deny.json at repo root (or install root).
POLICY_FILE="${PIKO_POLICY_FILE:-${SCRIPT_DIR%/hooks}/policy/deny.json}"
# shellcheck source=hooks/lib/audit.sh
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/audit.sh"

payload="$(cat)"

if ! command -v jq >/dev/null 2>&1; then
  echo "error: jq not found on PATH (required by Piko Claude hooks). Install via 'brew install jq' or 'apt-get install jq'." >&2
  exit 2
fi

if [ ! -r "${POLICY_FILE}" ]; then
  echo "error: policy file not readable: ${POLICY_FILE}. Re-run the Piko bootstrap script." >&2
  exit 2
fi

cmd="$(printf '%s' "${payload}" | jq -r '.tool_input.command // empty')"
if [ -z "${cmd}" ]; then
  exit 0
fi

while IFS=$'\t' read -r label pattern; do
  if [ -z "${pattern}" ]; then
    continue
  fi
  if [[ "${cmd}" =~ ${pattern} ]]; then
    if [ "${PIKO_HOOK_BYPASS:-0}" = "1" ]; then
      piko_audit_log "BYPASS" "label=${label} cmd=$(printf '%s' "${cmd}" | tr '\n' ' ')"
      exit 0
    fi
    piko_audit_log "DENY" "label=${label} cmd=$(printf '%s' "${cmd}" | tr '\n' ' ')"
    {
      echo "error: blocked by PikoLabs Claude policy"
      echo "  rule:    ${label}"
      echo "  command: ${cmd}"
      echo "  override: set PIKO_HOOK_BYPASS=1 if you have explicit authorization (audit-logged)."
    } >&2
    exit 2
  fi
done < <(jq -r '.patterns[] | "\(.label)\t\(.pattern)"' "${POLICY_FILE}")

exit 0
