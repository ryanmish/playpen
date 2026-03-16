# =============================================================================
# Playpen - Sandboxed Claude Code Environment
# A container that gives Claude Code everything it needs to work on any project.
# =============================================================================

FROM node:22-slim

LABEL org.opencontainers.image.title="Playpen"
LABEL org.opencontainers.image.description="Sandboxed Claude Code environment with full dev tooling"

# ---------------------------------------------------------------------------
# System packages + GitHub CLI
# ---------------------------------------------------------------------------
# 1) Install core dev tools and dependencies
# 2) Add GitHub CLI apt repository and install gh
# 3) Clean up apt cache to keep the image small
# ---------------------------------------------------------------------------
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        git \
        python3 \
        python3-pip \
        ripgrep \
        jq \
        curl \
        openssh-client \
        build-essential \
        gpg && \
    # GitHub CLI - official install method for Debian
    mkdir -p -m 755 /etc/apt/keyrings && \
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | gpg --dearmor -o /etc/apt/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        > /etc/apt/sources.list.d/github-cli.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends gh && \
    # Cleanup
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# Claude Code
# ---------------------------------------------------------------------------
RUN npm install -g @anthropic-ai/claude-code

# ---------------------------------------------------------------------------
# Non-root user (Claude Code refuses --dangerously-skip-permissions as root)
# ---------------------------------------------------------------------------
RUN useradd -m -s /bin/bash -u 1001 playpen
USER playpen

# ---------------------------------------------------------------------------
# Workspace setup
# ---------------------------------------------------------------------------
WORKDIR /workspace

# ---------------------------------------------------------------------------
# Entrypoint - launch Claude Code with permissions pre-approved
# ---------------------------------------------------------------------------
ENTRYPOINT ["claude", "--dangerously-skip-permissions"]
