#!/usr/bin/env bats

load 'helpers'

setup() {
  setup_isolated_home
  PC="${REPO_ROOT}/git-hooks/pre-commit"
  export GIT_CONFIG_GLOBAL="${HOME}/.gitconfig"
  export GIT_CONFIG_SYSTEM=/dev/null
  # Each test runs inside a disposable pikolabs-origin repo by default.
  REPO_DIR="$(mktemp -d)"
  cd "${REPO_DIR}"
  git init -q
  git remote add origin https://github.com/pikolabs/claude-hooks.git
}

teardown() {
  cd /
  rm -rf "${REPO_DIR}"
  teardown_isolated_home
}

make_non_piko_repo() {
  git remote remove origin
  git remote add origin https://github.com/milorad-teodorovic/personal.git
}

make_no_remote_repo() {
  git remote remove origin
}

@test "passes with pikolabs email in pikolabs repo" {
  git config --global user.email "milos@pikolabs.ai"
  run "${PC}"
  [ "$status" -eq 0 ]
}

@test "blocks non-pikolabs email in pikolabs repo" {
  git config --global user.email "outside@example.com"
  run "${PC}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"blocked by PikoLabs"* ]]
}

@test "blocks unset email in pikolabs repo" {
  run "${PC}"
  [ "$status" -eq 1 ]
}

@test "skips enforcement in non-pikolabs repo" {
  make_non_piko_repo
  git config --global user.email "outside@example.com"
  run "${PC}"
  [ "$status" -eq 0 ]
}

@test "skips enforcement when repo has no origin remote" {
  make_no_remote_repo
  git config --global user.email "outside@example.com"
  run "${PC}"
  [ "$status" -eq 0 ]
}

@test "enforces on SSH alias form (github-piko:pikolabs/*)" {
  git remote remove origin
  git remote add origin git@github-piko:pikolabs/insurance.git
  git config --global user.email "outside@example.com"
  run "${PC}"
  [ "$status" -eq 1 ]
}

@test "bypass allows non-pikolabs email in pikolabs repo with audit log" {
  git config --global user.email "outside@example.com"
  export PIKO_HOOK_BYPASS=1
  run "${PC}"
  [ "$status" -eq 0 ]
  [ -f "${HOME}/.piko/hook-audit.log" ]
  run grep -c "BYPASS-PRECOMMIT" "${HOME}/.piko/hook-audit.log"
  [ "$status" -eq 0 ]
}
