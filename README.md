# pi-less-yolo

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![pi version](https://img.shields.io/badge/pi--coding--agent-0.84.3-blueviolet)](https://github.com/earendil-works/pi/tree/main/packages/coding-agent)
[![Base Image](https://img.shields.io/badge/base%20image-chainguard%2Fnode-F4835E?logo=docker)](https://images.chainguard.dev/directory/image/node/overview)
[![Dependabot](https://img.shields.io/badge/Dependabot-enabled-brightgreen?logo=dependabot)](https://github.com/cjermain/pi-less-yolo/blob/main/.github/dependabot.yml)
[![mise](https://mise-versions.jdx.dev/badge.svg)](https://mise.jdx.dev)
[![CI](https://img.shields.io/github/actions/workflow/status/cjermain/pi-less-yolo/ci.yml?style=flat&label=CI)](https://github.com/cjermain/pi-less-yolo/actions/workflows/ci.yml)

> Run [pi-coding-agent](https://github.com/earendil-works/pi/tree/main/packages/coding-agent) (a multi-provider AI coding agent supporting Claude, GPT, Gemini, and [many more](https://github.com/earendil-works/pi/tree/main/packages/coding-agent#providers--models)) inside an isolated Docker container — limiting the blast radius of agent-driven changes to your mounted working directory.

![pi-less-yolo demo: filesystem isolation proof and AI-assisted bug fix](docs/demo.gif)

A [mise](https://mise.jdx.dev) shim that wraps the **pi** AI coding agent in a [Chainguard](https://chainguard.dev)-based container with your current directory and `~/.pi/agent` volume-mounted — and nothing else.

Pi defaults to running with full access to your filesystem. This repo constrains it so the agent cannot touch files outside your project, cannot escalate privileges, and runs as your own user.

A second agent, **omp** ([oh-my-pi](https://github.com/can1357/oh-my-pi) — a different
project, not a version of pi), is wrapped the same way under the `omp:` tasks. Both
share one set of hardening flags. See [omp (oh-my-pi)](#omp-oh-my-pi).

> **This is "less YOLO", not "no YOLO".** Container escapes exist. The mounted directories are fully writable. This is a meaningful reduction in risk, not a security guarantee.

## Why use this?

AI coding agents are powerful — and dangerous. A hallucinating model, a misunderstood instruction, or a runaway loop can delete, overwrite, or exfiltrate files anywhere on your machine. `pi-less-yolo` gives you a practical safety net:

- **Filesystem isolation** — the agent can only read and write your current project directory.
- **No privilege escalation** — all Linux capabilities are dropped; `no-new-privileges` is set.
- **Reproducible environment** — a pinned, minimal Chainguard Node image with only the tools pi needs.
- **Zero friction** — one `mise run pi` command from any project; no manual Docker incantations.

If you use [Claude Code](https://docs.anthropic.com/en/docs/claude-code), Aider, Cursor, or any other LLM-based coding assistant and want sandboxed execution, this pattern applies to you.

## Prerequisites

- [mise](https://mise.jdx.dev/installing-mise.html) >= 2024.12.0
- [Docker](https://docs.docker.com/get-docker/) (Desktop on macOS, Engine on Linux) or [Podman](https://podman.io/getting-started/installation) (via `PI_CONTAINER_RUNTIME=podman`, the `podman-docker` package, or a symlink)
- git

## Install

```bash
git clone https://github.com/cjermain/pi-less-yolo.git
cd pi-less-yolo
mise run install
```

`install` writes a single file — `~/.config/mise/conf.d/pi-less-yolo.toml` — that points mise at the `tasks/` directory in the cloned repo. The `pi:` and `omp:` tasks become available globally from any directory. The repo must stay at the cloned path; if you move it, re-run `mise run install`.

Then build the image for whichever agent you want (one-time, ~2 minutes each):

```bash
mise run pi:build     # the pi agent
mise run omp:build    # the omp (oh-my-pi) agent — only if you want it
```

You don't need both. Each run task builds its own image on first use if it is missing.

## Usage

Run pi from any project directory:

```bash
cd ~/my-project
mise run pi
```

Your current directory is mounted at its real path inside the container (e.g. `/home/you/my-project`). Pi uses this path for session tracking, so each project gets its own session history. Pi's config, sessions, and credentials are mounted from `~/.pi/agent`. Files written by the agent are owned by your user on the host.

### Non-interactive use

Pi's `-p` flag runs a single prompt and exits. All arguments after `--` are passed through to pi:

```bash
mise run pi -- -p "summarize this repo"
```

Piped stdin is also supported:

```bash
cat README.md | mise run pi -- -p "summarize this"
git diff | mise run pi -- -p "write a commit message for this diff"
```

This works with `pi:readonly` too:

```bash
cat src/auth.ts | mise run pi:readonly -- -p "review for security issues"
```

### Alias (optional)

To type `pi` instead of `mise run pi`, add to your shell profile:

```bash
alias pi='mise run pi'
```

> **Task name collision warning:** If any project you work in defines its own `pi` mise task, the project-local task will take precedence over the global one inside that directory. Run `mise tasks --global` to confirm which `pi` task is active.

## Available mise tasks

| Task | Description |
|---|---|
| `mise run pi` | Run the pi AI coding agent in the sandboxed container |
| `mise run pi:pi-acp` | Run pi-acp to provide Agent Client Protocol (ACP) stdio connection for IDE's to connect (same mounts as pi)|
| `mise run pi:readonly` | Run pi with the project directory mounted read-only and file-modification tools disabled |
| `mise run pi:build` | Build or rebuild the Docker container image |
| `mise run pi:shell` | Open a bash shell in the container (same mounts as `pi`) |
| `mise run pi:upgrade` | Upgrade pi to the latest npm release and rebuild |
| `mise run pi:health` | Check the setup for common problems |
| `mise run pi:egress-build` | Build or rebuild the egress proxy image used by `PI_EGRESS=proxy` |
| `mise run omp` | Run the omp (oh-my-pi) coding agent in the sandboxed container |
| `mise run omp:readonly` | Run omp with the project directory mounted read-only and write tools disabled |
| `mise run omp:yolo` | Run omp in yolo mode with the egress allowlist on and a git-recoverability warning |
| `mise run omp:build` | Build or rebuild the omp container image |
| `mise run omp:shell` | Open a bash shell in the omp container (same mounts as `omp`) |

## omp (oh-my-pi)

[oh-my-pi](https://github.com/can1357/oh-my-pi) is a separate coding agent — a fork
of Mario Zechner's pi-mono, not the same project as the `pi` this repo wraps. It runs
in the same sandbox under its own image and task namespace:

```bash
cd ~/my-project
mise run omp
```

Both agents can be installed side by side. They share `tasks/pi/_docker_flags`
verbatim, so every hardening flag, mount guard, and key-forwarding rule documented
under [Security model](#security-model) applies identically to `omp`. What differs:

| | `pi` | `omp` |
|---|---|---|
| Image | `pi-less-yolo:latest` (Chainguard Node) | `omp-less-yolo:latest` (Bun) |
| Host state | `~/.pi/agent` → `/pi-agent` | `~/.omp` → `/home/ompuser/.omp` |
| Container `$HOME` | `/home/piuser` | `/home/ompuser` |
| Version pin | `Dockerfile` | `Dockerfile.omp` |
| Approval default | n/a | lowered from `yolo` to `write` ([below](#approval-mode)) |
| Command denylist | n/a | `bash.patterns` in the baked overlay ([below](#safer-yolo-ompyolo)) |
| Read-only tools | `read,grep,find,ls` | `read,grep,glob,ast_grep` |

State is kept separate on purpose: the two agents use incompatible config formats
and session layouts, so `mise run omp` will not see your pi sessions or auth, and
you will need to authenticate omp separately.

There is no `omp:upgrade` or `omp:health` task — `pi:health` checks the pi setup
only. Bump the omp pins by editing `Dockerfile.omp` (Renovate opens PRs for both
`@oh-my-pi/*` packages) and running `mise run omp:build`.

> **After an omp upgrade, re-run `mise run test:omp`.** Both the approval floor and the
> denylist depend on omp internals — the tier semantics in `resolveApproval` and the glob
> matcher in `bash.ts`, neither of which is a public API. The tests assert the observable
> behaviour, so a release that changes it fails there rather than silently in a session.

### Language servers

omp has an `lsp` tool but ships no servers with it: its defaults declare ~53 of them
as a command name plus arguments, and it starts the ones whose binary it can find on
`$PATH` and whose root markers match your project. A server that is not installed is
skipped without a word, and nothing inside the container can install one — the runtime
UID has no root and no package manager.

The image therefore carries them, pinned in `Dockerfile.omp` alongside the agent:

| Language | Server | Starts when the project has |
|---|---|---|
| TypeScript / JavaScript | `typescript-language-server` (on TypeScript 5.x) | `package.json`, a lockfile |
| Python | `basedpyright` + `ruff` | `pyproject.toml`, `requirements.txt`, `setup.py` |
| Lua | `lua-language-server` | `.luarc.json`, `.luacheckrc`, `stylua.toml` |
| Bash | `bash-language-server` (with `shellcheck` and `shfmt`) | any git repo |
| YAML | `yaml-language-server` | any git repo |
| JSON / HTML / CSS | `vscode-langservers-extracted` | any git repo |
| Dockerfile | `docker-langserver` | a `Dockerfile` |
| Ansible | `ansible-language-server` (with `ansible-lint`) | `ansible.cfg`, `.ansible-lint`, `galaxy.yml`, `playbooks/`, `roles/` |

A project's own tooling still wins where it exists: omp checks `node_modules/.bin` and
`.venv/bin` before `$PATH`, so a repo pinning its own `typescript` or `ruff` gets that
one, and these are the fallback.

Ansible is the one that needed more than a package. The
[vscode-ansible](https://github.com/ansible/vscode-ansible) server has no entry in omp's
defaults, so `omp-lsp.yml` — baked in at `$HOME/.lsp.yml`, the lowest-priority config
location, so any project `lsp.json` still overrides it — adds one and points it at the
`ansible-lint`, `ansible-doc`, and `ansible-playbook` in `/opt/omp-python`. Only
`ansible-core` is installed, not the full `ansible` distribution with its ~1 GB of
bundled collections; `ansible-galaxy install` into the workspace for anything a playbook
actually needs. Execution environments are turned off — they would need a container
runtime, which this sandbox deliberately does not expose.

The servers add roughly 350 MB to the image. `mise run test:omp` asserts each one still
resolves, which is the check that catches an upstream rename after a version bump.

### Approval mode

omp ships with `tools.approvalMode: yolo`, which auto-approves its `exec` tier —
shelling out, driving a browser, spawning subagents — with no prompt. This image
lowers that floor to `write`: reads and writes are still automatic, `exec` prompts.

It is applied as a read-only `PI_CONFIG_FILES` overlay baked into the image
(`omp-hardened.yml`), which also carries a `bash.patterns` denylist for commands with no
legitimate use in this sandbox. The overlay takes effect without touching your own
`config.yml` — and **outranks it**: a `config.yml` setting `approvalMode: yolo` and
`patterns: []` does not override it. That matters because the agent can write to its own
state directory, so a self-relaxing config would otherwise be one injected command away.

Changing **Tool Approval** in `/settings` is therefore inert — the write persists to
`~/.omp/agent/config.yml` and is then outranked, so the row snaps back to `Write` and
`omp config set tools.approvalMode yolo` answers `✔ Set tools.approvalMode = write`. Use
one of the opt-outs below instead.

The mode is not the only way over that floor. `resolveApproval` consults the per-tool
`tools.approval` map *before* it compares a tool's tier against the mode, so three lines
of `config.yml` —

```yaml
tools:
  approval:
    bash: allow
```

— would auto-approve bash in `write` mode. Same reach as the mode switch: `/settings`
("Tool Approval Policies"), `omp config set`, or the agent writing its own state dir. The
overlay closes it by pinning every built-in to `inherit`, which is not one of omp's three
policies — `normalizePolicy` drops unrecognised values, so the mode decides again. Pinning
`prompt` would have been wrong in both directions: it prompts per command under `--yolo`
(where a user policy *is* honoured), and it prompts on every read, since the map is
consulted before the tier is. Two gaps remain by construction: MCP and plugin tools mint
their names at runtime and cannot be listed, and a tool added by a future omp release is
unpinned until `omp-hardened.yml` names it — `mise run test:omp` fails when that happens.

Opt back out per session:

```bash
mise run omp:yolo                           # yolo, hardened — see below
mise run omp -- --yolo                      # upstream behaviour, hardened floor only
mise run omp -- --approval-mode always-ask  # prompt for writes too
```

> **Why this differs from `pi`.** omp's tool set is much broader — `browser`,
> `computer`, `eval`, `task` (subagents). Those are not disabled here, but with
> `exec` gated behind a prompt they cannot fire unattended. The `computer` tool is
> disabled upstream by default and nothing here enables it.

### Safer yolo (`omp:yolo`)

Yolo with the controls that still function underneath it. Built for **unattended** use —
you start it and walk away, and it never stops to ask you anything:

```bash
mise run omp:yolo
```

**What `--yolo` costs you** is more than skipped prompts. It also disarms omp's own
`CRITICAL_BASH_PATTERNS` net — those rules return `override: true` with no explicit
policy, and `resolveApproval` ignores override-based prompts in yolo by design. So
`rm -rf /` is auto-approved under plain `--yolo`, where `write` would have prompted.

**What still applies**, verified against omp 17.2.7's own resolver:

| | `write` | `yolo` |
|---|---|---|
| `tools.approvalMode` floor | exec prompts | ignored |
| `CRITICAL_BASH_PATTERNS` | prompt | **allow** |
| `bash.patterns` `deny` | deny | **deny** |
| a `tools.approval` policy | honoured, ahead of the mode | honoured, ahead of the mode |

The last row is why the overlay pins those per-tool policies: it is the one input that
outranks the mode in *both* columns, so leaving it open would leave a `bash: allow` in
`config.yml` deciding the outcome.

A user-supplied `deny` rule carries an explicit policy, which short-circuits before the
yolo branch is reached. That is the entire mechanism this task rests on.

**Every rule is `deny`, never `prompt`** — deliberately, and it is what makes unattended
operation work. Under `--yolo` a `bash.patterns` `prompt` rule is the *only* remaining
thing that can request approval, so one would stop the session with nobody there to
answer. In `write` mode a `prompt` rule is a no-op anyway, since bash is exec-tier and
already prompts for everything. Allow and deny are the only two useful states.

Two files, layered:

| File | Applies to | Contents |
|---|---|---|
| `omp-hardened.yml` | every omp task | approval floor and the per-tool pins that keep it standing, plus denies for what is never legitimate: absolute-path `rm -rf`, `mkfs`, `dd` to a device, `curl … \| sh` |
| `omp-yolo.yml` | `omp:yolo` only | all of the above, plus what only unattended operation rules out: `git push --force`, `git reset --hard`, history rewrites, and the global installs that persist into `~/.omp` |

`PI_CONFIG_FILES` layering replaces arrays rather than merging them, so `omp-yolo.yml`
restates every rule; `mise run test:omp` asserts it stays a superset and contains no
`prompt` rule. Maps are the other case — they merge per key, so the `tools.approval` pins
from `omp-hardened.yml` carry over here without being restated.

> **The overlay outranks your own config**, which is the point. A `~/.omp/agent/config.yml`
> setting `patterns: []`, `approvalMode: yolo`, or `approval: {bash: allow}` does *not*
> override it — verified. That matters because the agent can write to its own state
> directory, so a self-relaxing config would otherwise be one injected command away.
>
> The flip side: you cannot relax a rule you find too strict from your config either — nor
> tighten one, since the pins outrank `browser: deny` exactly as they outrank
> `browser: allow`. Drop a tool with `--tools`, edit `omp-yolo.yml` and run
> `mise run omp:build`, or use `mise run omp -- --yolo` for upstream behaviour with only
> the hardened floor.

**The task adds two things** on top:

- **The egress allowlist, defaulted on** — `PI_EGRESS=proxy` unless you set it otherwise.
  This is the only one of the three an injected session cannot argue its way around, since
  it is enforced by routing rather than by the agent. `PI_EGRESS=off` restores plain yolo.
  Note it costs you `browser` and `fetch` for anything unlisted; see
  [Network egress](#network-egress-pi_egress).
- **A recoverability warning** naming uncommitted changes, unpushed commits, or a missing
  upstream — the exposure yolo creates that no network boundary can address:

  ```console
  $ mise run omp:yolo
  warning: yolo mode can destroy the following irrecoverably:
           - 16 uncommitted change(s)
           Commit and push first if you want a fallback.
  ```

  Warn-only, deliberately. A hard block would be bypassed, and the point is to make the
  exposure visible at the moment it is accepted.

#### What a block looks like

From an unattended run against a scratch repo — the session continued past both without
stopping:

```console
$ mkfs.ext4 /dev/does-not-exist
Tool "bash" is blocked by user policy.
To allow: remove "tools.approval.bash: deny" from config.

$ curl -sS --max-time 10 https://ifconfig.me
curl: (56) CONNECT tunnel failed, response 403
```

> **That first message is wrong, and it is upstream's.** There is no
> `tools.approval.bash: deny` in any config here, so following the advice finds nothing to
> remove. The block came from a `bash.patterns` rule, which omp's resolver reports as
> `source: "tool"` with `reason: "Blocked by bash pattern: …"` — the runtime takes the
> user-policy branch instead and discards the reason. Enforcement is correct; only the
> explanation is misattributed. Check `omp-yolo.yml` for the rule that actually fired.

> **This does not make yolo safe.** The pattern list is glob-matched, case-sensitive, and
> literal, so `eval`, variable indirection (`R=rm; $R -rf /`), and base64 round-trips all
> evade it — treat it as a guard against accidents and unsubtle injection, not against a
> determined adversary. The real boundaries remain the mount, the dropped capabilities,
> and the egress allowlist. What this task buys is narrower irreversible outcomes and
> visible reversible ones.

### Read-only mode (omp)

`mise run omp:readonly` mounts the project `:ro` and restricts omp to
`read,grep,glob,ast_grep` with `--approval-mode always-ask`. The same caveat as
[`pi:readonly`](#read-only-mode-pi) applies: the `:ro` mount is kernel-enforced, the
tool restriction is enforced by omp in userspace, and `~/.omp` stays writable
because omp writes session history there.

## Agent Client Protocol (ACP) Connections

The `mise run pi:pi-acp` task command can be utilzed for connecting IDE's over [ACP](https://agentclientprotocol.com/overview/introduction) to the Pi coding agent in the sandboxed container.

The task will install [pi-acp](https://github.com/svkozak/pi-acp) to the `/pi-agent/npm-global` shared directory, if not already installed.

The version is pinned in `tasks/pi/pi-acp` (`PI_ACP_VERSION`) and tracked by Renovate,
for the same reason pi itself is pinned in the Dockerfile: `/pi-agent/npm-global/bin` is
prepended to `PATH` and persists on the host, so anything installed there can shadow any
command in every later session. Bump the pin deliberately rather than floating on
`latest`.

Most IDE's will expect to run the `pi-acp` command, so add this to your shell profile:

```bash
alias pi-acp='mise run pi:pi-acp'
```

To move to a newer release, edit `PI_ACP_VERSION` in `tasks/pi/pi-acp`, then remove the
installed copy so the task reinstalls at the new pin:
`rm -rf ~/.pi/agent/npm-global/lib/node_modules/pi-acp`.


## Staying current

### Update the shim (new features in this repo)

```bash
cd /path/to/pi-less-yolo
mise run update
```

No reinstall is needed. Because mise includes the `tasks/` directory directly, task changes go live immediately.

> **Rebuild the omp image if the pull touched `Dockerfile.omp`, `omp-hardened.yml`, or
> `omp-yolo.yml`:**
>
> ```bash
> mise run omp:build
> ```
>
> The approval floor and the command denylist are **baked into the image**, not read from
> `tasks/`, so a pull alone does not update them. The run tasks build only when an image is
> *missing*, never when it is stale — so an out-of-date image is used silently, and
> `mise run omp:yolo` will start the proxy and print its warning while the bash rules are
> not actually present. `mise run test:omp` catches this: it compares the running image's
> behaviour against what the overlays specify.

### Upgrade pi to the latest release

```bash
mise run pi:upgrade
```

Fetches the latest `@earendil-works/pi-coding-agent` version from npm, updates the
`npm install -g` line in `Dockerfile`, and rebuilds the image. Unlike `mise run update`,
this does not go through git at all — it edits your working copy in place, so the change
is yours to commit.

It rewrites **only** the pin in `Dockerfile`. The pi version badge at the top of this
README is a second copy of that number, and the task leaves it alone — so a local
`pi:upgrade` puts the badge one release behind. The Renovate PR for pi updates both in the
same commit, which is why merging that PR is the tidier route when you are not in a hurry.

### Upgrade omp to a newer release

There is no `omp:upgrade` counterpart to `pi:upgrade`, and `mise run update` does not move
omp: the version is pinned by hand in `Dockerfile.omp`, so a pull only changes it if the
pull itself changed those pins.

Renovate opens a PR for each new release. Once it is merged, `mise run update` followed by
`mise run omp:build` is all that is needed. To move ahead of that PR, edit both pins in the
`bun install -g` line near the top of `Dockerfile.omp`:

```
@oh-my-pi/pi-coding-agent@<version>
@oh-my-pi/pi-natives@<version>
```

Then rebuild:

```bash
mise run omp:build
```

**The two versions must be identical.** `pi-natives` is the prebuilt Rust addon compiled
against one specific agent release; a mismatched pair fails at load time, not at build
time.

> **After an omp upgrade, run `mise run test:omp`.** The approval floor and the bash
> denylist both depend on omp internals that are not a public API, so an upgrade can
> disable them silently. The tests assert the observable behaviour and fail if it moved.

## Health check

```bash
mise run pi:health
```

Checks mise version, Docker availability, image existence, task files, npm (for upgrade), `~/.pi/agent`, and tmux passthrough support.

## Uninstall

```bash
cd /path/to/pi-less-yolo
mise run uninstall
```

Removes `~/.config/mise/conf.d/pi-less-yolo.toml`. The Docker image and `~/.pi/agent` are left untouched.

To remove everything:

```bash
mise run uninstall
docker rmi pi-less-yolo:latest
rm -rf ~/.pi/agent
rm -rf /path/to/pi-less-yolo
```

If you built the omp image, remove its state too:

```bash
docker rmi omp-less-yolo:latest
rm -rf ~/.omp
```

## Authentication

Pi supports two ways to authenticate with a provider:

**API key via environment variable** (recommended for scripted or non-interactive use):

```bash
export ANTHROPIC_API_KEY=sk-ant-...
mise run pi
```

The following environment variables are forwarded from your host into the container:

| Provider | Environment Variable |
|---|---|
| Anthropic | `ANTHROPIC_API_KEY` |
| Anthropic (OAuth token; takes precedence over the API key) | `ANTHROPIC_OAUTH_TOKEN` |
| OpenAI | `OPENAI_API_KEY` |
| Azure OpenAI | `AZURE_OPENAI_API_KEY` |
| Google Gemini | `GEMINI_API_KEY` |
| Mistral | `MISTRAL_API_KEY` |
| Groq | `GROQ_API_KEY` |
| Cerebras | `CEREBRAS_API_KEY` |
| xAI | `XAI_API_KEY` |
| OpenRouter | `OPENROUTER_API_KEY` |
| Vercel AI Gateway | `AI_GATEWAY_API_KEY` |
| ZAI | `ZAI_API_KEY` |
| OpenCode | `OPENCODE_API_KEY` |
| Kimi | `KIMI_API_KEY` |
| MiniMax | `MINIMAX_API_KEY` |
| MiniMax (China) | `MINIMAX_CN_API_KEY` |

Pi config variables (`PI_SKIP_VERSION_CHECK`, `PI_CACHE_RETENTION`, `PI_PACKAGE_DIR`) and editor variables (`VISUAL`, `EDITOR`) are also forwarded.

> **`ANTHROPIC_OAUTH_TOKEN` is not refreshed.** Both agents document it as an
> alternative to the API key, and both read it, but neither renews it — an OAuth
> token carries an expiry, and once it lapses requests fail until you export a
> fresh one. For unattended or long sessions, use `ANTHROPIC_API_KEY`.

`mise run omp` forwards everything above **plus** the following, which omp resolves
and pi does not. They are added only for the omp variant, so pi's forwarded surface
is unchanged:

| Provider / purpose | Environment Variable |
|---|---|
| Anthropic via Azure Foundry | `ANTHROPIC_FOUNDRY_API_KEY` |
| Google (Gemini image-tool fallback) | `GOOGLE_API_KEY` |
| Fireworks | `FIREWORKS_API_KEY` |
| Together | `TOGETHER_API_KEY` |
| Hugging Face | `HUGGINGFACE_HUB_TOKEN`, `HF_TOKEN` |
| NVIDIA | `NVIDIA_API_KEY` |
| LiteLLM proxy | `LITELLM_API_KEY` |
| omp named profile | `OMP_PROFILE` |

No other host environment variables are passed into either container.

**Auth file** (`~/.pi/agent/auth.json`): credentials stored here take priority over environment variables. Use `/login` inside pi to set this up interactively. See [pi's provider docs](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/providers.md) for details.

omp stores its own credentials under `~/.omp/agent` instead, so authenticating one
agent does nothing for the other.

## Security model

The container is launched with:

- `--user $(id -u):$(id -g)` — files created inside the container are owned by your host user
- `--cap-drop=ALL` — all Linux capabilities dropped
- `--security-opt=no-new-privileges` — prevents privilege escalation via setuid binaries
- `--ipc=none` — isolated IPC namespace; no shared memory with other containers
- `--volume $(pwd):$(pwd)` — your current directory is mounted at its real host path; the container's working directory is set to match
- `--volume ~/.pi/agent:/pi-agent` — pi config, credentials, and sessions

The image itself also declares `USER 65532:65532`, so it fails closed: a bare
`docker run pi-less-yolo:latest` that forgets `--user` still gets a non-root UID
rather than root. The omp image does the same.

Two build-time properties matter as well:

- **No Docker socket, ever.** It is never mounted, and `PI_EXTRA_MOUNTS` refuses both a
  socket source and any directory enclosing one — mounting it would let the agent drive
  the host daemon and start a privileged container.
- **The mise signing key is a build secret** (`--mount=type=secret`), not a `COPY`, so it
  never lands in an image layer. mise itself is GPG-verified during the build.

For omp, the image additionally bakes a read-only overlay that lowers the agent's
approval mode below upstream's default — see [Approval mode](#approval-mode).

`$HOME` inside the container is intentionally mode `1777`. `--user` passes your host
UID, which the image cannot know at build time, so a fixed owner would leave `$HOME`
unwritable for everyone whose UID isn't the baked-in default. The sticky bit is what
makes this safe; `--cap-drop=ALL` and `--no-new-privileges` mean nothing there can
escalate.

Mounting the directory at its real path (rather than a fixed `/workspace`) means pi's session tracking reflects the actual project path, so each project gets distinct session history.

The agent cannot reach other directories on your host. By default it can make arbitrary network requests and execute any command available inside the container image — see [Network egress](#network-egress-pi_egress) to put an allowlist in front of the first of those.

**API keys** are passed to the container by name (`--env ANTHROPIC_API_KEY`), not as
`--env NAME=value`, so key material never appears in the `docker run` command line
where other users on the host could read it out of `ps`.

**Wide mounts are refused.** Because the containment boundary is "the agent only sees
`$(pwd)`", running from your home directory or `/` would quietly hand the agent
read-write access to everything beneath it — `~/.ssh`, `~/.aws`, and `~/.pi/agent`
included. Those two cases abort with an error. Set `PI_ALLOW_WIDE_MOUNT=1` if you
genuinely mean it.

### Read-only mode (pi)

`mise run pi:readonly` mounts the project directory read-only and restricts pi to the `read`, `grep`, `find`, and `ls` tools. The agent can answer questions about the codebase but cannot write files or run shell commands.

Two different mechanisms are at work here, and they are not equally strong:

- **Your project directory is protected by the kernel**, via the `:ro` bind mount. Nothing inside the container can write to it, whatever pi does.
- **`~/.pi/agent` stays writable**, and the restriction to read-only *tools* is enforced by pi in userspace, not by the kernel. The agent dir cannot be mounted `:ro` — pi writes session history there on every run and aborts with `EROFS` if it can't.

So `pi:readonly` gives you a hard guarantee about your source tree and a softer one about everything else. It is a good fit for reading a codebase you don't trust; it is not a containment boundary against a pi bug or a prompt injection that reaches a write path in `/pi-agent`.

### Network egress (`PI_EGRESS`)

Everything else in this repo bounds the agent's **filesystem**. Nothing bounds its
**network** — the container can reach any host on the internet, and both the source
tree and the forwarded API keys are readable from inside it. `PI_EGRESS=proxy` puts a
kernel-enforced allowlist in front of that.

```bash
mise run pi:egress-build          # one-time, ~10 seconds

PI_EGRESS=proxy mise run pi:readonly
PI_EGRESS=proxy mise run omp:readonly
```

**Why this is not just an approval mode.** omp's `tools.approvalMode` and pi's `--tools`
gate what the *model* may invoke — a userspace check inside the agent process, on
arguments the model produced. They cannot see anything else running in the container: an
npm `postinstall` during `pi install`, a `make` recipe under one approved bash call, a
subprocess three levels down. Those reach the network with no tool call and therefore no
prompt, at any approval tier. Egress filtering sits outside the agent entirely, so it
covers code the model never saw.

**Why this is not just `HTTPS_PROXY`.** Proxy environment variables are a convention that
well-behaved clients honour; `curl --noproxy '*'` ignores them. Here the agent container
joins a Docker `--internal` network, which has no route off the host at all. The only way
out is a dual-homed [tinyproxy](https://tinyproxy.github.io/) sidecar that forwards a
fixed list of hostnames. The env vars are set so clients *find* the proxy; the
containment comes from there being nowhere else to go. `mise run test:egress` asserts
exactly that, including two bypass attempts that ignore the proxy entirely.

#### Adding to the allowlist

Defaults cover the model providers whose keys `_docker_flags` forwards (plus their OAuth
hosts) and the common package registries — npm, PyPI, crates.io, Go, GitHub, GitLab.
`huggingface.co` is deliberately excluded: it is a general hosting platform rather than
just an inference endpoint, and `HF_TOKEN` is forwarded for omp, so allowlisting it would
hand the agent an authenticated, writable destination. Add it to your allow-file if you
pull models from it. Three ways to extend, applied in order and combined:

```bash
# 1. Per-session, for a one-off host. Comma, semicolon, or space separated.
PI_EGRESS_ALLOW="docs.example.com,internal.registry.corp" PI_EGRESS=proxy mise run pi:readonly

# 2. Persistent, one hostname per line, '#' comments allowed.
mkdir -p ~/.config/pi-less-yolo
echo "internal.registry.corp" >> ~/.config/pi-less-yolo/egress-allow.txt

# 3. A different file entirely.
export PI_EGRESS_ALLOW_FILE=/path/to/allow.txt
```

Entries are plain hostnames, and subdomains are implied: `github.com` also covers
`api.github.com` and `codeload.github.com`. Matching is anchored, so
`github.com.attacker.test` does not pass. `PI_EGRESS_NO_DEFAULTS=1` drops the built-in
list and uses only what you supply.

When something breaks, the proxy says what it refused:

```bash
docker logs pi-egress-<pid>    # "Proxying refused on filtered domain \"ifconfig.me\""
```

| Variable | Effect |
|---|---|
| `PI_EGRESS` | `proxy` to enable, `off` (default) for today's unrestricted behaviour |
| `PI_EGRESS_ALLOW` | Extra hostnames for this session |
| `PI_EGRESS_ALLOW_FILE` | Path to an allow-file (default `~/.config/pi-less-yolo/egress-allow.txt`) |
| `PI_EGRESS_NO_DEFAULTS` | `1` drops the built-in defaults |
| `PI_EGRESS_LOG_LEVEL` | tinyproxy log level (default `Notice`) |

#### Recipe: pin an exact allowlist

`PI_EGRESS_NO_DEFAULTS=1` plus your own file gives you a list that is exactly what you
wrote — nothing inherited, so a default added here in a later release cannot silently
widen your policy. That is the reason to prefer it over editing around the defaults.

**1. Seed from the current defaults**, so you start from a known-good list rather than a
blank file. Run this *before* setting `PI_EGRESS_NO_DEFAULTS=1`, or you will write an
empty file:

```bash
mkdir -p ~/.config/pi-less-yolo
bash -c 'source /path/to/pi-less-yolo/tasks/pi/_egress; _pi_egress_allowlist' \
  > ~/.config/pi-less-yolo/egress-allow.txt
```

**2. Trim it.** The file takes `#` comments, so comment lines out rather than deleting
them while you find the floor. The true minimum is your provider's API host *and* its
OAuth host — for Anthropic:

```
api.anthropic.com        # API calls
platform.claude.com      # OAuth token refresh; omitting this fails as "token has expired"
# claude.ai              # only needed to re-run the browser authorize flow
```

Then add whatever your projects actually fetch — `registry.npmjs.org`, `github.com`,
`pypi.org`.

**3. Enable it**, in your shell profile to make it standing:

```bash
export PI_EGRESS_NO_DEFAULTS=1
export PI_EGRESS=proxy
```

**4. Iterate on failures.** The proxy names what it refused:

```bash
docker logs "$(docker ps -q --filter name=pi-egress-)"
# NOTICE  Proxying refused on filtered domain "ifconfig.me"
```

> **The log dies with the session.** Teardown does `docker rm -f`, so read it from a
> second pane while the session is still up. For a `-p` one-shot that fails, the evidence
> is already gone — re-run with a tail attached.

> **Exported variables do not apply everywhere.** Only the `readonly` tasks honour
> `PI_EGRESS`. With the exports above standing in your profile, `mise run pi` and
> `mise run omp` ignore them silently — the variables persist across sessions, the
> filtering does not, and nothing says which is which. Use `mise run pi:readonly` or
> `mise run omp:readonly` for a proxied session.

#### Downsides

Turning this on costs you real functionality. Read this before making it standing policy.

**What stops working**

- **SSH, entirely.** The internal network has no route to port 22 and SSH cannot traverse
  an HTTP proxy, so git-over-SSH fails and `PI_SSH_AGENT=1` becomes inert. Setting both
  warns rather than aborting: the conflict is functional, not a security downgrade — the
  forwarded agent socket is still mounted, but with no reachable SSH server the exposure
  it normally carries is moot. Use HTTPS remotes, or drop `PI_EGRESS`.
- **Most of omp's `browser`, `fetch`, and web search.** Arbitrary sites are not on the
  allowlist, so the tools that most distinguish omp from pi can reach very little. If
  those are why you run omp, this is the largest cost here.
- **Dependency fetches beyond the allowlist** — private registries, internal mirrors,
  vendored URLs. Each needs an allow-file entry.
- **`PI_LOCAL_MODELS=1`**, which shares the host network namespace and would bypass the
  proxy entirely; setting both is a hard error rather than a silent downgrade.

**The error messages are misleading.** The container cannot resolve external names at all
— Docker's embedded DNS serves only container names — so a blocked host surfaces inside
the agent as `Could not resolve host`, not as a policy denial. It reads like broken
networking. Check the proxy log before debugging anything else:

```bash
docker logs "$(docker ps -q --filter name=pi-egress-)"
```

**What it does not protect against**

> **The allowlist is itself a channel.** `github.com` is on it so `git push` works — which
> means `git push` to someone else's repo also works. The model provider must be
> reachable, and data can leave inside a prompt. This narrows the exit; it does not seal
> it.

- **Anything local.** Deletion, overwriting, or history rewriting inside the mounted
  directory is untouched by a network boundary.
- **Persistence, which escapes in time.** Packages installed into `~/.pi/agent` or
  `~/.omp` persist on the host and load in *every* later session — including ones run
  without the proxy. A filtered session can plant something that runs unfiltered later.
- **False confidence, which is the subtlest cost.** Closing the exfiltration path
  convincingly makes it tempting to relax approval modes in exchange. That trades a
  control covering local destruction for one that does not.

**Operational**

- **Only the `readonly` tasks honour `PI_EGRESS`** so far. `mise run pi` and `mise run omp`
  ignore it silently — see the warning in the [recipe](#recipe-pin-an-exact-allowlist).
  The read-only tasks are the "read a codebase I don't trust" path — highest injection
  risk, lowest need for network access — so they are where the allowlist earns its
  friction first.
- **The default is `off`**, so nothing changes unless you ask for it.
- **A proxy container per session**, plus two networks that are created once and left in
  place for concurrent sessions. Remove them with
  `docker network rm pi-egress-internal pi-egress-external`.
- **The proxy log dies with the session** — teardown does `docker rm -f`, so a failed
  one-shot leaves no evidence behind.
- **Podman is untested** for this path, though `--internal` networks are supported there.
  `mise run test:egress` skips there rather than reporting a failure.

**Deliberate design limits**

- **No project-local allow-file is read.** A `.pi-egress-allow` inside the mounted
  directory would be writable by the agent, letting an injected session widen its own
  allowlist for the next run.
- **CONNECT is limited to ports 443 and 8443**, so the proxy cannot tunnel to arbitrary
  services on an allowlisted host.
- **Filtering is on the CONNECT hostname**, with no TLS interception — nothing decrypts
  your traffic, and no custom CA is installed. The cost is that per-path rules are
  impossible: the proxy can allow `github.com`, but not "only this owner's repos". Scope
  the credential instead — a token that cannot write elsewhere is enforced by the server,
  not by us.

### Pi packages

Pi packages installed inside the container (`pi install npm:...`, `pi install git:...`)
are written to `~/.pi/agent/npm-global/lib/node_modules/` and `~/.pi/agent/git/` and loaded as extensions on
every subsequent run. A prompt-injected install persists to the host and survives the
session.

> **Accepted risk.** Audit installed packages with `pi list` and review
> `~/.pi/agent/git/` and `~/.pi/agent/npm/` periodically.

### Git identity

If `~/.gitconfig` exists on the host it is mounted read-only at startup, so the agent can make `git commit` with your correct author identity. Opt out by setting `PI_NO_GITCONFIG=1`.

> **Note:** credential helpers referenced in `~/.gitconfig` (e.g. `osxkeychain`, `libsecret`) are not available inside the container. They fail gracefully — git falls back to prompting for credentials.

### Container context prompt

By default pi is told it is running inside a Docker container as a non-root user, and that the Docker socket, sudo, and system package installation are unavailable. This prevents the agent from confidently suggesting commands that will fail. Opt out by setting `PI_NO_CONTAINER_PROMPT=1`.

### SSH agent forwarding

SSH is **disabled by default**. Set `PI_SSH_AGENT=1` to forward the host SSH agent socket into the container, enabling SSH-based git remotes (`git clone git@github.com:...`) without private keys ever entering the container.

```bash
PI_SSH_AGENT=1 mise run pi
```

Or export it in your shell profile to make it permanent.

> **Does not combine with `PI_EGRESS=proxy`.** SSH cannot traverse an HTTP proxy, and the
> internal network has no route to port 22, so git-over-SSH fails under the egress
> allowlist. Setting both warns and continues — use HTTPS remotes for those sessions. See
> [Network egress](#network-egress-pi_egress).

> **Security note:** a compromised container can authenticate as you to any SSH server your agent has loaded. Review loaded keys with `ssh-add -l` before enabling. On macOS, Docker Desktop exposes the host SSH agent via a fixed path inside the VM. The socket is created root-owned with restricted permissions; the root group (GID 0) is added as a supplementary group so the non-root container user can access it — no additional setup is needed. On Linux, ensure `ssh-agent` is running and `SSH_AUTH_SOCK` is exported in your shell environment.

### Local models (Ollama, LM Studio, vLLM)

Local model servers are **disabled by default**. Set `PI_LOCAL_MODELS=1` to share
the host network namespace, making `localhost` inside the container identical to
`localhost` on the host. Model URLs that work when running pi natively work
identically inside the container with no changes to `models.json` or to the model
server's binding address.

Create `~/.pi/agent/models.json` using the same URL you would use on the host:

```json
{
  "providers": {
    "ollama": {
      "baseUrl": "http://localhost:11434/v1",
      "api": "openai-completions",
      "apiKey": "ollama",
      "compat": {
        "supportsDeveloperRole": false,
        "supportsReasoningEffort": false
      },
      "models": [
        { "id": "llama3.1:8b" }
      ]
    }
  }
}
```

Then start pi with the flag and select the model with `/model`:

```bash
PI_LOCAL_MODELS=1 mise run pi
```

Or export it in your shell profile to make it permanent.

> **Security note:** `--network=host` makes all host ports reachable from inside
> the container, not just the model server port. `--cap-drop=ALL` and
> `--no-new-privileges` remain in force.

> **macOS:** `--network=host` uses the Docker Desktop Linux VM's network namespace,
> not the Mac's. Localhost services on macOS are not reachable this way. Use
> `host.docker.internal` as the `baseUrl` in `models.json` instead — Docker
> Desktop routes that hostname to the Mac host correctly.

### Extra mounts

Set `PI_EXTRA_MOUNTS` to mount additional host directories into the container —
for example an LLM wiki, shared agent config, or SSH keys — without editing
`DOCKER_FLAGS` directly:

```bash
export PI_EXTRA_MOUNTS="$HOME/.llm-wiki:/home/piuser/.llm-wiki;$HOME/.agents:/home/piuser/.agents:ro"
```

Format: `source:target[:mode]`, entries separated by `;`. `mode` is `rw` (default) or
`ro`. Both paths must be absolute. Malformed entries, relative paths, and sources that
don't exist on the host all print a warning and are skipped — they don't stop pi from
starting.

> **Security note:** the default mode is `rw`, so the agent can write to any mounted
> directory unless you add `:ro`. Only mount directories you're comfortable with the
> agent modifying.
>
> Mounting a container runtime socket (`/var/run/docker.sock` or the Podman
> equivalent) would let the agent drive the host daemon and start a fully
> privileged container — a complete escape from this sandbox in one line. Sockets
> are refused outright rather than warned about.
>
> Note also that `target` is not restricted, so a mount can shadow paths inside the
> image (for example `/usr/local/bin/...`). Choose targets under the container's
> `$HOME` unless you have a specific reason not to — `/home/piuser` for `pi`,
> `/home/ompuser` for `omp`.

### Resource limits

By default no memory, CPU, or process-count limits are applied. Set any of these
variables to cap resource usage:

| Variable | Docker flag | Example |
|---|---|---|
| `PI_MEMORY` | `--memory` | `PI_MEMORY=4g` |
| `PI_CPUS` | `--cpus` | `PI_CPUS=2` |
| `PI_PIDS_LIMIT` | `--pids-limit` | `PI_PIDS_LIMIT=512` |

```bash
PI_MEMORY=4g PI_PIDS_LIMIT=512 mise run pi
```

Or export in your shell profile to make them permanent.

### Linux: `--network=host` at build time

On Linux, Docker's default bridge network cannot reach `127.0.0.53` (systemd-resolved). `pi:build` uses `--network=host` during the build only to work around this. This does not affect runtime.

To fix this permanently instead:

1. Find your upstream nameserver: `resolvectl status | grep "DNS Server"`
2. Add to `/etc/docker/daemon.json`: `{ "dns": ["<upstream-ip>"] }`
3. Restart dockerd
4. Remove the `--network=host` line from `tasks/pi/build`

## Podman support

`pi-less-yolo` works with [Podman](https://podman.io) as a drop-in Docker replacement.
Podman is automatically detected when the `docker` command in PATH resolves to the
podman binary — either via a compatibility wrapper or a symlink.

The runtime adds `--userns=keep-id` when podman is detected, which properly maps user
namespaces and avoids TTY ownership errors.

Set `PI_CONTAINER_RUNTIME=podman` to use podman explicitly without relying on detection:

```bash
PI_CONTAINER_RUNTIME=podman mise run pi
```

If you don't have a `docker` compatibility shim, the `podman-docker` package is the
recommended way to provide one:

```bash
# Fedora/RHEL:
sudo dnf install podman-docker

# Ubuntu/Debian:
sudo apt install podman-docker
```

Or create a symlink manually (no package required):

```bash
sudo ln -s "$(which podman)" /usr/local/bin/docker
```

> **Note:** Shell aliases (`alias docker=podman`) are only expanded in interactive
> shells. Mise tasks run as non-interactive bash subprocesses and cannot see aliases
> defined in your shell profile — see the
> [Bash manual on Aliases](https://www.gnu.org/software/bash/manual/bash.html#Aliases).
> Use `PI_CONTAINER_RUNTIME=podman`, the `podman-docker` package, or a symlink instead.

All tasks work identically with podman, for both agents (`pi`, `pi:readonly`,
`pi:build`, `pi:shell`, `omp`, `omp:readonly`, `omp:build`, `omp:shell`). CI builds
and smoke-tests both images under Docker and Podman.

## Customising the container

To modify the container — adding tools, changing the base image, pinning different versions — edit `Dockerfile` and rebuild:

```bash
# Edit Dockerfile...
mise run pi:build
```

The `npm install -g` line near the bottom of `Dockerfile` pins the pi version. `mise run pi:upgrade` updates it automatically; you can also edit the version string by hand.

The omp image is `Dockerfile.omp`, rebuilt with `mise run omp:build`. Its `bun install -g`
line pins both `@oh-my-pi/pi-coding-agent` and `@oh-my-pi/pi-natives` — keep the two
versions identical, since the natives addon is compiled against a specific agent release.

## Related projects

- [pi-coding-agent](https://github.com/earendil-works/pi) — the upstream AI coding agent this repo wraps
- [oh-my-pi](https://github.com/can1357/oh-my-pi) — the `omp` agent, wrapped by the `omp:` tasks; a fork of [pi-mono](https://github.com/badlogic/pi-mono), separate from the pi above
- [mise](https://mise.jdx.dev) — the polyglot dev-tool manager used for task running
- [Chainguard Images](https://chainguard.dev) — minimal, hardened container base images used here
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) — Anthropic's official sandboxed coding agent CLI, a similar concept

---

**Keywords:** docker sandbox AI coding agent, sandboxed LLM agent, pi-coding-agent docker, isolated Claude CLI, mise AI task runner, Chainguard AI container, prevent AI agent filesystem access, secure coding agent container, ai agent docker isolation
