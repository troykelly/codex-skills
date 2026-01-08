#!/usr/bin/env bash
#
# install.sh - Install codex-autonomous, codex-account, codex-hook-runner, codex-subagent, Codex skills, and optional MCP helpers
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/troykelly/codex-skills/main/install.sh | bash
#
# Or clone and run:
#   git clone https://github.com/troykelly/codex-skills.git
#   cd codex-skills && ./install.sh
#
# Options (via environment variables):
#   INSTALL_DIR      Where to install helper scripts (default: /usr/local/bin)
#   SKIP_DEPS        Skip dependency installation (default: false)
#   SKIP_CODEX_CLI   Skip Codex CLI installation (default: false)
#   SKIP_MCP         Skip MCP server configuration (default: false)
#   SKIP_SKILLS      Skip skill installation to $CODEX_HOME/skills (default: false)
#   SKIP_HOOKS       Skip hook installation to $CODEX_HOME/hooks (default: false)
#   SKIP_PLAYWRIGHT  Skip Playwright browser installation (default: false)
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Configuration
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"
SKIP_DEPS="${SKIP_DEPS:-false}"
SKIP_CODEX_CLI="${SKIP_CODEX_CLI:-false}"
SKIP_MCP="${SKIP_MCP:-false}"
SKIP_SKILLS="${SKIP_SKILLS:-false}"
SKIP_HOOKS="${SKIP_HOOKS:-false}"
SKIP_PLAYWRIGHT="${SKIP_PLAYWRIGHT:-false}"

REPO_URL="https://github.com/troykelly/codex-skills"
RAW_URL="https://raw.githubusercontent.com/troykelly/codex-skills/main"

TMP_REPO_PARENT=""
TMP_REPO_DIR=""

# Logging
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

has_cmd() { command -v "$1" &>/dev/null; }

cleanup_tmp_repo() {
  if [[ -n "$TMP_REPO_PARENT" && -d "$TMP_REPO_PARENT" ]]; then
    rm -rf "$TMP_REPO_PARENT"
  fi
}

fetch_repo_archive() {
  if [[ -n "$TMP_REPO_DIR" && -d "$TMP_REPO_DIR" ]]; then
    echo "$TMP_REPO_DIR"
    return 0
  fi

  if ! has_cmd tar; then
    log_warn "tar not found; cannot download repository archive"
    return 1
  fi

  TMP_REPO_PARENT=$(mktemp -d)
  if ! curl -fsSL "${REPO_URL}/archive/refs/heads/main.tar.gz" | tar -xz -C "$TMP_REPO_PARENT"; then
    log_warn "Failed to download repository archive"
    rm -rf "$TMP_REPO_PARENT"
    TMP_REPO_PARENT=""
    return 1
  fi

  TMP_REPO_DIR=$(ls -d "${TMP_REPO_PARENT}"/codex-skills-* 2>/dev/null | head -n 1)
  if [[ -z "$TMP_REPO_DIR" || ! -d "$TMP_REPO_DIR" ]]; then
    log_warn "Repository archive missing expected contents"
    rm -rf "$TMP_REPO_PARENT"
    TMP_REPO_PARENT=""
    TMP_REPO_DIR=""
    return 1
  fi

  echo "$TMP_REPO_DIR"
}

trap cleanup_tmp_repo EXIT

# Detect OS and package manager
detect_os() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
    PKG_MGR="brew"
  elif [[ -f /etc/debian_version ]]; then
    OS="debian"
    PKG_MGR="apt"
  elif [[ -f /etc/fedora-release ]]; then
    OS="fedora"
    PKG_MGR="dnf"
  elif [[ -f /etc/redhat-release ]]; then
    OS="redhat"
    if has_cmd dnf; then
      PKG_MGR="dnf"
    else
      PKG_MGR="yum"
    fi
  elif [[ -f /etc/arch-release ]]; then
    OS="arch"
    PKG_MGR="pacman"
  elif [[ -f /etc/alpine-release ]]; then
    OS="alpine"
    PKG_MGR="apk"
  else
    OS="unknown"
    PKG_MGR="unknown"
  fi
}

check_connectivity() {
  log_info "Checking network connectivity..."
  if ! curl -fsSL --connect-timeout 5 https://github.com &>/dev/null; then
    log_error "Cannot reach github.com - check your internet connection"
    exit 1
  fi
  log_success "Network connectivity OK"
}

