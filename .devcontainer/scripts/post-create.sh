#!/bin/bash
set -e

echo "=== Codex Skills Dev Container: Post-Create Setup ==="

# ==============================================================================
# PNPM DIRECTORY SETUP - DO NOT REMOVE OR SIMPLIFY
# ==============================================================================
# pnpm 10.x requires the .tools subdirectory to exist with write permissions
# BEFORE any pnpm command runs. Without this, you'll get:
#   EACCES: permission denied, mkdir '/home/vscode/.local/share/pnpm/.tools/...'
#
# The codex-skills-vscode-home volume mounts /home/vscode which Docker creates as root.
# We MUST fix ownership unconditionally - checking first is unreliable.
# ==============================================================================
export PNPM_HOME="/home/vscode/.local/share/pnpm"
export PATH="${PNPM_HOME}:${PATH}"

# Create pnpm directories using sudo to handle any ownership situation
echo "Setting up pnpm directories..."
sudo mkdir -p "${PNPM_HOME}/.tools"   # REQUIRED: pnpm stores version management files here
sudo mkdir -p "${PNPM_HOME}/store"    # REQUIRED: pnpm package store location

# Fix ownership of entire .local tree unconditionally
# This ensures vscode user can write regardless of how volume was initialized
sudo chown -R vscode:vscode /home/vscode/.local
# ==============================================================================

# Install pnpm if not available
if ! command -v pnpm &> /dev/null; then
    echo "Installing pnpm..."
    npm install -g pnpm@10.24.0
fi

echo "pnpm version: $(pnpm --version)"

# Install Claude CLI globally
echo "Installing Claude CLI..."
curl -fsSL https://raw.githubusercontent.com/troykelly/claude-skills/main/install.sh | bash

# Set up git safe directory
if [ -d /workspaces/codex-skills/.git ]; then
    git config --global --add safe.directory /workspaces/codex-skills
fi

# Prompt user to configure git if not already done
if [ -z "$(git config --global user.email)" ]; then
    echo ""
    echo "NOTE: Git user config not set. Run these commands to configure:"
    echo "  git config --global user.name \"Your Name\""
    echo "  git config --global user.email \"your@email.com\""
fi

# Set up zsh customizations (idempotent - only adds if marker not present)
KIN_ZSHRC_MARKER="# >>> budgeter devcontainer config >>>"
if ! grep -q "$KIN_ZSHRC_MARKER" /home/vscode/.zshrc 2>/dev/null; then
    echo "Adding Codex Skills customizations to .zshrc..."
    cat >> /home/vscode/.zshrc << 'ZSHRC'

# >>> budgeter devcontainer config >>>
# DO NOT EDIT - managed by .devcontainer/scripts/post-create.sh

# pnpm
export PNPM_HOME="/home/vscode/.local/share/pnpm"
export PATH="${PNPM_HOME}:${PATH}"

# GitHub token for MCP plugins (from gh CLI)
if command -v gh &> /dev/null && gh auth status &> /dev/null 2>&1; then
    export GITHUB_TOKEN=$(gh auth token 2>/dev/null)
fi

# <<< budgeter devcontainer config <<<
ZSHRC
else
    echo "Codex Skills .zshrc customizations already present, skipping..."
fi

echo ""
echo "=== Post-Create Setup Complete ==="
echo ""
echo "Node.js: $(node --version)"
echo "pnpm:    $(pnpm --version)"
echo "Claude:  $(claude --version 2>/dev/null || echo 'installed')"
echo ""
