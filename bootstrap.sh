#!/usr/bin/env bash
# Piko Claude Code hooks bootstrap installer.
#
# Installs the Piko policy bundle into ~/.piko and configures git to use the
# pre-commit email guard globally. Idempotent; safe to re-run.
#
# Usage:
#   bootstrap.sh                    # install the pinned VERSION
#   bootstrap.sh v1.0.0             # install a specific tag
#   PIKO_HOOKS_SRC=/path ./bootstrap.sh   # install from a local checkout (dev)

set -euo pipefail

REPO_URL="${PIKO_HOOKS_REPO:-https://github.com/pikolabs/claude-hooks.git}"
PIKO_ROOT="${HOME}/.piko"
REPO_DIR="${PIKO_ROOT}/repo"
HOOKS_DIR="${PIKO_ROOT}/hooks"
GIT_HOOKS_DIR="${PIKO_ROOT}/git-hooks"
VERSION_FILE="${PIKO_ROOT}/version"
CLAUDE_MCP_FILE="${HOME}/.claude/mcp.json"
REQUESTED_TAG="${1:-}"

log() {
  printf '[piko-bootstrap] %s\n' "$*"
}

fail() {
  printf '[piko-bootstrap] error: %s\n' "$*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "missing required command: $1"
}

for c in git jq curl; do
  require_cmd "${c}"
done

log "creating ${PIKO_ROOT} tree"
mkdir -p "${PIKO_ROOT}" "${HOOKS_DIR}" "${HOOKS_DIR}/lib" "${GIT_HOOKS_DIR}"
chmod 700 "${PIKO_ROOT}"

SOURCE_MODE=""
if [ -n "${PIKO_HOOKS_SRC:-}" ] && [ -d "${PIKO_HOOKS_SRC}" ]; then
  SOURCE_MODE="local"
  SRC_DIR="${PIKO_HOOKS_SRC}"
  log "source: local checkout at ${SRC_DIR}"
else
  SOURCE_MODE="git"
  if [ -d "${REPO_DIR}/.git" ]; then
    log "updating ${REPO_DIR}"
    git -C "${REPO_DIR}" fetch --tags origin
  else
    log "cloning ${REPO_URL} into ${REPO_DIR}"
    git clone "${REPO_URL}" "${REPO_DIR}"
  fi
  local_default="$(cat "${REPO_DIR}/VERSION" | tr -d '[:space:]')"
  tag="${REQUESTED_TAG:-v${local_default}}"
  log "checking out ${tag}"
  git -C "${REPO_DIR}" checkout "${tag}"
  SRC_DIR="${REPO_DIR}"
fi

[ -d "${SRC_DIR}/hooks" ] || fail "source ${SRC_DIR} missing hooks/ — wrong checkout?"

log "installing hook binaries"
install -m 0755 "${SRC_DIR}/hooks/guard.sh" "${HOOKS_DIR}/guard.sh"
install -m 0755 "${SRC_DIR}/hooks/write-guard.sh" "${HOOKS_DIR}/write-guard.sh"
install -m 0755 "${SRC_DIR}/hooks/session-start.sh" "${HOOKS_DIR}/session-start.sh"
install -m 0644 "${SRC_DIR}/hooks/lib/audit.sh" "${HOOKS_DIR}/lib/audit.sh"

log "installing policy and git hook"
mkdir -p "${PIKO_ROOT}/policy"
install -m 0644 "${SRC_DIR}/policy/deny.json" "${PIKO_ROOT}/policy/deny.json"
install -m 0755 "${SRC_DIR}/git-hooks/pre-commit" "${GIT_HOOKS_DIR}/pre-commit"

if [ "${SOURCE_MODE}" = "git" ]; then
  # When installed from git, the guard.sh default POLICY_FILE resolves relative
  # to the hooks dir layout ${SCRIPT_DIR%/hooks}/policy/deny.json. Point it at
  # the copy we installed under PIKO_ROOT so hooks stay self-contained.
  :
fi
export PIKO_POLICY_FILE="${PIKO_ROOT}/policy/deny.json"

log "recording version"
install -m 0644 "${SRC_DIR}/VERSION" "${VERSION_FILE}"
installed_version="$(tr -d '[:space:]' < "${VERSION_FILE}")"

log "setting git core.hooksPath"
git config --global core.hooksPath "${GIT_HOOKS_DIR}"

log "merging MCP config into ${CLAUDE_MCP_FILE}"
mkdir -p "$(dirname "${CLAUDE_MCP_FILE}")"
if [ -f "${CLAUDE_MCP_FILE}" ]; then
  backup="${CLAUDE_MCP_FILE}.piko-bak.$(date -u +%Y%m%dT%H%M%SZ)"
  cp "${CLAUDE_MCP_FILE}" "${backup}"
  log "backed up existing mcp.json to ${backup}"
  jq -s '.[0] * .[1]' "${CLAUDE_MCP_FILE}" "${SRC_DIR}/mcp/mcp.json" > "${CLAUDE_MCP_FILE}.tmp"
  mv "${CLAUDE_MCP_FILE}.tmp" "${CLAUDE_MCP_FILE}"
else
  cp "${SRC_DIR}/mcp/mcp.json" "${CLAUDE_MCP_FILE}"
fi

current_email="$(git config --global user.email 2>/dev/null || true)"
if [[ ! "${current_email}" =~ @pikolabs\.ai$ ]]; then
  printf '[piko-bootstrap] warning: global git user.email is "%s"\n' "${current_email:-<unset>}" >&2
  printf '[piko-bootstrap]          fix: git config --global user.email <you>@pikolabs.ai\n' >&2
  log "install complete, but email mismatch will fail SessionStart and pre-commit until fixed"
  exit 3
fi

log "done. installed version ${installed_version}. hooks at ${HOOKS_DIR}."
log "sanity: echo '{\"tool_input\":{\"command\":\"rm -rf /tmp/__piko-canary\"}}' | ${HOOKS_DIR}/guard.sh"