maybe_sudo() {
  if [[ $EUID -ne 0 ]]; then
    if has_cmd sudo; then
      sudo "$@"
    else
      log_error "Need root privileges. Please run as root or install sudo."
      exit 1
    fi
  else
    "$@"
  fi
}

run_brew() {
  if ! has_cmd brew; then
    log_error "brew not found"
    return 1
  fi

  local brew_path
  brew_path=$(which brew)
  local brew_owner
  if [[ "$OS" == "macos" ]]; then
    brew_owner=$(stat -f '%Su' "$brew_path" 2>/dev/null)
  else
    brew_owner=$(stat -c '%U' "$brew_path" 2>/dev/null)
  fi

  local current_user
  current_user=$(whoami)

  if [[ "$brew_owner" != "$current_user" && -n "$brew_owner" ]]; then
    log_info "Running brew as '$brew_owner' (brew owner)..."
    if has_cmd sudo; then
      sudo -u "$brew_owner" brew "$@"
    else
      log_warn "Cannot sudo to brew owner '$brew_owner'"
      brew "$@"
    fi
  else
    brew "$@"
  fi
}

install_pkg() {
  local cmd="$1"
  local pkg_apt="${2:-$cmd}"
  local pkg_yum="${3:-$cmd}"
  local pkg_brew="${4:-$cmd}"
  local pkg_pacman="${5:-$cmd}"
  local pkg_apk="${6:-$cmd}"

  if has_cmd "$cmd"; then
    log_success "$cmd already installed"
    return 0
  fi

  log_info "Installing $cmd..."

  case "$PKG_MGR" in
    apt)
      maybe_sudo apt-get update -qq
      maybe_sudo apt-get install -y -qq "$pkg_apt"
      ;;
    dnf)
      maybe_sudo dnf install -y -q "$pkg_yum"
      ;;
    yum)
      maybe_sudo yum install -y -q "$pkg_yum"
      ;;
    brew)
      run_brew install "$pkg_brew"
      ;;
    pacman)
      maybe_sudo pacman -S --noconfirm "$pkg_pacman"
      ;;
    apk)
      maybe_sudo apk add --quiet "$pkg_apk"
      ;;
    *)
      log_warn "Unknown package manager. Please install $cmd manually."
      return 1
      ;;
  esac

  if has_cmd "$cmd"; then
    log_success "$cmd installed successfully"
  else
    log_error "Failed to install $cmd"
  fi
}

install_gh() {
  if has_cmd gh; then
    log_success "gh (GitHub CLI) already installed"
    return 0
  fi

  log_info "Installing GitHub CLI..."

  case "$PKG_MGR" in
    apt)
      maybe_sudo mkdir -p -m 755 /etc/apt/keyrings
      curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | maybe_sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
      maybe_sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | maybe_sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
      maybe_sudo apt-get update -qq
      maybe_sudo apt-get install -y -qq gh
      ;;
    dnf)
      maybe_sudo dnf install -y -q 'dnf-command(config-manager)' 2>/dev/null || true
      maybe_sudo dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
      maybe_sudo dnf install -y -q gh
      ;;
    yum)
      maybe_sudo yum-config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
      maybe_sudo yum install -y -q gh
      ;;
    brew)
      run_brew install gh
      ;;
    pacman)
      maybe_sudo pacman -S --noconfirm github-cli
      ;;
    apk)
      maybe_sudo apk add --quiet github-cli
      ;;
    *)
      log_warn "Please install GitHub CLI manually: https://cli.github.com/"
      return 1
      ;;
  esac

  if has_cmd gh; then
    log_success "GitHub CLI installed successfully"
  else
    log_error "Failed to install GitHub CLI"
  fi
}

install_uv() {
  if has_cmd uvx; then
    log_success "uv/uvx already installed ($(uv --version 2>/dev/null || echo 'version unknown'))"
    return 0
  fi

  log_info "Installing uv (Python package manager with uvx)..."
  curl -LsSf https://astral.sh/uv/install.sh | sh

  [[ -d "$HOME/.local/bin" ]] && export PATH="$HOME/.local/bin:$PATH"
  [[ -d "$HOME/.cargo/bin" ]] && export PATH="$HOME/.cargo/bin:$PATH"

  if has_cmd uvx; then
    log_success "uv/uvx installed"
  else
    log_warn "uv installed but uvx not in PATH"
  fi
}

