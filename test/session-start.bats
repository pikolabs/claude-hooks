#!/usr/bin/env bats

load 'helpers'

setup() {
  setup_isolated_home
  SS="${REPO_ROOT}/hooks/session-start.sh"
  # Fake a per-user git config scope for these tests.
  export GIT_CONFIG_GLOBAL="${HOME}/.gitconfig"
  export GIT_CONFIG_SYSTEM=/dev/null
  git config --global user.email "someone@pikolabs.ai"
}

teardown() {
  teardown_isolated_home
}

write_version() {
  printf '%s' "$1" > "${HOME}/.piko/version"
}

@test "happy path with correct version and email" {
  write_version "1.0.0"
  run "${SS}"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"policy_version":"1.0.0"'* ]]
}

@test "fails with stale version" {
  write_version "0.9.0"
  run "${SS}"
  [ "$status" -eq 2 ]
  [[ "$output" == *"older than required"* ]]
}

@test "fails with missing version file" {
  rm -f "${HOME}/.piko/version"
  run "${SS}"
  [ "$status" -eq 2 ]
  [[ "$output" == *"version file missing"* ]]
}

@test "fails with wrong email domain" {
  write_version "1.0.0"
  git config --global user.email "someone@example.com"
  run "${SS}"
  [ "$status" -eq 2 ]
  [[ "$output" == *"pikolabs.ai"* ]]
}

@test "fails with missing email" {
  write_version "1.0.0"
  rm -f "${HOME}/.gitconfig"
  run "${SS}"
  [ "$status" -eq 2 ]
}

@test "fails when guard.sh missing" {
  write_version "1.0.0"
  rm -f "${HOME}/.piko/hooks/guard.sh"
  run "${SS}"
  [ "$status" -eq 2 ]
  [[ "$output" == *"hook missing"* ]]
}

@test "accepts a future version (1.1.0) as >= min 1.0.0" {
  write_version "1.1.0"
  run "${SS}"
  [ "$status" -eq 0 ]
}
