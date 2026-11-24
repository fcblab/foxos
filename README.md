# FoxOS

An Arch Linux container for AI-assisted development with Codex, Claude Code, Oh My Pi (OMP), and T3 Code, plus development tools and agent extensions.

## Included tools

- **AI coding:** Codex, Claude Code, and OMP; T3 Code provides a web service with OMP ACP integration.
- **Development:** Python, uv, Node.js, npm, Bun, Go, Rust stable, and Liberica JDK 25.
- **Code tools:** rust-analyzer, gopls, Serena, and its TypeScript language service dependencies.
- **Agent integrations:** Context7, Exa Skills, Ponytail, RTK, and Caveman. See `Dockerfile` for installation targets.
- **Utilities:** Git, OpenSSH, curl, wget, jq, yq, ripgrep, fd, tree, and more.

The base image is `archlinux:base-devel`, and the default time zone is `America/Los_Angeles`. The build commands target `linux/amd64`; the JDK download also targets x86_64.

## Quick start

Use a Linux host with Docker Engine and the Docker Compose plugin. The current configuration uses host networking. Local builds also require Docker Buildx with BuildKit support.

### 1. Configure the environment

Edit `compose.yaml`:

- Replace `CODEX_BASE_URL` and `CODEX_AUTH_TOKEN` with your API endpoint and token. OMP uses these values too.
- Replace `CC_BASE_URL` and `CC_AUTH_TOKEN` with the endpoint and token for Claude Code.
- Set `CONTEXT7_API_KEY` and `EXA_API_KEY` as needed. Do not use `xxx` as a real credential.
- Replace `T3CODE_HOST: 100.90.7.6` with an IP address assigned to your host. Use `127.0.0.1` for local access only; `0.0.0.0` listens on all IPv4 interfaces.
- Ensure your provider supports the configured model names and thinking levels.

### 2. Start the container

Run from the repository root:

```bash
docker compose up -d
docker logs -f coding-agent
```

Compose uses `ghcr.io/fcblab/fos:latest`; it does not automatically build the local Dockerfile.

T3 Code starts with the container by default and listens on port `3773`. Generate a pairing link in another terminal:

```bash
docker exec -it coding-agent t3 pair
```

Open the generated link to pair. The listening address must be reachable from the device running your browser.

### 3. Use command-line agents

```bash
docker exec -it coding-agent bash

# Run these commands inside the container.
codex
claude
omp
```

The default working directory is `/root/.t3/projects`, mapped to `./workspace` on the host. Enter a project directory before starting an agent.

## Environment variables

Set these values under `environment` in `compose.yaml`:

| Variable | Default or current configuration | Purpose |
| --- | --- | --- |
| `CODEX_BASE_URL` | Empty string by default in the script | Custom API endpoint for Codex and OMP |
| `CODEX_AUTH_TOKEN` | Empty string by default in the script | API credential for Codex and OMP |
| `CODEX_MODEL` | `gpt-6.2-sol` | Default model for Codex, OMP, and T3 |
| `CODEX_THINKING_LEVEL` | `medium` | Thinking level for the default Codex, OMP, and T3 model |
| `CC_BASE_URL` | Empty string by default in the script | Claude Code API endpoint |
| `CC_AUTH_TOKEN` | Empty string by default in the script | Claude Code API credential |
| `CC_MODEL` | `claude-opus-5-5[1m]` | Claude Code model; the T3 fallback model strips the trailing `[1m]` |
| `CC_THINKING_LEVEL` | `medium` | Claude Code model thinking level |
| `CONTEXT7_API_KEY` | `xxx` in Compose | Context7 credential |
| `EXA_API_KEY` | `xxx` in Compose | Exa credential |
| `START_T3CODE` | `true` | Starts T3 Code automatically only when set to `true` |
| `T3CODE_HOST` | `0.0.0.0` in the image; overridden to `100.90.7.6` in Compose | T3 Code listening address |
| `T3CODE_PORT` | `3773` | T3 Code listening port |

OMP's custom provider uses the `openai-responses` API and `openai-models-list` model discovery. Your endpoint must support both.

After changing Compose environment variables, run `docker compose up -d` again. Restarting an existing container does not update its environment.

## Persistent data

These host paths are relative to the directory containing `compose.yaml` and are bind-mounted when the container starts:

| Host path | Container path | Contents |
| --- | --- | --- |
| `./workspace` | `/root/.t3/projects` | Project code |
| `./worktrees` | `/root/.t3/worktrees` | Project worktrees |
| `./t3-data` | `/root/.t3/userdata` | T3 Code user data |
| `./codex-data/sessions` | `/root/.codex/sessions` | Codex sessions |
| `./codex-data/archived_sessions` | `/root/.codex/archived_sessions` | Archived Codex sessions |
| `./claude-data/{projects,file-history,plans,tasks,agent-memory}` | Corresponding subdirectories under `/root/.claude/` | Claude Code projects, history, plans, tasks, and memory |
| `./omp-data/agent/{sessions,blobs}` | Corresponding subdirectories under `/root/.omp/agent/` | OMP sessions and attachment data |

**Configuration overrides:** On every container start, `config.sh` updates agent configuration from environment variables and first overwrites `/root/.t3/userdata/settings.json` with the image's template. Settings changed in T3 may reset on the next start, even though this file is in a persistent directory.

Templates in `config` are installed when the image is built, not mounted at runtime. Rebuild the image after changing templates to make those changes permanent. Container files outside the listed mounts may be lost when the container is recreated.

## Build and update

Build and load a local image without pushing it:

```bash
docker buildx build --platform linux/amd64 -t ghcr.io/fcblab/fos:latest --load .
docker compose up -d --force-recreate
```

Build without cache and push the image:

```bash
docker buildx build --platform linux/amd64 -t ghcr.io/fcblab/fos:latest --no-cache --push .
```

Pushing requires authentication and write access to `ghcr.io/fcblab/fos`. To publish your own image, change both the build tag and the image name in `compose.yaml`.

Pull the remote image and recreate the container:

```bash
docker compose pull
docker compose up -d
```

The base image and several tools are not version-pinned. Some installations use `latest` or upstream install scripts, so tool versions may differ between builds.

## Common commands

Run each command as needed:

```bash
# Show service status.
docker compose ps

# Follow logs. Press Ctrl+C to stop following.
docker logs -f coding-agent

# Open a shell inside the container. Run exit to leave it.
docker exec -it coding-agent bash

# Generate a T3 Code pairing link.
docker exec -it coding-agent t3 pair

# Stop and remove containers while keeping host bind-mount directories.
docker compose down
```

## Repository layout

```text
.
├── Dockerfile              # Base environment, agents, and extensions
├── compose.yaml            # Service, environment, networking, and data mounts
├── config/                 # Agent configuration templates installed at build time
├── config.sh               # Writes environment variables into configuration at startup
└── docker-entrypoint.sh    # Applies configuration, starts T3, and runs the container command
```

## Security notes

- The container runs as root, uses host networking, and sets `seccomp:unconfined`. Do not treat it as a strongly isolated sandbox for untrusted code.
- Agents can modify mounted projects and worktrees. Keep important code under version control and maintain backups.
- API credentials enter through environment variables and are written to agent configuration files inside the container. Never commit real credentials or publish configuration or diagnostic output containing them.
- Bind T3 Code only to trusted interfaces and restrict access with a firewall. Do not expose it directly to the public internet.
