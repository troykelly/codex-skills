#!/bin/bash
set -e

echo "=== Codex Skills Dev Container: Post-Start ==="

# Source nvm and use project's Node version
export NVM_DIR="${HOME}/.nvm"
[ -s "/usr/local/share/nvm/nvm.sh" ] && . "/usr/local/share/nvm/nvm.sh"
cd /workspaces/budget
nvm use 2>/dev/null || true

# Ensure pnpm is available
export PNPM_HOME="/home/vscode/.local/share/pnpm"
export PATH="${PNPM_HOME}:${PATH}"

echo ""
echo "=== Development Environment Ready ==="
echo ""
echo "Node.js: $(node --version)"
echo ""