install_node() {
  if has_cmd node; then
    log_success "Node.js already installed ($(node --version))"
    return 0
  fi

  log_info "Installing Node.js (optional, for MCP servers)..."

  case "$PKG_MGR" in
    apt)
      curl -fsSL https://deb.nodesource.com/setup_20.x | maybe_sudo bash -
      maybe_sudo apt-get install -y -qq nodejs
      ;;
    dnf)
      curl -fsSL https://rpm.nodesource.com/setup_20.x | maybe_sudo bash -
      maybe_sudo dnf install -y -q nodejs
      ;;
    yum)
      curl -fsSL https://rpm.nodesource.com/setup_20.x | maybe_sudo bash -
      maybe_sudo yum install -y -q nodejs
      ;;
    brew)
      run_brew install node
      ;;
    pacman)
      maybe_sudo pacman -S --noconfirm nodejs npm
      ;;
    apk)
      maybe_sudo apk add --quiet nodejs npm
      ;;
    *)
      log_warn "Please install Node.js manually: https://nodejs.org/"
      return 1
      ;;
  esac

  if has_cmd node; then
    log_success "Node.js installed ($(node --version))"
  fi
}

install_playwright() {
  if ! has_cmd node; then
    log_warn "Node.js required for Playwright - installing..."
    install_node
  fi

  if ! has_cmd npx; then
    log_warn "npx not found - Node.js installation may be incomplete"
    log_info "Try: npm install -g npx"
    return 1
  fi

  if npx playwright --version &>/dev/null 2>&1; then
    log_success "Playwright already installed ($(npx playwright --version 2>/dev/null || echo 'version unknown'))"
    return 0
  fi

  log_info "Installing Playwright with Chromium browser..."
  npm install -g playwright 2>/dev/null || true

  log_info "Installing Chromium browser and system dependencies..."
  case "$PKG_MGR" in
    apt|dnf|yum|pacman|apk)
      maybe_sudo npx playwright install --with-deps chromium 2>/dev/null || npx playwright install chromium 2>/dev/null || true
      ;;
    brew)
      npx playwright install --with-deps chromium 2>/dev/null || npx playwright install chromium 2>/dev/null || true
      ;;
    *)
      npx playwright install chromium 2>/dev/null || true
      ;;
  esac

  if npx playwright --version &>/dev/null 2>&1; then
    log_success "Playwright installed with Chromium"
  else
    log_warn "Playwright may need manual setup: npx playwright install --with-deps chromium"
  fi
}

install_1password_cli() {
  if has_cmd op; then
    log_success "1Password CLI already installed ($(op --version 2>/dev/null || echo 'version unknown'))"
    return 0
  fi

  log_info "Installing 1Password CLI (optional)..."

  case "$PKG_MGR" in
    apt)
      maybe_sudo mkdir -p -m 755 /usr/share/keyrings
      curl -sS https://downloads.1password.com/linux/keys/1password.asc | maybe_sudo gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg 2>/dev/null || \
        curl -sS https://downloads.1password.com/linux/keys/1password.asc | maybe_sudo tee /usr/share/keyrings/1password-archive-keyring.gpg > /dev/null
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/$(dpkg --print-architecture) stable main" | maybe_sudo tee /etc/apt/sources.list.d/1password.list > /dev/null
      maybe_sudo apt-get update -qq
      maybe_sudo apt-get install -y -qq 1password-cli
      ;;
    dnf)
      maybe_sudo rpm --import https://downloads.1password.com/linux/keys/1password.asc
      # shellcheck disable=SC2016
      maybe_sudo sh -c 'echo -e "[1password]\nname=1Password Stable Channel\nbaseurl=https://downloads.1password.com/linux/rpm/stable/\$basearch\nenabled=1\ngpgcheck=1\nrepo_gpgcheck=1\ngpgkey=https://downloads.1password.com/linux/keys/1password.asc" > /etc/yum.repos.d/1password.repo'
      maybe_sudo dnf install -y -q 1password-cli
      ;;
    yum)
      maybe_sudo rpm --import https://downloads.1password.com/linux/keys/1password.asc
      # shellcheck disable=SC2016
      maybe_sudo sh -c 'echo -e "[1password]\nname=1Password Stable Channel\nbaseurl=https://downloads.1password.com/linux/rpm/stable/\$basearch\nenabled=1\ngpgcheck=1\nrepo_gpgcheck=1\ngpgkey=https://downloads.1password.com/linux/keys/1password.asc" > /etc/yum.repos.d/1password.repo'
      maybe_sudo yum install -y -q 1password-cli
      ;;
    brew)
      run_brew install --cask 1password-cli
      ;;
    pacman)
      log_warn "Install 1Password CLI manually on Arch"
      return 0
      ;;
    apk)
      log_warn "Install 1Password CLI manually on Alpine"
      return 0
      ;;
    *)
      log_warn "Install 1Password CLI manually: https://developer.1password.com/docs/cli/"
      return 0
      ;;
  esac

  if has_cmd op; then
    log_success "1Password CLI installed"
  else
    log_warn "1Password CLI installation incomplete"
  fi
}

