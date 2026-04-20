#!/usr/bin/env bash
# SessionStart hook. Validates Piko Claude policy preconditions:
#   - hook binaries present and executable
#   - ~/.piko/version meets minimum required version
#   - git user.email matches @pikolabs.ai
# Exit 0 = allow session; exit 2 = block with remediation.

set -euo pipefail

MIN_VERSION="1.0.0"
PIKO_ROOT="${PIKO_ROOT:-${HOME}/.piko}"
PIKO_HOOKS_DIR="${PIKO_ROOT}/hooks"
VERSION_FILE="${PIKO_ROOT}/version"

require_hook() {
  local name="$1"
  if [ ! -x "${PIKO_HOOKS_DIR}/${name}" ]; then
    {
      echo "error: Piko Claude hook missing or not executable: ${PIKO_HOOKS_DIR}/${name}"
      echo "  fix:   re-run the bootstrap: curl -fsSL https://raw.githubusercontent.com/pikolabs/claude-hooks/v${MIN_VERSION}/bootstrap.sh | bash"
    } >&2
    exit 2
  fi
}

# Version comparison: returns 0 if $1 >= $2, else 1.
# Handles semantic versions without pre-release suffix; treats "-alpha"/"-beta" as older.
version_ge() {
  local a="$1" b="$2"
  local highest
  highest="$(printf '%s\n%s\n' "${a}" "${b}" | sort -V | tail -n 1)"
  [ "${highest}" = "${a}" ]
}

for h in guard.sh write-guard.sh session-start.sh; do
  require_hook "${h}"
done

if [ ! -r "${VERSION_FILE}" ]; then
  {
    echo "error: Piko Claude hook version file missing at ${VERSION_FILE}"
    echo "  fix:   re-run the bootstrap."
  } >&2
  exit 2
fi

local_version="$(tr -d '[:space:]' < "${VERSION_FILE}")"
if ! version_ge "${local_version}" "${MIN_VERSION}"; then
  {
    echo "error: Piko Claude hooks version ${local_version} is older than required ${MIN_VERSION}"
    echo "  fix:   curl -fsSL https://raw.githubusercontent.com/pikolabs/claude-hooks/v${MIN_VERSION}/bootstrap.sh | bash"
  } >&2
  exit 2
fi

email="$(git config user.email 2>/dev/null || true)"
if [[ ! "${email}" =~ @pikolabs\.ai$ ]]; then
  {
    echo "error: git user.email must end with @pikolabs.ai in this repo (got: '${email:-<unset>}')"
    echo "  fix:   git config user.email <you>@pikolabs.ai"
  } >&2
  exit 2
fi

printf '{"policy_version":"%s","piko_env":"%s","status":"ok"}\n' "${local_version}" "${PIKO_ENV:-dev}"
exit 0
