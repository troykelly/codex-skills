FROM mcr.microsoft.com/devcontainers/python:3.14-trixie

ENV PYTHONUNBUFFERED 1
ENV DEBIAN_FRONTEND=noninteractive

# Install additional tools via apt
RUN apt-get update && apt-get install -y --no-install-recommends \
    #
    # === Build & Compilation ===
    build-essential \
    cmake \
    python3 \
    python3-venv \
    #
    # === Version Control ===
    git-lfs \
    gnupg \
    #
    # === Database Clients ===
    postgresql-client \
    redis-tools \
    sqlite3 \
    #
    # === Data Processing (JSON/XML) ===
    jq \
    xmlstarlet \
    #
    # === Text Search & Processing ===
    ripgrep \
    fd-find \
    bat \
    fzf \
    #
    # === File & Archive Utilities ===
    tree \
    file \
    zip \
    unzip \
    gzip \
    bzip2 \
    xz-utils \
    p7zip-full \
    #
    # === Network & HTTP Tools ===
    curl \
    wget \
    httpie \
    openssh-client \
    dnsutils \
    iputils-ping \
    netcat-openbsd \
    socat \
    #
    # === System Monitoring & Debugging ===
    htop \
    procps \
    lsof \
    strace \
    #
    # === Terminal & Editor ===
    tmux \
    neovim \
    less \
    #
    # === Shell & Script Development ===
    shellcheck \
    shfmt \
    #
    # === Development Utilities ===
    entr \
    direnv \
    parallel \
    gettext \
    #
    # === Core System ===
    coreutils \
    ca-certificates \
    locales \
    #
    # === Native Module Dependencies ===
    libsecret-1-dev \
    #
    # Clean up apt cache
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 25.x from NodeSource
RUN rm -Rf /usr/bin/yarn /usr/bin/yarnpkg; \
    curl -fsSL https://deb.nodesource.com/setup_25.x | bash - \
    && apt-get install -y nodejs \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && npm install -g corepack \
    && corepack enable pnpm

# Create symlinks for better tool names (Debian package naming quirks)
RUN ln -sf /usr/bin/batcat /usr/local/bin/bat \
    && ln -sf /usr/bin/fdfind /usr/local/bin/fd

# Use bash with pipefail for commands with pipes
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install yq (YAML processor) - Mike Farah's Go implementation
# https://github.com/mikefarah/yq
ARG YQ_VERSION=v4.45.1
RUN ARCH=$(dpkg --print-architecture) && \
    curl -fsSL "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_${ARCH}" \
    -o /usr/local/bin/yq \
    && chmod +x /usr/local/bin/yq

# Install GitHub CLI (gh) for repository management and API access
# https://github.com/cli/cli
ARG GH_VERSION=2.65.0
RUN ARCH=$(dpkg --print-architecture) && \
    curl -fsSL "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_${ARCH}.tar.gz" \
    | tar -xz -C /tmp \
    && mv "/tmp/gh_${GH_VERSION}_linux_${ARCH}/bin/gh" /usr/local/bin/gh \
    && chmod +x /usr/local/bin/gh \
    && rm -rf /tmp/gh_*

# Install delta (better git diffs with syntax highlighting)
# https://github.com/dandavison/delta
ARG DELTA_VERSION=0.18.2
RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "aarch64" ]; then DELTA_ARCH="aarch64-unknown-linux-gnu"; \
    else DELTA_ARCH="x86_64-unknown-linux-gnu"; fi && \
    curl -fsSL "https://github.com/dandavison/delta/releases/download/${DELTA_VERSION}/delta-${DELTA_VERSION}-${DELTA_ARCH}.tar.gz" \
    | tar -xz -C /tmp \
    && mv "/tmp/delta-${DELTA_VERSION}-${DELTA_ARCH}/delta" /usr/local/bin/delta \
    && chmod +x /usr/local/bin/delta \
    && rm -rf /tmp/delta-*

# Install lazygit (terminal UI for git)
# https://github.com/jesseduffield/lazygit
ARG LAZYGIT_VERSION=0.44.1
RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "aarch64" ]; then LG_ARCH="arm64"; else LG_ARCH="x86_64"; fi && \
    curl -fsSL "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_Linux_${LG_ARCH}.tar.gz" \
    | tar -xz -C /tmp \
    && mv /tmp/lazygit /usr/local/bin/lazygit \
    && chmod +x /usr/local/bin/lazygit \
    && rm -rf /tmp/lazygit*

# Install uv (Python package manager) and uvx from Astral's official image
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv
COPY --from=ghcr.io/astral-sh/uv:latest /uvx /usr/local/bin/uvx

# Configure git to use delta for diffs (can be overridden by user config)
RUN git config --system core.pager delta \
    && git config --system interactive.diffFilter "delta --color-only" \
    && git config --system delta.navigate true \
    && git config --system delta.line-numbers true \
    && git config --system delta.side-by-side false \
    && git config --system merge.conflictstyle diff3 \
    && git config --system diff.colorMoved default

# Initialize git-lfs
RUN git lfs install --system