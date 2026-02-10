#!/bin/bash
set -euo pipefail

# ── Playpen Setup ──────────────────────────────────────────────────────────────
# One-time setup for the Playpen sandboxed Claude Code environment.
# Uses Colima + Docker on macOS (Apple Silicon).
# Safe to run multiple times (idempotent).
# ───────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Colors ─────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

info()    { echo -e "${BLUE}[info]${NC}  $*"; }
success() { echo -e "${GREEN}[ok]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[warn]${NC}  $*"; }
error()   { echo -e "${RED}[error]${NC} $*"; }
step()    { echo -e "\n${BOLD}── $* ──${NC}"; }

# ── Step 1: Check Homebrew ─────────────────────────────────────────────────────
step "Checking Homebrew"

if ! command -v brew &>/dev/null; then
    error "Homebrew is not installed."
    echo ""
    echo "  Install it first:"
    echo "    /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    echo ""
    echo "  Then re-run this script."
    exit 1
fi

success "Homebrew found at $(which brew)"

# ── Step 2: Install Colima and Docker CLI ──────────────────────────────────────
step "Installing Colima and Docker CLI"

installed_colima=false
installed_docker=false

if command -v colima &>/dev/null; then
    success "Colima already installed ($(colima version 2>/dev/null | head -1 || echo 'unknown version'))"
else
    info "Installing Colima via Homebrew..."
    brew install colima
    installed_colima=true
    success "Colima installed"
fi

if command -v docker &>/dev/null; then
    success "Docker CLI already installed ($(docker --version 2>/dev/null || echo 'unknown version'))"
else
    info "Installing Docker CLI via Homebrew..."
    brew install docker
    installed_docker=true
    success "Docker CLI installed"
fi

# ── Step 3: Start Colima ──────────────────────────────────────────────────────
step "Starting Colima"

if colima status &>/dev/null; then
    success "Colima is already running"
else
    info "Starting Colima (2 CPUs, 4GB RAM, aarch64)..."
    colima start --cpu 2 --memory 4 --arch aarch64
    success "Colima started"
fi

# ── Step 4: Build the Playpen Docker image ────────────────────────────────────
step "Building Playpen Docker image"

if [ ! -f "$SCRIPT_DIR/Dockerfile" ]; then
    error "Dockerfile not found in $SCRIPT_DIR"
    echo "  The Dockerfile must exist alongside this setup script."
    exit 1
fi

info "Building image from $SCRIPT_DIR..."
docker build -t playpen "$SCRIPT_DIR"
success "Docker image 'playpen' built"

# ── Step 5: Symlink launcher ──────────────────────────────────────────────────
step "Creating launcher symlink"

if [ ! -f "$SCRIPT_DIR/launcher.sh" ]; then
    warn "launcher.sh not found in $SCRIPT_DIR -- skipping symlink"
    warn "Create launcher.sh and re-run this script to set up the symlink."
else
    mkdir -p ~/.local/bin
    ln -sf "$SCRIPT_DIR/launcher.sh" ~/.local/bin/playpen
    success "Symlinked ~/.local/bin/playpen -> $SCRIPT_DIR/launcher.sh"
fi

# ── Step 6: Check PATH ───────────────────────────────────────────────────────
step "Checking PATH"

if echo "$PATH" | tr ':' '\n' | grep -qx "$HOME/.local/bin"; then
    success "~/.local/bin is in your PATH"
else
    warn "~/.local/bin is NOT in your PATH"
    echo ""
    echo "  Add it by appending this line to your shell profile:"
    echo ""
    echo "    export PATH=\"\$HOME/.local/bin:\$PATH\""
    echo ""
    echo "  For zsh (~/.zshrc):   echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.zshrc"
    echo "  For bash (~/.bashrc): echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.bashrc"
    echo ""
    echo "  Then restart your terminal or run: source ~/.zshrc"
fi

# ── Step 7: Run Quick Action installer ────────────────────────────────────────
step "Installing Quick Action"

if [ -f "$SCRIPT_DIR/install-quick-action.sh" ]; then
    info "Running install-quick-action.sh..."
    bash "$SCRIPT_DIR/install-quick-action.sh"
    success "Quick Action installer finished"
else
    warn "install-quick-action.sh not found in $SCRIPT_DIR -- skipping"
    warn "Create it and re-run this script to install the Quick Action."
fi

# ── Step 8: Summary ──────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}════════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD}  Playpen setup complete${NC}"
echo -e "${BOLD}════════════════════════════════════════${NC}"
echo ""
echo "  What was set up:"
echo "    - Colima ............. $(command -v colima)"
echo "    - Docker CLI ......... $(command -v docker)"
echo "    - Colima VM .......... running (2 CPUs, 4GB RAM)"
echo "    - Docker image ....... playpen"
if [ -f "$SCRIPT_DIR/launcher.sh" ]; then
echo "    - Launcher symlink ... ~/.local/bin/playpen"
fi
echo ""
echo "  Next steps:"
if ! echo "$PATH" | tr ':' '\n' | grep -qx "$HOME/.local/bin"; then
echo "    1. Add ~/.local/bin to your PATH (see warning above)"
echo "    2. Run 'playpen' to launch a sandboxed session"
else
echo "    1. Run 'playpen' to launch a sandboxed session"
fi
echo ""