install_codex_cli() {
  if has_cmd codex; then
    log_success "Codex CLI already installed ($(codex --version 2>/dev/null || echo 'version unknown'))"
    return 0
  fi

  log_info "Installing Codex CLI (@openai/codex)..."

  if ! has_cmd node; then
    log_warn "Node.js required for Codex CLI - installing..."
    install_node
  fi

  if ! has_cmd pnpm; then
    if has_cmd corepack; then
      log_info "Enabling pnpm via corepack..."
      corepack enable >/dev/null 2>&1 || true
      corepack prepare pnpm@latest --activate >/dev/null 2>&1 || true
    fi
  fi

  if ! has_cmd pnpm; then
    log_warn "pnpm not found. Install pnpm (corepack or https://pnpm.io/installation) and retry."
    return 1
  fi

  if pnpm add -g @openai/codex 2>/dev/null; then
    true
  else
    log_warn "pnpm global install failed; retrying with sudo..."
    maybe_sudo pnpm add -g @openai/codex
  fi

  if has_cmd codex; then
    log_success "Codex CLI installed"
  else
    log_warn "Codex CLI installed but not in PATH"
  fi
}

install_scripts() {
  local scripts=("codex-autonomous" "codex-account" "codex-hook-runner" "codex-subagent")

  if [[ ! -d "$INSTALL_DIR" ]]; then
    maybe_sudo mkdir -p "$INSTALL_DIR"
  fi

  for script_name in "${scripts[@]}"; do
    local script_url="${RAW_URL}/scripts/${script_name}"
    local install_path="${INSTALL_DIR}/${script_name}"

    log_info "Installing ${script_name} to ${install_path}..."

    if [[ -f "scripts/${script_name}" ]]; then
      maybe_sudo cp "scripts/${script_name}" "$install_path"
    else
      curl -fsSL "$script_url" | maybe_sudo tee "$install_path" > /dev/null
    fi

    maybe_sudo chmod +x "$install_path"
    if [[ -x "$install_path" ]]; then
      log_success "Installed ${script_name}"
    else
      log_error "Failed to install ${script_name}"
    fi
  done
}

