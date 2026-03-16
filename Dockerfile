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
# Home directory for non-root runtime user
# Claude Code refuses --dangerously-skip-permissions as root, so we run as
# the host user's UID at launch (--user). This pre-created home directory
# with open permissions lets any UID write to ~/.claude/ etc.
# ---------------------------------------------------------------------------
RUN mkdir -p /home/playpen/.claude && chmod -R 777 /home/playpen
ENV HOME=/home/playpen

# ---------------------------------------------------------------------------
# Workspace setup
# ---------------------------------------------------------------------------
WORKDIR /workspace

# ---------------------------------------------------------------------------
# Entrypoint - launch Claude Code with permissions pre-approved
# ---------------------------------------------------------------------------
ENTRYPOINT ["claude", "--dangerously-skip-permissions"]
