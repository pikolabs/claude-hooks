#!/usr/bin/env bash
# Shared audit log helper for Piko Claude Code hooks.
# Sourced by guard.sh and write-guard.sh.

piko_audit_log() {
  local event="$1"
  local detail="$2"
  local log_dir="${HOME}/.piko"
  local log_file="${log_dir}/hook-audit.log"
  mkdir -p "${log_dir}"
  local ts
  ts="$(date -u +%FT%TZ)"
  local user="${USER:-unknown}"
  printf '%s %s user=%s pwd=%s %s\n' "${ts}" "${event}" "${user}" "${PWD}" "${detail}" >> "${log_file}"
}
