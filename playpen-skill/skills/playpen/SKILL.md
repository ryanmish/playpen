---
name: playpen
description: Launch a sandboxed Claude Code session in an isolated Docker container. Use when tasks involve risk to the host machine or when full permissions are needed with isolation.
argument-hint: "[path-to-project]"
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

## How to Launch

Provide the user with the terminal command:

```bash
playpen /path/to/project
```

If `$ARGUMENTS` is provided, use it as the project path. Otherwise, determine the path from context or ask the user.

The `playpen` CLI is at `~/.local/bin/playpen`. It:
1. Starts Colima (Docker VM) if not already running
2. Builds the container image if needed
3. Mounts the project folder at `/workspace` (read-write)
4. Mounts all Claude Code plugins (ralph-wiggum, compound-engineering, etc.)
5. Launches Claude Code with full permissions inside the container

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

## Important

Do NOT attempt to run `playpen` from within this Claude Code session. It launches an interactive Docker container that requires its own terminal. Provide the command for the user to copy and run.

The user can also right-click any folder in Finder and select Quick Actions > "Claude in Sandbox" to launch Playpen without the terminal.

## Prerequisites

Playpen requires initial setup. If the user hasn't installed it yet, point them to the repo's `setup.sh` script which installs Colima, Docker CLI, builds the image, and creates the Finder Quick Action.
