# AGENTS.md

## Project purpose

`pi-less-yolo` is a mise shim that runs `pi-coding-agent` inside a sandboxed
Chainguard Docker container, restricting the agent to the mounted working
directory only. There is no build system or test suite beyond shell scripts, a
Dockerfile, and a CI smoke test.

It also wraps a second, unrelated agent: `omp` ([oh-my-pi](https://github.com/can1357/oh-my-pi),
a fork of pi-mono) under the `omp:` task namespace and its own Bun image. Both
agents share `tasks/pi/_docker_flags` so the hardening cannot drift between them;
`_PI_VARIANT` selects image, state mount, and container home.

## Key files

| Path | Role |
|---|---|
| `Dockerfile` | Single-stage Chainguard node image; installs curl, git, tmux, mise, uv, Python, and pi. `mise-release.asc` is passed in as a build secret (not a bind mount). Entrypoint synthesises a `/etc/passwd` entry for the runtime UID so tools like SSH can resolve the user. |
| `tasks/pi/_docker_flags` | Sourced (not executed) by all pi *and* omp tasks; `_PI_VARIANT` (`pi`/`omp`) selects image, state mount, and container home; defines `DOCKER_FLAGS` (security options, volume mounts, env-var forwarding); detects podman and adds `--userns=keep-id` when needed |
| `tasks/pi/_default` | `mise run pi` — launches the agent in the container |
| `tasks/pi/readonly` | `mise run pi:readonly` — launches the agent with the project directory mounted read-only and file-modification tools disabled |
| `tasks/pi/build` | `mise run pi:build` — builds the Docker image |
| `tasks/pi/shell` | `mise run pi:shell` — opens bash in the container with identical mounts |
| `tasks/pi/upgrade` | `mise run pi:upgrade` — bumps the `npm install -g` line in `Dockerfile` and rebuilds |
| `tasks/pi/health` | `mise run pi:health` — checks mise version, Docker, image, task files, `~/.pi/agent`, and tmux |
| `tasks/pi/_egress` | Sourced by `_docker_flags`; defines `_pi_egress_start`/`_pi_egress_stop` for `PI_EGRESS=proxy`. Puts the agent on a Docker `--internal` network (no route off the host) with a dual-homed tinyproxy sidecar as the only exit, allowlisting hostnames. Called by the `readonly` tasks only. |
| `tasks/pi/egress-build` | `mise run pi:egress-build` — builds `pi-egress:latest` from `Dockerfile.egress`; agent-agnostic, so there is no omp variant |
| `Dockerfile.egress` | Alpine + tinyproxy sidecar for `PI_EGRESS=proxy`. No config baked in — `tasks/pi/_egress` generates `tinyproxy.conf` and the filter file on the host and bind-mounts them `:ro`, so allowlist changes never need a rebuild. |
| `Dockerfile.omp` | Single-stage Bun image for the omp (oh-my-pi) agent; installs git, ripgrep, fd, python3, tini, and the pinned `@oh-my-pi/*` npm packages. Shares `entrypoint.sh` via `PI_ENTRY_CMD=omp`. Bakes the `omp-hardened.yml` `PI_CONFIG_FILES` overlay (approval-mode floor + per-tool `tools.approval` pins + `bash.patterns`). The `mkdir` before that `COPY` is load-bearing: `COPY --chmod=0444` would otherwise create `/etc/omp` unreadable, silently dropping the overlay. |
| `tasks/omp/_default` | `mise run omp` — launches omp in the container |
| `tasks/omp/readonly` | `mise run omp:readonly` — project mounted read-only, tools limited to `read,grep,glob,ast_grep`, approval mode `always-ask` |
| `tasks/omp/yolo` | `mise run omp:yolo` — `--yolo` with `PI_EGRESS` defaulted to `proxy`, `PI_CONFIG_FILES` pointed at both overlays, and a warning naming uncommitted/unpushed work. Relies on `bash.patterns` deny rules, which (unlike `approvalMode`) still apply under `--yolo`. Never prompts, by design. |
| `omp-hardened.yml` | The `PI_CONFIG_FILES` overlay COPYed into the omp image: `tools.approvalMode: write`, a `tools.approval` pin for every built-in tool, and a deny-only `bash.patterns` list. Deny-only on purpose — a `prompt` rule is a no-op in `write` mode and a hang under `--yolo`. Outranks the user's own `config.yml` (verified), so the agent cannot relax it by writing to its state dir. The pins are `inherit`, not a real policy: `resolveApproval` consults `tools.approval` *before* the tier/mode comparison, so a `config.yml` `bash: allow` would otherwise defeat the floor; an unrecognised value is dropped by `normalizePolicy` and the mode decides. `prompt` would be wrong — honoured under `--yolo` (hangs) and consulted ahead of the tier (prompts on reads). |
| `omp-yolo.yml` | Second overlay, layered by `omp:yolo` only. Restates every hardened rule (array layering REPLACES rather than merges) and adds the unattended-only denies. Does *not* restate `tools.approval`: maps merge per key, so the hardened pins carry over. `test:omp` asserts superset + no `prompt` rules. |
| `tasks/omp/build` | `mise run omp:build` — builds the omp image |
| `tasks/omp/shell` | `mise run omp:shell` — opens bash in the omp container |
| `.mise/tasks/ci` | `mise run ci` — lint → build → smoke test (local equivalent of CI) |
| `.mise/tasks/install` | Writes `~/.config/mise/conf.d/pi-less-yolo.toml` to register tasks globally |
| `.mise/tasks/uninstall` | Removes the global config file |
| `.mise/tasks/update` | `git pull` in the repo root; no reinstall needed |
| `.mise/tasks/lint/_default` | Runs `lint:shell` then `lint:docker` |
| `.mise/tasks/lint/shell` | shellcheck on all executable scripts under `tasks/` and `.mise/tasks/` |
| `.mise/tasks/lint/docker` | hadolint on `Dockerfile`, `Dockerfile.omp`, and `Dockerfile.egress` |
| `.mise.toml` | Pins tool versions (shellcheck, hadolint) for local development |
| `.hadolint.yaml` | Suppresses three intentional hadolint rules with justification comments (DL3018, DL3008, DL3059) |
| `.github/workflows/ci.yml` | CI: lint job + build job (image build, `--version` smoke test, `python3 --version`) |
| `renovate.json` | Renovate config (see below) |
| `.github/dependabot.yml` | Dependabot config (see below) |

## Development workflow

The Docker socket is intentionally absent from the container — mounting it
would grant full host filesystem access via a trivial container escape, defeating
the entire security model.

From within a `mise run pi` session, run `mise run lint` to validate scripts
and the Dockerfile. For anything that requires Docker (`mise run ci`,
`mise run pi:build`, smoke tests), exit the container and run on the host.
Commit the changes and let CI handle build validation if a host shell isn't
available.

On a fresh clone, two setup steps are required before any tasks will work:

```bash
mise trust          # trust .mise.toml so mise will install tools from it
mise run install    # register tasks/pi/ globally via ~/.config/mise/conf.d/pi-less-yolo.toml
```

`mise run ci` calls `mise run pi:build`, which is defined in `tasks/pi/` and only
resolvable after `install` has been run. Without it, mise will error with
`no task pi:build found`.

Day-to-day commands:

```bash
mise run lint    # shellcheck + hadolint
mise run ci      # lint + docker build + smoke test
```

`MISE_PROJECT_ROOT` and `MISE_TASK_DIR` are available inside all task scripts.

## Conventions

- **All task scripts must pass `shellcheck -x` and `hadolint`** — CI enforces both.
- `tasks/pi/_docker_flags` is *sourced*, not executed — no shebang, not executable.
- Both agents share `_docker_flags`. Put security-relevant flags there, never in a per-agent task, so `pi` and `omp` cannot diverge. Set `_PI_VARIANT=omp` before sourcing; unset defaults to `pi`.
- `PI_CONFIG_DIR` is **not** an absolute path for omp — omp joins it under `$HOME`, so `/omp-home` resolves to `/home/ompuser/omp-home` and misses the mount. The omp variant therefore mounts state at omp's own default `~/.omp` and sets no env var. Verify any change here with `omp config path`.
- `#MISE raw=true` and `#MISE dir="{{cwd}}"` on `_default` and `shell` are intentional: they preserve raw terminal I/O and ensure the container's working directory matches the caller's. Do not remove them.
- Docker security flags (`--cap-drop=ALL`, `--security-opt=no-new-privileges`, `--user $(id -u):$(id -g)`) are non-negotiable. Do not weaken them.
- **Podman support:** `tasks/pi/_docker_flags` detects podman via `docker --version` output (version string) and binary path (`readlink -f`); adds `--userns=keep-id` to fix TTY ownership errors. Shell aliases are not visible in non-interactive scripts; users need the `podman-docker` package, a symlink, or `PI_CONTAINER_RUNTIME=podman`.
- `--network=host` appears in `pi:build` on Linux (DNS workaround) and in runtime `DOCKER_FLAGS` when `PI_LOCAL_MODELS=1` is set. It must not appear unconditionally in runtime `DOCKER_FLAGS`.
- When adding a new provider API key: add it to the `PI_ENV_VARS` array in `tasks/pi/_docker_flags` **and** the auth table in `README.md`.
- Host-side control variables consumed by `_docker_flags`; not forwarded into the container via `PI_ENV_VARS`:

  | Variable | Effect |
  |---|---|
  | `PI_NO_GITCONFIG=1` | Suppress `~/.gitconfig` read-only mount |
  | `PI_NO_CONTAINER_PROMPT=1` | Suppress the container-context `--append-system-prompt` (no Docker socket, sudo, or root) |
  | `PI_SSH_AGENT=1` | Forward SSH agent socket; also mounts `~/.ssh/known_hosts` and `~/.ssh/config` read-only |
  | `PI_LOCAL_MODELS=1` | Add `--network=host` so local model servers are reachable at `localhost`; on macOS Docker Desktop use `host.docker.internal` instead |
  | `PI_MEMORY` | Set `--memory` (e.g. `4g`) |
  | `PI_CPUS` | Set `--cpus` |
  | `PI_PIDS_LIMIT` | Set `--pids-limit` |
  | `PI_CONTAINER_RUNTIME` | Override container runtime (e.g. `podman`); skips auto-detection |
  | `PI_EXTRA_MOUNTS` | `;`-separated `source:target[:mode]` volume mounts; mode defaults to `rw`; malformed entries and missing sources both warn to stderr and are skipped, never fail the task |
- Use `perl -pi -e` for in-place file edits (cross-platform; avoids `sed -i` / `sed -i ''` incompatibility between Linux and macOS).
- `mise-release.asc` is mounted as a build secret (`--mount=type=secret`), not a bind mount — rootless Podman + SELinux denies `gpg` read access to bind-mounted context files (issue #99).

## Automated dependency updates

### Renovate

`renovate.json` uses `config:recommended` and applies a 72-hour minimum release age to all dependencies except `@earendil-works/pi-coding-agent`. It disables Docker image digest and GitHub Actions managers (handled by Dependabot) and uses regex managers to track versions in `Dockerfile`, `Dockerfile.omp`, `tasks/pi/pi-acp`, and `README.md`:

| Dependency | Location | Datasource |
|---|---|---|
| `mise` | `MISE_VERSION=` in `Dockerfile` | GitHub Releases (`jdx/mise`) |
| `uv` | `mise install uv@` / `mise exec uv@` in `Dockerfile` | GitHub Releases (`astral-sh/uv`) |
| Python | `uv python install <ver>` in `Dockerfile` | GitHub Tags (`python/cpython`) |
| `@earendil-works/pi-coding-agent` | `npm install -g` line in `Dockerfile` and badge in `README.md` | npm |
| `pi-acp` | `PI_ACP_VERSION=` in `tasks/pi/pi-acp` | npm |
| `@oh-my-pi/pi-coding-agent` **and** `@oh-my-pi/pi-natives` | both `bun install -g` pins in `Dockerfile.omp`, one lockstep dep | npm |

Both `Dockerfile` and `README.md` must be updated together when pi's version changes (Renovate handles both via the same `matchStrings` list).

The same one-dependency-two-matchStrings trick is load-bearing for omp: `@oh-my-pi/pi-natives` is the prebuilt addon for a specific `@oh-my-pi/pi-coding-agent` release, and `Dockerfile.omp` requires the two pins to be identical. Modelling them as separate dependencies would let Renovate open a PR bumping only one, leaving an incompatible native addon. Keep them in a single custom manager. Validate changes with:

```bash
docker run --rm -v "$PWD:/repo:ro" -w /repo node:24-slim \
  npx --yes --package renovate@latest -- renovate-config-validator
```

(Run with no path argument — passing one validates as *global* config, which is more permissive and will not catch custom-manager errors. The host's Node may be too old for current Renovate, hence the container.)

### Dependabot

`.github/dependabot.yml` runs weekly on a 3-day cooldown for:

- **Docker** — the `FROM` image digest in `Dockerfile`
- **GitHub Actions** — action versions in `.github/workflows/`

## GitHub Actions

`.github/workflows/ci.yml` triggers on push and pull requests to `main`. It has four jobs:

| Job | Depends on | Steps |
|---|---|---|
| `lint` | — | Checkout → mise-action → `mise run lint` |
| `build` | — | Checkout → Docker Buildx → build image, exported to `image.tar` (GHA cache) → upload as artifact |
| `test` | `build` | Checkout → mise-action → download + `docker load` the image → `mise run test` |
| `test-podman` | `build` | Checkout → mise-action → download + `podman load` the image → `PI_CONTAINER_RUNTIME=podman mise run test` |

The build job uses `docker/build-push-action` with `push: false` and `outputs: type=docker` so the built image can be uploaded as an artifact and reused by both test jobs without a registry.
