#!/usr/bin/env bats

load 'helpers'

setup() {
  setup_isolated_home
  PC="${REPO_ROOT}/git-hooks/pre-commit"
  export GIT_CONFIG_GLOBAL="${HOME}/.gitconfig"
  export GIT_CONFIG_SYSTEM=/dev/null
}

teardown() {
  teardown_isolated_home
}

@test "passes with pikolabs email" {
  git config --global user.email "milos@pikolabs.ai"
  run "${PC}"
  [ "$status" -eq 0 ]
}

@test "blocks with non-pikolabs email" {
  git config --global user.email "outside@example.com"
  run "${PC}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"blocked by PikoLabs"* ]]
}

@test "blocks with unset email" {
  run "${PC}"
  [ "$status" -eq 1 ]
}

@test "bypass allows non-pikolabs email with audit log" {
  git config --global user.email "outside@example.com"
  export PIKO_HOOK_BYPASS=1
  run "${PC}"
  [ "$status" -eq 0 ]
  [ -f "${HOME}/.piko/hook-audit.log" ]
  run grep -c "BYPASS-PRECOMMIT" "${HOME}/.piko/hook-audit.log"
  [ "$status" -eq 0 ]
}
