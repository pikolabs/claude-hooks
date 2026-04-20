# claude-hooks

**Internal PikoLabs use only — all rights reserved.**

Org-wide Claude Code policy bundle for PikoLabs engineers. Installs:

- Bash PreToolUse guard (`guard.sh`) — blocks destructive filesystem, credential reads, exfiltration patterns, dangerous git operations, destructive infrastructure, supply-chain pipes, and blockchain-mainnet misuse.
- Write/Edit PreToolUse guard (`write-guard.sh`) — blocks writes to `.env*`, private keys, mainnet deployment manifests, and production infrastructure code. Explicitly allows `.github/workflows/*`.
- SessionStart hook (`session-start.sh`) — validates hook install, policy version, and the `@pikolabs.ai` git email.
- Git `pre-commit` hook — enforces the `@pikolabs.ai` email on every commit, even outside Claude.
- Claude MCP config merge — enables Atlassian and Playwright servers locally. The managed settings in the Claude.ai admin console restrict the org to those two.

## Prerequisites

- macOS or Linux.
- `git`, `jq`, `curl` on `PATH`.
- A Claude Teams seat in the PikoLabs organization.

## Install

The installer is pinned by tag. Verify the SHA-256 of the released bootstrap script before running it. The expected hash for each release is published in this README under **Release hashes** below.

```bash
# Fetch the pinned release
curl -fsSL -o /tmp/piko-bootstrap.sh \
  https://raw.githubusercontent.com/pikolabs/claude-hooks/v1.0.0/bootstrap.sh

# Verify against the expected hash
echo "<paste-expected-sha256>  /tmp/piko-bootstrap.sh" | shasum -a 256 -c -

# Run the installer
bash /tmp/piko-bootstrap.sh v1.0.0
```

If your global `git user.email` does not end in `@pikolabs.ai`, the installer exits with code 3 and prints the command to fix it. Re-run after setting the email.

## Verify

After install, run the sanity smoke tests documented in [docs/smoke.md](docs/smoke.md).

Key quick checks:

```bash
# The policy file is in place.
ls -la ~/.piko/hooks ~/.piko/policy

# The bash guard blocks a canary destructive command.
echo '{"tool_input":{"command":"rm -rf /tmp/__piko-canary"}}' | ~/.piko/hooks/guard.sh
# Expected: exit 2, remediation message to stderr.

# The version file matches the installer tag.
cat ~/.piko/version

# The git pre-commit hook is wired.
git config --global core.hooksPath
# Expected: /Users/<you>/.piko/git-hooks
```

## Break-glass

If a hook blocks legitimate work, set `PIKO_HOOK_BYPASS=1` for the single command. Every bypass is appended to `~/.piko/hook-audit.log` with timestamp, user, working directory, and command. Reviews of this log are a monthly responsibility of the engineering security lead.

```bash
PIKO_HOOK_BYPASS=1 git commit --no-verify -m "WIP"
```

Do not put `PIKO_HOOK_BYPASS` in your shell profile.

## Upgrade

Re-run the installer with a newer tag. The installer is idempotent.

```bash
bash /tmp/piko-bootstrap.sh v1.1.0
```

If the `SessionStart` hook reports a stale version, re-run the installer.

## Policy version

The canonical policy version is the `VERSION` file in this repository. The `SessionStart` hook enforces a `MIN_VERSION` constant compiled into `hooks/session-start.sh`; any installed version older than that constant is rejected until the developer re-runs the bootstrap.

## Contributing

1. Branch off `main`.
2. Add or edit a `.bats` test in `test/` covering the change.
3. Run `shellcheck hooks/*.sh git-hooks/pre-commit bootstrap.sh` and `bats test/` locally.
4. Open a pull request; CI must be green.
5. Merges to `main` are tagged with a semver release by a maintainer.

## Release hashes

Populated at release cut. The release SHA-256 of `bootstrap.sh` must match exactly before the installer is run.

| Tag | `bootstrap.sh` SHA-256 |
| --- | ---------------------- |
| v1.0.0 | _to be populated when the tag is cut_ |
