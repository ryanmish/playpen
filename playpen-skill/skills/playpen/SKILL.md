---
name: playpen
description: Launch a sandboxed Claude Code session in an isolated Docker container. Use when tasks involve risk to the host machine or when full permissions are needed with isolation.
argument-hint: "[path-to-project]"
allowed-tools: Bash(playpen *), Bash(docker logs *), Bash(docker ps *), Bash(docker stop *)
---

# Playpen - Sandboxed Claude Code

Run a task inside a Playpen sandbox (isolated Docker container) using the `playpen` CLI.

## When to Use This

Use `/playpen` when a task involves risk to the host machine or when full permissions are needed but isolation is preferred:

- Running untrusted or generated code
- Installing unknown packages or dependencies
- Bulk file operations that could go wrong
- Testing destructive commands (rm, database drops, etc.)
- Running code from third-party repos you haven't audited
- Any task where `--dangerously-skip-permissions` would be useful but you want a safety net
- Running Ralph Wiggum loops (`/ralph-loop`) on risky tasks
- Dispatching autonomous work while continuing the current conversation

## Three Modes

All three can be run from the current session using the Bash tool.

### Spawn Mode (recommended for interactive dispatch)

Opens a new Terminal.app tab with a full interactive Playpen session. The current session stays free.

```bash
playpen --spawn /path/to/project
```

Use this when the user wants to work inside the sandbox themselves, or when you want to hand off a task for interactive use (e.g., "go explore this repo in a sandbox").

### Headless Mode (fire and forget)

Launches a detached container running Claude Code in print mode (`-p`). No terminal, no interaction. Pure autonomous execution.

```bash
playpen --headless "Your detailed prompt here" /path/to/project
```

**Typical headless flow:**
1. Collaborate with the user to write a PRD, plan, or detailed brief
2. Dispatch it to a Playpen container with `--headless`
3. Monitor progress with `docker logs -f playpen-<project-name>`
4. The user reviews changes via `git diff` when it finishes

**Monitor the running container:**

```bash
docker logs -f playpen-project    # follow logs
docker ps --filter name=playpen-project  # check status
docker stop playpen-project       # stop if needed
```

### Interactive Mode (direct, blocks current terminal)

For when the user manually runs playpen in their own terminal:

```bash
playpen /path/to/project
```

Do NOT run this bare command from the current session (it requires a TTY). Use `--spawn` or `--headless` instead.

## What Gets Mounted

- **Project folder** at `/workspace` (read-write, changes are live on host)
- **`~/.claude.json`** for OAuth auth (read-only)
- **`~/.gitconfig`** for git identity (read-only)
- **`~/.claude/plugins`** for all installed plugins (read-only)
- **`sandbox-claude.md`** as the container's CLAUDE.md (read-only)

Nothing else from the host is accessible. No SSH keys, no Keychain, no other files.

## Plugins Inside the Container

All Claude Code plugins work inside Playpen:
- `/ralph-loop` for autonomous iteration
- `/lfg` and `/slfg` for full autonomous workflows
- All compound-engineering agents, commands, and skills

MCP servers (Playwright, Supabase, Figma) are **not** available.

## Limitations

- No MCP servers available inside the container
- No macOS system services (Keychain, Spotlight, etc.)
- Container is destroyed on exit (anything outside `/workspace` is lost)
- Cold start takes 10-30 seconds if Colima VM is not running

## Prerequisites

Playpen requires initial setup. If the user hasn't installed it yet, point them to the repo's `setup.sh` script which installs Colima, Docker CLI, builds the image, and creates the Finder Quick Action.

The user can also right-click any folder in Finder and select Quick Actions > "Claude in Sandbox" to launch Playpen interactively.
