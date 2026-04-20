#!/usr/bin/env bash
# Shared bats helpers for Piko Claude hook tests.

# REPO_ROOT is the repository root (parent of test/).
REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
export REPO_ROOT

# Each test runs under an isolated HOME so audit logs don't leak between cases.
setup_isolated_home() {
  PIKO_TMP_HOME="$(mktemp -d)"
  export HOME="${PIKO_TMP_HOME}"
  export PIKO_ROOT="${HOME}/.piko"
  mkdir -p "${PIKO_ROOT}/hooks" "${PIKO_ROOT}/hooks/lib"
  # Install hook binaries into the isolated PIKO_ROOT so session-start can find them.
  cp "${REPO_ROOT}/hooks/guard.sh" "${PIKO_ROOT}/hooks/guard.sh"
  cp "${REPO_ROOT}/hooks/write-guard.sh" "${PIKO_ROOT}/hooks/write-guard.sh"
  cp "${REPO_ROOT}/hooks/session-start.sh" "${PIKO_ROOT}/hooks/session-start.sh"
  cp "${REPO_ROOT}/hooks/lib/audit.sh" "${PIKO_ROOT}/hooks/lib/audit.sh"
  chmod +x "${PIKO_ROOT}/hooks/"*.sh
}

teardown_isolated_home() {
  if [ -n "${PIKO_TMP_HOME:-}" ] && [ -d "${PIKO_TMP_HOME}" ]; then
    rm -rf "${PIKO_TMP_HOME}"
  fi
  unset PIKO_TMP_HOME
}

# Build a Claude PreToolUse Bash payload for guard.sh.
bash_payload() {
  local cmd="$1"
  jq -cn --arg c "${cmd}" '{tool_input: {command: $c}}'
}

# Build a Claude PreToolUse Write/Edit payload for write-guard.sh.
write_payload() {
  local path="$1"
  jq -cn --arg p "${path}" '{tool_input: {file_path: $p}}'
}

# Pipe a JSON payload into a hook binary and return its exit code. Use this
# instead of `bash -c "$(payload ...) | hook"` which mis-parses JSON as argv.
pipe_to_hook() {
  local payload="$1"
  local hook="$2"
  printf '%s' "${payload}" | "${hook}"
}
