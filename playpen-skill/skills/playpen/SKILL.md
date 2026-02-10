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

## Two Modes

### Interactive Mode (user opens a new terminal)

For when the user wants to work inside the sandbox directly:

```bash
playpen /path/to/project
```

Do NOT run this from the current session. Provide the command for the user to copy and run in a separate terminal.

### Headless Mode (dispatch from current session)

For when you want to fire off autonomous work in the background. You CAN run this directly from the current session using the Bash tool:

```bash
playpen --headless "Your detailed prompt here" /path/to/project
```

This launches a detached container that runs Claude Code in print mode (`-p`). The current session stays free.

**Typical headless flow:**
1. Collaborate with the user to write a PRD, plan, or detailed brief
2. Dispatch it to a Playpen container with `--headless`
3. Monitor progress with `docker logs -f playpen-<project-name>`
4. The user reviews changes via `git diff` when it finishes

**Example dispatch:**

```bash
playpen --headless "Read PRD.md in this repo and implement the full feature. Write small commits as you go. When done, create a summary in RESULT.md." /Users/ryanmish/Dev/project
```

**Monitor the running container:**

```bash
# Follow logs live
docker logs -f playpen-project

# Check if still running
docker ps --filter name=playpen-project

# Stop if needed
docker stop playpen-project
```

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
