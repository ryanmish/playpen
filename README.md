# Playpen

Sandboxed Claude Code via Docker. Run Claude Code with `--dangerously-skip-permissions` inside an isolated container where it can't touch your host machine. Available as a CLI, a Finder Quick Action, and a Claude Code plugin.

## How It Works

1. Your project folder is mounted into a Docker container at `/workspace`
2. Claude Code runs with full permissions inside the container
3. File changes are live (bind mount), so edits appear on the host immediately
4. The container is disposable (`--rm`) and destroyed when the session ends
5. Claude cannot access anything outside the mounted project folder
6. All your Claude Code plugins (ralph-wiggum, compound-engineering, etc.) work inside the container

Uses **Colima** as a lightweight Docker runtime instead of Docker Desktop.

## Setup

Run the one-time setup script:

```bash
git clone https://github.com/ryanmish/playpen.git
cd playpen
bash setup.sh
```

This will:
- Install Colima and Docker CLI via Homebrew (if not already installed)
- Start the Colima VM (2 CPUs, 4GB RAM, aarch64)
- Build the `playpen` Docker image
- Symlink `launcher.sh` to `~/.local/bin/playpen`
- Install the Finder Quick Action ("Claude in Sandbox")

Make sure `~/.local/bin` is in your PATH. If it isn't, add to `~/.zshrc`:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

## Usage

### From Terminal

```bash
playpen ~/Dev/my-project
```

### From Finder

1. Right-click any folder
2. Quick Actions > "Claude in Sandbox"
3. Terminal.app opens with Claude Code running in the container

If the Quick Action doesn't appear, enable it in:
System Settings > Privacy & Security > Extensions > Finder Extensions

### As a Claude Code Plugin

Install the plugin to get a `/playpen` slash command inside Claude Code:

```
/plugin marketplace add ryanmish/playpen
/plugin install playpen
```

Then use `/playpen` in any conversation. Claude will help you determine the right command to run.

## What Gets Mounted

| Host Path | Container Path | Mode |
|-----------|---------------|------|
| Your project folder | `/workspace` | read-write |
| `~/.claude.json` | `/root/.claude.json` | read-only |
| `~/.gitconfig` | `/root/.gitconfig` | read-only |
| `~/.claude/plugins` | `/root/.claude/plugins` | read-only |
| `sandbox-claude.md` | `/root/.claude/CLAUDE.md` | read-only |

SSH keys are **not** mounted. The container has no access to `~/.ssh` or any other host credentials beyond what's listed above.

## Plugins

All Claude Code plugins installed on your host are available inside the container. This includes:

- **Ralph Wiggum**: Run `/ralph-loop` for autonomous iteration loops. Claude keeps working on a task until a completion promise is met.
- **Compound Engineering**: All agents, commands, and skills (review, plan, work, etc.)
- **Any other installed plugins**: Everything in `~/.claude/plugins` is mounted read-only.

MCP servers (Playwright, Supabase, Figma, etc.) are **not** available inside the container since they require host-side processes.

## What's in the Container

- **Node.js 22** (base image: `node:22-slim`)
- **Claude Code** (`@anthropic-ai/claude-code`)
- **Git** + **GitHub CLI** (`gh`)
- **Python 3**
- **ripgrep**, **jq**, **curl**
- **build-essential** (gcc, make, etc.)
- **openssh-client**

## Authentication

Playpen supports two auth methods:

1. **OAuth (default)**: Mounts `~/.claude.json` read-only into the container. This is what you get after running `claude` and logging in normally.
2. **API key**: If `ANTHROPIC_API_KEY` is set in your environment, it gets passed into the container.

## Files

| File | Purpose |
|------|---------|
| `Dockerfile` | Defines the container image with all dev tooling |
| `launcher.sh` | Main entry point. Validates args, starts Colima, builds image, runs container |
| `setup.sh` | One-time setup. Installs dependencies, builds image, creates symlink + Quick Action |
| `sandbox-claude.md` | CLAUDE.md injected into the container explaining sandbox constraints |
| `install-quick-action.sh` | Creates the macOS Automator Quick Action programmatically |
| `SECURITY.md` | Security audit and threat model |
| `ORCHESTRATION.md` | Research on CLI orchestration and headless mode |

### Plugin Files

| File | Purpose |
|------|---------|
| `.claude-plugin/marketplace.json` | Makes this repo a Claude Code plugin marketplace |
| `playpen-skill/.claude-plugin/plugin.json` | Plugin metadata |
| `playpen-skill/skills/playpen/SKILL.md` | The `/playpen` slash command definition |

## Rebuilding the Image

If you modify the Dockerfile or want to update Claude Code to the latest version:

```bash
docker rmi playpen
playpen ~/Dev/any-project  # auto-rebuilds on next launch
```

## Stopping Colima

Colima runs a background VM. Stop it when not in use to free resources:

```bash
colima stop
```

The launcher will auto-start it again next time you use playpen.

## Security

See [SECURITY.md](SECURITY.md) for the full threat model and hardening recommendations.

Key protections:
- **Filesystem isolation**: Container can only access the mounted project folder
- **No SSH keys mounted**: Eliminates the most critical credential exposure
- **OAuth config is read-only**: Prevents modification of auth state
- **Plugins are read-only**: Container cannot modify plugin code
- **Container is ephemeral** (`--rm`): No persistent attack surface

Remaining considerations:
- OAuth tokens in `~/.claude.json` are readable and the container has network access (needed for API calls)
- Git config is readable (email, signing key refs)
- Project folder is read-write by design (review changes via `git diff`)
- Container runs as root (no defense-in-depth inside the container)

## Future Plans

- CLI orchestration mode for programmatic/headless control (see [ORCHESTRATION.md](ORCHESTRATION.md))
- Non-root container user for defense-in-depth
