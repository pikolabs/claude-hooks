#!/usr/bin/env bats

load 'helpers'

setup() {
  setup_isolated_home
  WG="${REPO_ROOT}/hooks/write-guard.sh"
}

teardown() {
  teardown_isolated_home
}

@test "allows a normal source file" {
  run pipe_to_hook "$(write_payload '/repo/server/internal/foo.go')" "${WG}"
  [ "$status" -eq 0 ]
}

@test "allows .github/workflows/ci.yml explicitly" {
  run pipe_to_hook "$(write_payload '/repo/.github/workflows/ci.yml')" "${WG}"
  [ "$status" -eq 0 ]
}

@test "blocks .env write" {
  run pipe_to_hook "$(write_payload '/repo/.env')" "${WG}"
  [ "$status" -eq 2 ]
}

@test "blocks .env.production write" {
  run pipe_to_hook "$(write_payload '/repo/.env.production')" "${WG}"
  [ "$status" -eq 2 ]
}

@test "blocks nested .env file" {
  run pipe_to_hook "$(write_payload '/repo/server/.env.local')" "${WG}"
  [ "$status" -eq 2 ]
}

@test "blocks *.pem write" {
  run pipe_to_hook "$(write_payload '/repo/secrets/prod.pem')" "${WG}"
  [ "$status" -eq 2 ]
}

@test "blocks *.key write" {
  run pipe_to_hook "$(write_payload '/repo/secrets/sign.key')" "${WG}"
  [ "$status" -eq 2 ]
}

@test "blocks contracts mainnet deployment file" {
  run pipe_to_hook "$(write_payload '/repo/contracts/deployments/mainnet.json')" "${WG}"
  [ "$status" -eq 2 ]
}

@test "blocks pulumi prod directory" {
  run pipe_to_hook "$(write_payload '/repo/infra/pulumi/prod/stack.yaml')" "${WG}"
  [ "$status" -eq 2 ]
}

@test "blocks contracts/keys/ directory" {
  run pipe_to_hook "$(write_payload '/repo/contracts/keys/mainnet.json')" "${WG}"
  [ "$status" -eq 2 ]
}

@test "bypass allows .env.production write with audit entry" {
  export PIKO_HOOK_BYPASS=1
  run pipe_to_hook "$(write_payload '/repo/.env.production')" "${WG}"
  [ "$status" -eq 0 ]
  [ -f "${HOME}/.piko/hook-audit.log" ]
  run grep -c "BYPASS-WRITE" "${HOME}/.piko/hook-audit.log"
  [ "$status" -eq 0 ]
}

@test "empty file_path allowed (no-op)" {
  run pipe_to_hook "$(write_payload '')" "${WG}"
  [ "$status" -eq 0 ]
}
