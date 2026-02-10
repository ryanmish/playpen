#!/bin/bash
# =============================================================================
# Playpen Launcher
# Main entry point for running Claude Code in a sandboxed Docker container.
# Usage: launcher.sh <path-to-project-folder>
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Variables
# ---------------------------------------------------------------------------

# Directory where this script lives (contains Dockerfile, sandbox-claude.md, etc.)
PLAYPEN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="playpen"
CLAUDE_CONFIG="$HOME/.claude.json"

# ---------------------------------------------------------------------------
# Colors
# ---------------------------------------------------------------------------

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

info()    { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# ---------------------------------------------------------------------------
# 1. Validate argument
# ---------------------------------------------------------------------------

if [[ $# -lt 1 ]]; then
    echo -e "${BOLD}Usage:${NC} $(basename "$0") <path-to-project-folder>"
    echo ""
    echo "  Launches Claude Code inside a sandboxed Docker container"
    echo "  with the given project folder mounted at /workspace."
    echo ""
    echo "  Example:"
    echo "    $(basename "$0") ~/Dev/my-project"
    exit 1
fi

FOLDER_PATH="$(cd "$1" 2>/dev/null && pwd)" || {
    error "Path does not exist or is not accessible: $1"
    exit 1
}

if [[ ! -d "$FOLDER_PATH" ]]; then
    error "Not a directory: $FOLDER_PATH"
    exit 1
fi

FOLDER_NAME="$(basename "$FOLDER_PATH")"

# ---------------------------------------------------------------------------
# 2. Print banner
# ---------------------------------------------------------------------------

# Calculate the width needed for the project name line
BANNER_TEXT="Playpen - Sandboxed Claude Code"
PROJECT_TEXT="Project: $FOLDER_NAME"

# Find the longer line to set box width
if [[ ${#BANNER_TEXT} -ge ${#PROJECT_TEXT} ]]; then
    INNER_WIDTH=$(( ${#BANNER_TEXT} + 2 ))
else
    INNER_WIDTH=$(( ${#PROJECT_TEXT} + 2 ))
fi

# Build the horizontal border
BORDER=""
for (( i=0; i<INNER_WIDTH; i++ )); do
    BORDER="${BORDER}─"
done

# Pad each line to fill the box
pad_line() {
    local text="$1"
    local padding=$(( INNER_WIDTH - ${#text} - 1 ))
    local spaces=""
    for (( i=0; i<padding; i++ )); do
        spaces="${spaces} "
    done
    echo " ${text}${spaces}"
}

echo -e "${CYAN}"
echo "╭${BORDER}╮"
echo "│$(pad_line "$BANNER_TEXT")│"
echo "│$(pad_line "$PROJECT_TEXT")│"
echo "╰${BORDER}╯"
echo -e "${NC}"

# ---------------------------------------------------------------------------
# 3. Check Colima (Docker runtime for macOS)
# ---------------------------------------------------------------------------

if ! command -v colima &>/dev/null; then
    error "Colima is not installed. Install it with: brew install colima"
    exit 1
fi

if colima status &>/dev/null; then
    info "Colima is running."
else
    warn "Colima is not running. Starting it now..."
    colima start --cpu 2 --memory 4 --arch aarch64 &
    COLIMA_PID=$!

    TIMEOUT=60
    ELAPSED=0
    while ! colima status &>/dev/null; do
        if [[ $ELAPSED -ge $TIMEOUT ]]; then
            error "Colima failed to start within ${TIMEOUT}s."
            exit 1
        fi
        sleep 2
        ELAPSED=$((ELAPSED + 2))
        echo -ne "  Waiting for Colima... ${ELAPSED}s / ${TIMEOUT}s\r"
    done
    echo "" # clear the \r line
    info "Colima started successfully (${ELAPSED}s)."
fi

# ---------------------------------------------------------------------------
# 4. Check / build Docker image
# ---------------------------------------------------------------------------

if docker image inspect "$IMAGE_NAME" &>/dev/null; then
    info "Docker image '$IMAGE_NAME' found."
else
    warn "Docker image '$IMAGE_NAME' not found. Building from Dockerfile..."
    docker build -t "$IMAGE_NAME" "$PLAYPEN_DIR"
    info "Docker image '$IMAGE_NAME' built successfully."
fi

# ---------------------------------------------------------------------------
# 5. Authentication
# ---------------------------------------------------------------------------
# Claude Code uses OAuth by default (no raw API key in ~/.claude.json).
# We mount ~/.claude.json into the container to carry over the auth state.
# If ANTHROPIC_API_KEY is set in the environment, we also pass it through.

if [[ -f "$CLAUDE_CONFIG" ]]; then
    info "Found $CLAUDE_CONFIG (will mount into container for auth)."
else
    warn "$CLAUDE_CONFIG not found."
    if [[ -z "${ANTHROPIC_API_KEY:-}" ]]; then
        error "No authentication found. Either run 'claude' once to log in, or set ANTHROPIC_API_KEY."
        exit 1
    fi
fi

# ---------------------------------------------------------------------------
# 6. Build the docker run command
# ---------------------------------------------------------------------------

# Sanitize folder name for use as Docker container name.
# Docker allows [a-zA-Z0-9_.-] in container names.
SAFE_NAME="$(echo "$FOLDER_NAME" | tr -cs 'a-zA-Z0-9_.-' '-' | sed 's/^-//;s/-$//')"
CONTAINER_NAME="playpen-${SAFE_NAME}"

# Start assembling the docker run arguments
DOCKER_ARGS=(
    run --rm -it
    --name "$CONTAINER_NAME"
    -v "$FOLDER_PATH":/workspace
    -w /workspace
)

# Mount Claude config for OAuth auth
if [[ -f "$CLAUDE_CONFIG" ]]; then
    DOCKER_ARGS+=(-v "$CLAUDE_CONFIG":/root/.claude.json:ro)
    info "Mounting ~/.claude.json (auth)"
fi

# Pass API key if set in environment
if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
    DOCKER_ARGS+=(-e ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY")
    info "Passing ANTHROPIC_API_KEY from environment"
fi

# Conditionally mount .gitconfig (read-only)
if [[ -f "$HOME/.gitconfig" ]]; then
    DOCKER_ARGS+=(-v "$HOME/.gitconfig":/root/.gitconfig:ro)
    info "Mounting ~/.gitconfig"
else
    warn "~/.gitconfig not found, skipping mount."
fi

# Mount Claude Code plugins (read-only)
# Two mounts needed: one at /root/.claude/plugins so Claude finds installed_plugins.json,
# and one at the host's absolute path so the installPath values in the JSON resolve.
CLAUDE_PLUGINS_DIR="$HOME/.claude/plugins"
if [[ -d "$CLAUDE_PLUGINS_DIR" ]]; then
    DOCKER_ARGS+=(-v "$CLAUDE_PLUGINS_DIR":/root/.claude/plugins:ro)
    DOCKER_ARGS+=(-v "$CLAUDE_PLUGINS_DIR":"$CLAUDE_PLUGINS_DIR":ro)
    info "Mounting ~/.claude/plugins (plugins: ralph-wiggum, etc.)"
else
    warn "~/.claude/plugins not found, no plugins will be available."
fi

# Mount sandbox-claude.md as the container's CLAUDE.md if it exists
if [[ -f "$PLAYPEN_DIR/sandbox-claude.md" ]]; then
    DOCKER_ARGS+=(-v "$PLAYPEN_DIR/sandbox-claude.md":/root/.claude/CLAUDE.md:ro)
    info "Mounting sandbox-claude.md as container CLAUDE.md"
else
    warn "sandbox-claude.md not found in $PLAYPEN_DIR, no CLAUDE.md will be injected."
fi

# Add the image name last
DOCKER_ARGS+=("$IMAGE_NAME")

# ---------------------------------------------------------------------------
# 7. Launch
# ---------------------------------------------------------------------------

echo ""
info "Launching container '${CONTAINER_NAME}'..."
echo -e "  ${BOLD}Workspace:${NC} $FOLDER_PATH -> /workspace"
echo ""

exec docker "${DOCKER_ARGS[@]}"
