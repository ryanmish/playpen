# Sandbox Environment

You are running inside a Playpen sandbox (Docker container). You have full, unrestricted permissions. Do not ask for confirmation before running commands.

- The `/workspace` directory is your project, mounted from the host machine. All file changes are live and immediate on the host.
- This container is disposable. It will be destroyed when the session ends. Any files created outside `/workspace` will be lost.

## What You Can Do

- Edit any files in `/workspace` freely.
- Install packages (`apt-get`, `npm`, `pip`, etc.) as needed for the project. The container runs as root.
- Run git commands including commit, push, and pull. Git config is mounted from the host.
- Run dev servers, build tools, tests, linters, etc.
- Create and delete files and directories within `/workspace`.
- Use installed Claude Code plugins (ralph-wiggum, compound-engineering, etc.). Plugins are mounted from the host.
- Run Ralph Wiggum loops (`/ralph-loop`) for autonomous iteration.

## What You Cannot Do

- Access the host filesystem outside of `/workspace`.
- Use MCP servers (they are not available in this sandbox).
- Access the host's macOS Keychain or system services.
- Persist data between sessions (container is destroyed on exit).

## Guidelines

- If you need a tool or package that isn't installed, just install it. The container is ephemeral.
- Prefer making small, incremental changes that are easy to review via git diff.
- If the project has its own CLAUDE.md, follow those instructions as well. This file provides sandbox-specific context only.
