# Manual smoke tests

Run these once per seat after install, and before every admin-console rollout phase.

## 1. Offline hard-fail

1. Disable network.
2. Launch `claude` in any repo.
3. Expected: the CLI exits with a message about being unable to fetch managed settings.

## 2. Destructive command block

```bash
echo '{"tool_input":{"command":"rm -rf /tmp/__piko-canary"}}' | ~/.piko/hooks/guard.sh
```

Expected: exit code `2`, stderr contains `blocked by PikoLabs Claude policy`.

## 3. Protected-path write block

```bash
echo '{"tool_input":{"file_path":"/tmp/.env.test"}}' | ~/.piko/hooks/write-guard.sh
```

Expected: exit code `2`. Then:

```bash
echo '{"tool_input":{"file_path":"/tmp/.github/workflows/ci.yml"}}' | ~/.piko/hooks/write-guard.sh
```

Expected: exit code `0` (workflows explicitly allowed).

## 4. MCP allow-list

Open the Claude MCP panel and confirm only `atlassian` and `playwright` load. Attempting to enable a server not in the managed allow-list must fail.

## 5. Wrong-email commit block

```bash
mkdir -p /tmp/piko-canary && cd /tmp/piko-canary && git init
git -c user.email=outside@example.com commit --allow-empty -m test
```

Expected: the commit is rejected by the Piko `pre-commit` hook.

Record results in your rollout runbook signoff.