install_skills() {
  local codex_home="${CODEX_HOME:-${HOME}/.codex}"
  local dest="${codex_home}/skills"
  local src_root="."

  log_info "Installing skills to ${dest}..."
  mkdir -p "$dest"

  if [[ ! -d "skills" && ! -d "external/skills" ]]; then
    src_root=$(fetch_repo_archive || echo "")
  fi

  if [[ -z "$src_root" ]]; then
    log_warn "No skills source available; skipping"
    return 0
  fi

  # Copy first-party skills
  if [[ -d "${src_root}/skills" ]]; then
    for d in "${src_root}/skills"/*; do
      [[ -d "$d" ]] || continue
      [[ -f "$d/SKILL.md" ]] || continue
      local name
      name=$(basename "$d")
      rm -rf "${dest:?}/${name}"
      cp -R "$d" "$dest/"
    done
  else
    log_warn "No skills directory found in source; skipping first-party skills"
  fi

  # Copy external skills (imported)
  if [[ -d "${src_root}/external/skills" ]]; then
    for d in "${src_root}/external/skills"/*; do
      [[ -d "$d" ]] || continue
      [[ -f "$d/SKILL.md" ]] || continue
      local name
      name=$(basename "$d")
      rm -rf "${dest:?}/${name}"
      cp -R "$d" "$dest/"
    done
  else
    log_warn "No external skills directory found in source; skipping external skills"
  fi

  log_success "Skills installed (restart Codex to pick up changes)"
}

install_hooks() {
  if [[ "$SKIP_HOOKS" == "true" ]]; then
    log_warn "Skipping hook installation (SKIP_HOOKS=true)"
    return 0
  fi

  local codex_home="${CODEX_HOME:-${HOME}/.codex}"
  local dest="${codex_home}/hooks"
  local src_root="."
  local hook_src=""

  log_info "Installing hooks to ${dest}..."
  mkdir -p "$dest"

  if [[ ! -d "hooks" ]]; then
    src_root=$(fetch_repo_archive || echo "")
  fi

  if [[ -n "$src_root" && -d "${src_root}/hooks" ]]; then
    hook_src="${src_root}/hooks"
  elif [[ -d "hooks" ]]; then
    hook_src="hooks"
  fi

  if [[ -n "$hook_src" ]]; then
    rm -rf "${dest:?}"
    cp -R "$hook_src" "$dest"
    log_success "Hooks installed"
  else
    log_warn "No hooks directory found; skipping"
  fi
}

install_mcp_servers() {
  local codex_home="${CODEX_HOME:-${HOME}/.codex}"
  local config_file="${codex_home}/config.toml"

  log_info "Configuring MCP servers in ${config_file}..."
  mkdir -p "$codex_home"
  touch "$config_file"

  # Helper: append section if missing
  ensure_section() {
    local header="$1"
    local body="$2"
    if grep -qE "^\\[${header//./\\.}\\]$" "$config_file" 2>/dev/null; then
      log_success "MCP server already configured: ${header}"
      return 0
    fi
    {
      echo ""
      echo "[${header}]"
      echo "$body"
    } >> "$config_file"
    log_success "Configured MCP server: ${header}"
  }

  ensure_section "mcp_servers.git" 'command = "uvx"
args = ["mcp-server-git", "--repository", "."]'

  ensure_section "mcp_servers.memory" 'command = "npx"
args = ["-y", "@modelcontextprotocol/server-memory"]'

  ensure_section "mcp_servers.github" 'command = "npx"
args = ["-y", "@modelcontextprotocol/server-github"]
env_vars = ["GITHUB_PERSONAL_ACCESS_TOKEN"]'

  ensure_section "mcp_servers.playwright" 'command = "npx"
args = ["-y", "@playwright/mcp@latest"]'
}

install_subagent_profiles() {
  local codex_home="${CODEX_HOME:-${HOME}/.codex}"
  local config_file="${codex_home}/config.toml"
  local tmp_file
  local changed=false

  log_info "Configuring subagent profiles in ${config_file}..."
  mkdir -p "$codex_home"

  if [[ -f "$config_file" ]]; then
    tmp_file=$(mktemp)
    cp -p "$config_file" "$tmp_file"
  else
    tmp_file=$(mktemp)
    : > "$tmp_file"
    chmod 600 "$tmp_file" 2>/dev/null || true
  fi

  ensure_profile() {
    local name="$1"
    local model="$2"
    local sandbox_mode="$3"
    local approval_policy="$4"

    if grep -qE "^\\[profiles\\.${name//./\\.}\\]$" "$tmp_file" 2>/dev/null; then
      log_success "Profile already configured: ${name}"
      return 0
    fi

    {
      echo ""
      echo "[profiles.${name}]"
      echo "model = \"${model}\""
      echo "sandbox_mode = \"${sandbox_mode}\""
      echo "approval_policy = \"${approval_policy}\""
    } >> "$tmp_file"

    changed=true
    log_success "Configured profile: ${name}"
  }

  local model="gpt-5.2-codex"
  local sandbox_mode="workspace-write"
  local approval_policy="never"

  ensure_profile "code-reviewer" "$model" "$sandbox_mode" "$approval_policy"
  ensure_profile "security-reviewer" "$model" "$sandbox_mode" "$approval_policy"
  ensure_profile "code-architect" "$model" "$sandbox_mode" "$approval_policy"
  ensure_profile "code-explorer" "$model" "$sandbox_mode" "$approval_policy"
  ensure_profile "code-simplifier" "$model" "$sandbox_mode" "$approval_policy"
  ensure_profile "comment-analyzer" "$model" "$sandbox_mode" "$approval_policy"
  ensure_profile "pr-test-analyzer" "$model" "$sandbox_mode" "$approval_policy"
  ensure_profile "silent-failure-hunter" "$model" "$sandbox_mode" "$approval_policy"
  ensure_profile "type-design-analyzer" "$model" "$sandbox_mode" "$approval_policy"

  if [[ "$changed" == "true" ]]; then
    mv "$tmp_file" "$config_file"
  else
    rm -f "$tmp_file"
  fi
}

check_gh_auth() {
  if ! has_cmd gh; then
    return 1
  fi
  if gh auth status &>/dev/null; then
    GH_AUTHENTICATED=true
    GH_USER=$(gh api user --jq '.login' 2>/dev/null || echo "authenticated")
    log_success "GitHub CLI authenticated as: ${GH_USER}"
  else
    GH_AUTHENTICATED=false
    log_warn "GitHub CLI not authenticated"
  fi
}

main() {
  echo ""
  echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║${NC}        ${BOLD}Codex Skills - Issue-Driven Development Installer${NC}        ${CYAN}║${NC}"
  echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
  echo ""

  GH_AUTHENTICATED=false

  detect_os
  log_info "Detected OS: ${OS} (package manager: ${PKG_MGR})"
  echo ""

  check_connectivity
  echo ""

  if [[ "$SKIP_DEPS" != "true" ]]; then
    echo -e "${BOLD}Installing dependencies...${NC}"
    echo ""

    install_pkg "git" "git" "git" "git" "git" "git"
    install_pkg "curl" "curl" "curl" "curl" "curl" "curl"
    install_pkg "jq" "jq" "jq" "jq" "jq" "jq"

    install_gh
    check_gh_auth
    install_uv
    install_node
    install_1password_cli
    if [[ "$SKIP_PLAYWRIGHT" != "true" ]]; then
      install_playwright
    else
      log_info "Skipping Playwright installation (SKIP_PLAYWRIGHT=true)"
    fi
    echo ""
  else
    log_info "Skipping dependency installation (SKIP_DEPS=true)"
    check_gh_auth || true
  fi

  if [[ "$SKIP_CODEX_CLI" != "true" ]]; then
    echo -e "${BOLD}Installing Codex CLI...${NC}"
    echo ""
    install_codex_cli
    echo ""
  else
    log_info "Skipping Codex CLI installation (SKIP_CODEX_CLI=true)"
  fi

  echo -e "${BOLD}Installing helper scripts...${NC}"
  echo ""
  install_scripts
  echo ""

  if [[ "$SKIP_SKILLS" != "true" ]]; then
    echo -e "${BOLD}Installing Codex skills...${NC}"
    echo ""
    install_skills
    echo ""
  else
    log_info "Skipping skill installation (SKIP_SKILLS=true)"
  fi

  echo -e "${BOLD}Configuring subagent profiles...${NC}"
  echo ""
  install_subagent_profiles
  echo ""

  if [[ "$SKIP_HOOKS" != "true" ]]; then
    echo -e "${BOLD}Installing Codex hooks...${NC}"
    echo ""
    install_hooks
    echo ""
  else
    log_info "Skipping hook installation (SKIP_HOOKS=true)"
  fi

  if [[ "$SKIP_MCP" != "true" ]]; then
    echo -e "${BOLD}Configuring MCP servers...${NC}"
    echo ""
    install_mcp_servers
    echo ""
  else
    log_info "Skipping MCP configuration (SKIP_MCP=true)"
  fi

  echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}║${NC}                   ${BOLD}Installation Complete!${NC}                       ${GREEN}║${NC}"
  echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
  echo ""

  echo -e "${BOLD}Next steps:${NC}"
  echo ""

  local step=1
  if [[ "$GH_AUTHENTICATED" != "true" ]]; then
    echo "  ${step}. Authenticate GitHub CLI:"
    echo -e "     ${CYAN}gh auth login${NC}"
    echo ""
    step=$((step + 1))
  fi

  echo "  ${step}. Login to Codex (or set OPENAI_API_KEY):"
  echo -e "     ${CYAN}codex login${NC}"
  echo ""
  step=$((step + 1))

  echo "  ${step}. Export required GitHub Project variables (if using project board enforcement):"
  echo -e "     ${CYAN}export GITHUB_PROJECT=\"https://github.com/users/YOU/projects/N\"${NC}"
  echo -e "     ${CYAN}export GITHUB_PROJECT_NUM=N${NC}"
  echo -e "     ${CYAN}export GH_PROJECT_OWNER=\"@me\"${NC}"
  echo ""
  step=$((step + 1))

  echo "  ${step}. Run autonomous mode from any git repository:"
  echo -e "     ${CYAN}codex-autonomous${NC}"
  echo ""

  echo -e "Documentation: ${BLUE}${REPO_URL}${NC}"
  echo ""
}

main "$@"
