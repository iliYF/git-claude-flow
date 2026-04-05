#!/usr/bin/env bash
# =============================================================================
# install.sh — git-claude-flow installer / uninstaller
# =============================================================================
#
# Usage:
#   # Online install (recommended)
#   curl -sSL https://raw.githubusercontent.com/iliYF/git-claude-flow/main/install.sh | bash
#
#   # Specify install mode
#   curl -sSL https://raw.githubusercontent.com/iliYF/git-claude-flow/main/install.sh | bash -s -- --mode system
#   curl -sSL https://raw.githubusercontent.com/iliYF/git-claude-flow/main/install.sh | bash -s -- --mode user
#   curl -sSL https://raw.githubusercontent.com/iliYF/git-claude-flow/main/install.sh | bash -s -- --mode local
#
#   # Local execution
#   bash install.sh
#   bash install.sh --mode system
#
#   # Uninstall
#   bash install.sh --uninstall
#   bash install.sh --uninstall --mode system
#   bash install.sh --uninstall --mode all
#
# Install modes:
#   system  Download script to ~/.git-claude-flow/git-claude-flow, then symlink to
#           /usr/local/bin/git-<alias> (requires sudo)
#           Uses git external command mechanism (no git config needed)
#           Available to: all users on this machine
#
#   user    Download script to ~/.git-claude-flow/git-claude-flow (no sudo required)
#           Configured via: git config --global alias.<name> !bash ~/.git-claude-flow/...
#           Available to: current user in all repositories
#
#   local   Copy script to the current git repository's scripts/ directory
#           Configured via: git config alias.<name> (repo-level .git/config)
#           Available to: current repository only (great for team sharing via git)
#
# =============================================================================

set -euo pipefail

# Ensure running under bash (process substitution, [[ ]], etc. require bash)
if [ -z "${BASH_VERSION:-}" ]; then
    echo "Error: This script requires bash. Please run with: bash $0 $*" >&2
    exit 1
fi

# =============================================================================
# Configuration
# =============================================================================

SCRIPT_NAME="git-claude"
SCRIPT_SOURCE_NAME="git-claude-flow.sh"    # Source filename in repo (with .sh extension)
SCRIPT_INSTALL_NAME="git-claude-flow"       # Installed filename (without .sh extension)
GITHUB_REPO="iliYF/git-claude-flow"
GITHUB_BRANCH="main"
SCRIPT_URL="https://raw.githubusercontent.com/${GITHUB_REPO}/${GITHUB_BRANCH}/scripts/${SCRIPT_SOURCE_NAME}"
SYSTEM_INSTALL_DIR="/usr/local/bin"
USER_INSTALL_DIR="${HOME}/.git-claude-flow"
CONFIG_FILE="${USER_INSTALL_DIR}/config"   # Persistent config for system/user mode

# User configuration (set via interactive prompts or CLI flags)
GIT_ALIAS_NAME="claude"  # git alias name, default: claude
CLAUDE_CMD_NAME="claude" # Claude Code command name, default: claude

# Flags: whether explicitly set via CLI flags (to skip interactive prompts)
_ALIAS_SET=false
_CMD_SET=false
_UNINSTALL=false
_REINSTALL=false   # true = user chose to reinstall (skip existing-install check)

# =============================================================================
# Color output
# =============================================================================

if [ -t 1 ] && command -v tput &>/dev/null && tput colors &>/dev/null && [ "$(tput colors)" -ge 8 ]; then
    COLOR_RESET="\033[0m"
    COLOR_GREEN="\033[0;32m"
    COLOR_YELLOW="\033[0;33m"
    COLOR_RED="\033[0;31m"
    COLOR_CYAN="\033[0;36m"
    COLOR_BOLD="\033[1m"
else
    COLOR_RESET="" COLOR_GREEN="" COLOR_YELLOW="" COLOR_RED="" COLOR_CYAN="" COLOR_BOLD=""
fi

info_success() { echo -e "${COLOR_GREEN}✓ $*${COLOR_RESET}"; }
info_msg()     { echo -e "${COLOR_CYAN}→ $*${COLOR_RESET}"; }
info_warn()    { echo -e "${COLOR_YELLOW}⚠ $*${COLOR_RESET}"; }
die()          { echo -e "${COLOR_RED}✗ $*${COLOR_RESET}" >&2; exit 1; }

# =============================================================================
# Help
# =============================================================================

show_help() {
    local install_url="https://raw.githubusercontent.com/${GITHUB_REPO}/${GITHUB_BRANCH}/install.sh"
    echo -e "${COLOR_BOLD}install.sh${COLOR_RESET} — git-claude-flow installer / uninstaller"
    echo ""
    echo -e "${COLOR_BOLD}Usage:${COLOR_RESET}"
    echo "  bash install.sh [options]"
    echo ""
    echo -e "${COLOR_BOLD}Options:${COLOR_RESET}"
    echo -e "  ${COLOR_CYAN}--mode${COLOR_RESET} <mode>      Install mode: system | user | local (uninstall also supports: all)"
    echo -e "  ${COLOR_CYAN}--alias${COLOR_RESET} <name>     git alias name (default: claude)"
    echo -e "  ${COLOR_CYAN}--cmd${COLOR_RESET} <command>    Claude Code command name (default: claude)"
    echo -e "  ${COLOR_CYAN}--uninstall${COLOR_RESET}        Uninstall git-claude-flow"
    echo -e "  ${COLOR_CYAN}--help${COLOR_RESET}             Show this help message"
    echo ""
    echo -e "${COLOR_BOLD}Install modes (--mode):${COLOR_RESET}"
    echo -e "  ${COLOR_CYAN}system${COLOR_RESET}   Script to ${USER_INSTALL_DIR}/, symlink ${SYSTEM_INSTALL_DIR}/git-<alias> (all users, requires sudo, no git config needed)"
    echo -e "  ${COLOR_CYAN}user${COLOR_RESET}     Script to ${USER_INSTALL_DIR}/, git config --global alias (current user, no sudo)"
    echo -e "  ${COLOR_CYAN}local${COLOR_RESET}    Copy to current git repo's scripts/, git config alias (current repo only, team-friendly)"
    echo ""
    echo -e "${COLOR_BOLD}Online install examples:${COLOR_RESET}"
    echo "  curl -sSL ${install_url} | bash"
    echo "  curl -sSL ${install_url} | bash -s -- --mode system"
    echo "  curl -sSL ${install_url} | bash -s -- --mode user --alias cf --cmd claude-internal"
    echo "  curl -sSL ${install_url} | bash -s -- --mode local"
    echo ""
    echo -e "${COLOR_BOLD}Uninstall examples:${COLOR_RESET}"
    echo "  bash install.sh --uninstall"
    echo "  bash install.sh --uninstall --mode system"
    echo "  bash install.sh --uninstall --mode all"
}
# =============================================================================
# Argument parsing
# =============================================================================

INSTALL_MODE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --mode|-m)
            INSTALL_MODE="${2:-}"
            shift 2
            ;;
        --alias|-a)
            GIT_ALIAS_NAME="${2:-}"
            _ALIAS_SET=true
            shift 2
            ;;
        --cmd|-c)
            CLAUDE_CMD_NAME="${2:-}"
            _CMD_SET=true
            shift 2
            ;;
        --uninstall|-u)
            _UNINSTALL=true
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            die "Unknown option: $1\n  Use --help for usage information"
            ;;
    esac
done

# =============================================================================
# Get script content (download from URL for online install, or read from local directory)
# =============================================================================

get_script_content() {
    # Look for local file first: install.sh is in root, script is in scripts/ subdirectory
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-/dev/stdin}")" 2>/dev/null && pwd || echo "")"
    # Look for source file with .sh extension in scripts/ subdirectory
    local local_script="${script_dir}/scripts/${SCRIPT_SOURCE_NAME}"

    if [[ -f "$local_script" ]]; then
        # Local execution: use the script from the same repo's scripts/ directory
        echo "$local_script"
    else
        # Online install: download script from GitHub to a temp file
        local tmp_file
        tmp_file=$(mktemp /tmp/git-claude-XXXXXX)
        info_msg "Downloading script from GitHub: ${SCRIPT_URL}" >&2
        if command -v curl &>/dev/null; then
            curl -sSL "$SCRIPT_URL" -o "$tmp_file" || die "Download failed. Check your network or URL: ${SCRIPT_URL}"
        elif command -v wget &>/dev/null; then
            wget -qO "$tmp_file" "$SCRIPT_URL" || die "Download failed. Check your network or URL: ${SCRIPT_URL}"
        else
            die "Neither curl nor wget found. Cannot download script."
        fi
        echo "$tmp_file"
    fi
}

# =============================================================================
# Interactive configuration prompts
# =============================================================================

# Read input from terminal (compatible with pipe execution: when running via
# curl | bash, stdin is unavailable, so read from /dev/tty instead)
read_tty() {
    local __var="$1"
    local __val
    if [ -t 0 ]; then
        read -r __val
    else
        read -r __val < /dev/tty
    fi
    eval "$__var=\$__val"
}

# Prompt for git alias name
ask_alias_name() {
    echo ""
    echo -e "${COLOR_BOLD}Configure git alias name:${COLOR_RESET}"
    echo -e "  After installation, invoke via ${COLOR_CYAN}git <alias> <branch>${COLOR_RESET}"
    printf "Enter alias name (default: ${COLOR_BOLD}claude${COLOR_RESET}): "
    local input_alias
    read_tty input_alias
    if [[ -n "$input_alias" ]]; then
        GIT_ALIAS_NAME="$input_alias"
    fi
    info_success "git alias name: ${COLOR_BOLD}${GIT_ALIAS_NAME}${COLOR_RESET}"
}

# Validate that the Claude command exists in PATH
# Returns 0 if valid, 1 if not found
check_claude_cmd() {
    command -v "$CLAUDE_CMD_NAME" &>/dev/null
}

# Prompt user to re-enter or exit when command not found
# Used after command validation fails
prompt_retry_claude_cmd() {
    while true; do
        info_warn "Command '${CLAUDE_CMD_NAME}' not found in PATH."
        printf "  Re-enter command name or press Enter to exit: "
        local input_cmd
        read_tty input_cmd
        if [[ -z "$input_cmd" ]]; then
            die "Installation cancelled. Please install Claude Code first."
        fi
        CLAUDE_CMD_NAME="$input_cmd"
        if check_claude_cmd; then
            info_success "Claude Code command: ${COLOR_BOLD}${CLAUDE_CMD_NAME}${COLOR_RESET}"
            return 0
        fi
    done
}

# Prompt for Claude Code command name
ask_claude_cmd() {
    echo ""
    echo -e "${COLOR_BOLD}Configure Claude Code command name:${COLOR_RESET}"
    echo -e "  The executable invoked internally (e.g. claude, claude-internal, cc, etc.)"
    printf "Enter command name (default: ${COLOR_BOLD}claude${COLOR_RESET}): "
    local input_cmd
    read_tty input_cmd
    if [[ -n "$input_cmd" ]]; then
        CLAUDE_CMD_NAME="$input_cmd"
    fi
    info_success "Claude Code command: ${COLOR_BOLD}${CLAUDE_CMD_NAME}${COLOR_RESET}"
    if ! check_claude_cmd; then
        prompt_retry_claude_cmd
    fi
}

# =============================================================================
# Install mode selection (interactive)
# =============================================================================

select_mode() {
    echo ""
    echo -e "${COLOR_BOLD}Select install mode:${COLOR_RESET}"
    echo ""
    echo -e "  ${COLOR_CYAN}[1]${COLOR_RESET} ${COLOR_BOLD}system${COLOR_RESET}  — All users, requires sudo, installs to ${SYSTEM_INSTALL_DIR}/git-<alias>"
    echo -e "  ${COLOR_CYAN}[2]${COLOR_RESET} ${COLOR_BOLD}user${COLOR_RESET}    — Current user only, set git alias.<name> to ~/.gitconfig"
    echo -e "  ${COLOR_CYAN}[3]${COLOR_RESET} ${COLOR_BOLD}local${COLOR_RESET}   — Current repo only, set git alias.<name> to .git/config"
    echo ""
    echo -e "  ${COLOR_YELLOW}[0]${COLOR_RESET} Cancel"
    echo ""
    printf "Enter number [0-3] (default: 2): "
    local choice
    read_tty choice
    choice="${choice:-2}"
    case "$choice" in
        1) INSTALL_MODE="system" ;;
        2) INSTALL_MODE="user" ;;
        3) INSTALL_MODE="local" ;;
        0) info_msg "Installation cancelled."; exit 0 ;;
        *) die "Invalid option: ${choice}" ;;
    esac
}
# =============================================================================
# Uninstall
# =============================================================================

# Detect alias from config file or git config for uninstall
detect_uninstall_alias() {
    local detected_alias=""
    case "$INSTALL_MODE" in
        system|user)
            if [[ -f "$CONFIG_FILE" ]]; then
                detected_alias=$(_config_get "alias")
            fi
            ;;
        local)
            # Try to find alias pointing to git-claude-flow in repo .git/config
            if git rev-parse --is-inside-work-tree &>/dev/null; then
                detected_alias=$(git config --local --get-regexp '^alias\.' 2>/dev/null \
                    | grep 'git-claude-flow' | head -1 | sed 's/^alias\.\([^ ]*\).*/\1/' || true)
            fi
            ;;
    esac
    if [[ -n "$detected_alias" ]]; then
        GIT_ALIAS_NAME="$detected_alias"
        info_success "Detected alias: ${COLOR_BOLD}${GIT_ALIAS_NAME}${COLOR_RESET}"
    fi
}

# Select uninstall mode interactively
select_uninstall_mode() {
    echo ""
    echo -e "${COLOR_BOLD}Select uninstall mode:${COLOR_RESET}"
    echo ""
    echo -e "  ${COLOR_CYAN}[1]${COLOR_RESET} ${COLOR_BOLD}system${COLOR_RESET}  — All users, executable at ${SYSTEM_INSTALL_DIR}/git-<alias>"
    echo -e "  ${COLOR_CYAN}[2]${COLOR_RESET} ${COLOR_BOLD}user${COLOR_RESET}    — Current user only, git alias.<name> in ~/.gitconfig"
    echo -e "  ${COLOR_CYAN}[3]${COLOR_RESET} ${COLOR_BOLD}local${COLOR_RESET}   — Current repo only, git alias.<name> in .git/config"
    echo -e "  ${COLOR_CYAN}[4]${COLOR_RESET} ${COLOR_BOLD}all${COLOR_RESET}     — Remove all installations"
    echo ""
    echo -e "  ${COLOR_YELLOW}[0]${COLOR_RESET} Cancel"
    echo ""
    printf "Enter number [0-4] (default: 4): "
    local choice
    read_tty choice
    choice="${choice:-4}"
    case "$choice" in
        1) INSTALL_MODE="system" ;;
        2) INSTALL_MODE="user" ;;
        3) INSTALL_MODE="local" ;;
        4) INSTALL_MODE="all" ;;
        0) info_msg "Uninstall cancelled."; exit 0 ;;
        *) die "Invalid option: ${choice}" ;;
    esac
}

uninstall_system() {
    local script_dest="${USER_INSTALL_DIR}/${SCRIPT_INSTALL_NAME}"

    # Check if system mode was ever installed
    local has_symlink=false
    local symlinks_to_remove=("${SYSTEM_INSTALL_DIR}/git-claude")
    if [[ "$GIT_ALIAS_NAME" != "claude" ]]; then
        symlinks_to_remove+=("${SYSTEM_INSTALL_DIR}/git-${GIT_ALIAS_NAME}")
    fi
    for s in "${symlinks_to_remove[@]}"; do
        [[ -L "$s" || -f "$s" ]] && has_symlink=true
    done
    if ! $has_symlink && [[ ! -f "$script_dest" ]]; then
        info_warn "System mode not installed, skipping."
        return 0
    fi

    # Step 1: Remove symlink(s) from /usr/local/bin/
    for symlink_dest in "${symlinks_to_remove[@]}"; do
        if [[ -L "$symlink_dest" || -f "$symlink_dest" ]]; then
            info_msg "Removing: ${symlink_dest} (requires sudo)"
            if ! sudo rm -f "$symlink_dest"; then
                info_warn "Failed to remove: ${symlink_dest}. Please verify sudo permissions."
            else
                info_success "Removed: ${symlink_dest}"
            fi
        fi
    done

    # Step 2: Remove script and config from ~/.git-claude-flow/
    if [[ -f "$script_dest" ]]; then
        info_msg "Removing script: ${script_dest}"
        rm -f "$script_dest" || info_warn "Failed to remove ${script_dest}."
        info_success "Removed script: ${script_dest}"
    fi
    remove_config
    rmdir "${USER_INSTALL_DIR}" 2>/dev/null && info_success "Removed empty directory: ${USER_INSTALL_DIR}" || true
}

uninstall_user() {
    local dest="${USER_INSTALL_DIR}/${SCRIPT_INSTALL_NAME}"
    local has_alias=false
    git config --global "alias.${GIT_ALIAS_NAME}" &>/dev/null && has_alias=true

    # Check if user mode was ever installed
    if [[ ! -f "$dest" ]] && ! $has_alias; then
        info_warn "User mode not installed, skipping."
        return 0
    fi

    if [[ -f "$dest" ]]; then
        info_msg "Removing: ${dest}"
        rm -f "$dest" || info_warn "Failed to remove ${dest}."
        info_success "Removed: ${dest}"
    fi
    remove_config
    # Remove directory if empty
    rmdir "${USER_INSTALL_DIR}" 2>/dev/null && info_success "Removed empty directory: ${USER_INSTALL_DIR}" || true
    # Remove global git alias (--global)
    if $has_alias; then
        info_msg "Removing global git alias: ${GIT_ALIAS_NAME}"
        git config --global --unset "alias.${GIT_ALIAS_NAME}"
        info_success "Removed global git alias: git ${GIT_ALIAS_NAME}"
    fi
}

uninstall_local() {
    # Check if inside a git repository
    if ! git rev-parse --is-inside-work-tree &>/dev/null; then
        info_warn "Not in a git repository, skipping local uninstall."
        return 0
    fi

    local repo_root
    repo_root=$(git rev-parse --show-toplevel)
    local dest="${repo_root}/scripts/${SCRIPT_INSTALL_NAME}"
    local has_alias=false
    git config --local "alias.${GIT_ALIAS_NAME}" &>/dev/null && has_alias=true

    # Check if local mode was ever installed
    if [[ ! -f "$dest" ]] && ! $has_alias; then
        info_warn "Local mode not installed in this repo, skipping."
        return 0
    fi

    if [[ -f "$dest" ]]; then
        info_msg "Removing: ${dest}"
        rm -f "$dest" || info_warn "Failed to remove ${dest}."
        info_success "Removed: ${dest}"
    fi

    # Remove repository-level git alias
    if $has_alias; then
        info_msg "Removing repository-level git alias: ${GIT_ALIAS_NAME}"
        git config --unset "alias.${GIT_ALIAS_NAME}"
        info_success "Removed git alias: git ${GIT_ALIAS_NAME}"
    fi
}

# =============================================================================
# Config file management (persistent config for system/user mode)
# =============================================================================

# Config file format (INI-like, one key=value per line):
#   mode=user
#   alias=claude
#   cmd=claude
#   version=1.0.0
#   md5=abc123...
#   installed_at=2025-01-01T12:00:00

# Read a value from config file by key
_config_get() {
    local key="$1"
    if [[ -f "$CONFIG_FILE" ]]; then
        grep -m1 "^${key}=" "$CONFIG_FILE" 2>/dev/null | sed "s/^${key}=//" || true
    fi
}

# Save config file after installation (system/user mode only)
save_config() {
    # Only persist config for system/user mode; local mode is repo-specific
    if [[ "$INSTALL_MODE" == "local" ]]; then
        return 0
    fi

    local script_path="${USER_INSTALL_DIR}/${SCRIPT_INSTALL_NAME}"
    local script_version=""
    local script_md5=""

    # Extract version from installed script
    if [[ -f "$script_path" ]]; then
        script_version=$(grep -m1 '^VERSION=' "$script_path" 2>/dev/null | sed 's/^VERSION="\(.*\)"/\1/' || true)
        # Calculate MD5 (compatible with macOS and Linux)
        if command -v md5sum &>/dev/null; then
            script_md5=$(md5sum "$script_path" | awk '{print $1}')
        elif command -v md5 &>/dev/null; then
            script_md5=$(md5 -q "$script_path")
        fi
    fi

    mkdir -p "$USER_INSTALL_DIR"
    cat > "$CONFIG_FILE" <<EOF
mode=${INSTALL_MODE}
alias=${GIT_ALIAS_NAME}
cmd=${CLAUDE_CMD_NAME}
version=${script_version}
md5=${script_md5}
installed_at=$(date -u '+%Y-%m-%dT%H:%M:%S')
EOF
    info_success "Config saved: ${CONFIG_FILE}"
}

# Remove config file (called during uninstall)
remove_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        rm -f "$CONFIG_FILE"
        info_success "Removed config: ${CONFIG_FILE}"
    fi
}

# =============================================================================
# Detect existing installation (called before interactive prompts)
# =============================================================================

# Clean up old mode artifacts when switching install modes
# Usage: _cleanup_old_mode <old_mode> <old_alias>
_cleanup_old_mode() {
    local old_mode="$1"
    local old_alias="${2:-$GIT_ALIAS_NAME}"
    case "$old_mode" in
        system)
            # Remove symlinks from /usr/local/bin/
            local symlinks=("${SYSTEM_INSTALL_DIR}/git-claude")
            if [[ "$old_alias" != "claude" ]]; then
                symlinks+=("${SYSTEM_INSTALL_DIR}/git-${old_alias}")
            fi
            for s in "${symlinks[@]}"; do
                if [[ -L "$s" || -f "$s" ]]; then
                    info_msg "Removing old symlink: ${s} (requires sudo)"
                    sudo rm -f "$s" 2>/dev/null && info_success "Removed: ${s}" || info_warn "Failed to remove: ${s}"
                fi
            done
            ;;
        user)
            # Remove global git alias
            if git config --global "alias.${old_alias}" &>/dev/null; then
                info_msg "Removing old global git alias: ${old_alias}"
                git config --global --unset "alias.${old_alias}"
                info_success "Removed global git alias: git ${old_alias}"
            fi
            ;;
        local)
            # Remove local script and alias
            if git rev-parse --is-inside-work-tree &>/dev/null; then
                local repo_root
                repo_root=$(git rev-parse --show-toplevel)
                local old_dest="${repo_root}/scripts/${SCRIPT_INSTALL_NAME}"
                if [[ -f "$old_dest" ]]; then
                    rm -f "$old_dest"
                    info_success "Removed old local script: ${old_dest}"
                fi
                if git config --local "alias.${old_alias}" &>/dev/null; then
                    git config --local --unset "alias.${old_alias}"
                    info_success "Removed old local git alias: git ${old_alias}"
                fi
            fi
            ;;
    esac
}

# Check if already installed; if so, prompt user to reuse / reinstall / exit
check_existing_installation() {
    local installed_script=""
    local existing_mode="" existing_alias="" existing_cmd=""
    local existing_version="" existing_md5=""

    case "$INSTALL_MODE" in
        system|user)
            installed_script="${USER_INSTALL_DIR}/${SCRIPT_INSTALL_NAME}"
            # Read from config file if available
            if [[ -f "$CONFIG_FILE" ]]; then
                existing_mode=$(_config_get "mode")
                existing_alias=$(_config_get "alias")
                existing_cmd=$(_config_get "cmd")
                existing_version=$(_config_get "version")
                existing_md5=$(_config_get "md5")
            fi
            ;;
        local)
            local repo_root
            repo_root=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
            if [[ -n "$repo_root" ]]; then
                installed_script="${repo_root}/scripts/${SCRIPT_INSTALL_NAME}"
            fi
            # local mode: detect alias from git config (no persistent config)
            if [[ -n "$installed_script" ]] && [[ -f "$installed_script" ]]; then
                local _alias_output
                _alias_output=$(git config --get-regexp '^alias\.' 2>/dev/null || true)
                if [[ -n "$_alias_output" ]]; then
                    local key value
                    while read -r key value; do
                        if [[ "$value" == *"git-claude-flow"* ]]; then
                            existing_alias="${key#alias.}"
                            break
                        fi
                    done <<< "$_alias_output"
                fi
                existing_cmd=$(grep -m1 '^CLAUDE_CMD=' "$installed_script" 2>/dev/null | sed 's/^CLAUDE_CMD="\(.*\)"/\1/' || true)
                existing_version=$(grep -m1 '^VERSION=' "$installed_script" 2>/dev/null | sed 's/^VERSION="\(.*\)"/\1/' || true)
            fi
            ;;
    esac

    # No installed script found — fresh install
    if [[ -z "$installed_script" ]] || [[ ! -f "$installed_script" ]]; then
        return 0
    fi

    # Apply defaults
    existing_alias="${existing_alias:-claude}"
    existing_cmd="${existing_cmd:-claude}"
    existing_version="${existing_version:-unknown}"
    existing_mode="${existing_mode:-$INSTALL_MODE}"

    echo -e "${COLOR_YELLOW}════════════════════════════════════════════${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}  git-claude-flow is already installed (${existing_mode} mode)${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}════════════════════════════════════════════${COLOR_RESET}"
    echo ""
    echo -e "  Script:  ${COLOR_BOLD}${installed_script}${COLOR_RESET}"
    echo -e "  Alias:   ${COLOR_BOLD}git ${existing_alias}${COLOR_RESET}"
    echo -e "  Command: ${COLOR_BOLD}${existing_cmd}${COLOR_RESET}"
    echo -e "  Version: ${COLOR_BOLD}${existing_version}${COLOR_RESET}"
    if [[ -n "$existing_md5" ]]; then
        echo -e "  MD5:     ${COLOR_BOLD}${existing_md5}${COLOR_RESET}"
    fi
    if [[ "$existing_mode" != "$INSTALL_MODE" ]]; then
        echo ""
        echo -e "  ${COLOR_YELLOW}⚠ Mode change: ${existing_mode} → ${INSTALL_MODE}${COLOR_RESET}"
    fi
    echo ""
    echo -e "  ${COLOR_CYAN}[1]${COLOR_RESET} ${COLOR_BOLD}Reuse${COLOR_RESET}      — Keep current config, update script only"
    echo -e "  ${COLOR_CYAN}[2]${COLOR_RESET} ${COLOR_BOLD}Reinstall${COLOR_RESET}  — Reconfigure alias, command, and reinstall"
    echo -e "  ${COLOR_YELLOW}[0]${COLOR_RESET} Exit"
    echo ""
    printf "Enter number [0-2] (default: 1): "
    local choice
    read_tty choice
    choice="${choice:-1}"
    case "$choice" in
        1)
            # Reuse existing config: set alias & cmd, skip interactive prompts
            GIT_ALIAS_NAME="$existing_alias"
            CLAUDE_CMD_NAME="$existing_cmd"
            _ALIAS_SET=true
            _CMD_SET=true
            # If mode changed, clean up old mode first
            if [[ "$existing_mode" != "$INSTALL_MODE" ]]; then
                info_msg "Cleaning up previous ${existing_mode} mode installation..."
                _cleanup_old_mode "$existing_mode" "$existing_alias"
            fi
            info_success "Reusing existing config: git ${GIT_ALIAS_NAME}, cmd=${CLAUDE_CMD_NAME}"
            ;;
        2)
            # Reinstall: always clean up old installation first
            _REINSTALL=true
            info_msg "Cleaning up previous ${existing_mode} mode installation..."
            _cleanup_old_mode "$existing_mode" "$existing_alias"
            info_msg "Proceeding with fresh configuration..."
            ;;
        0)
            info_msg "Installation cancelled."
            exit 0
            ;;
        *)
            die "Invalid option: ${choice}"
            ;;
    esac
}

# =============================================================================
# Alias conflict detection (called before downloading script)
# =============================================================================

check_alias_conflict() {
    case "$INSTALL_MODE" in
        system) check_alias_conflict_system ;;
        user)   check_alias_conflict_user   ;;
        local)  check_alias_conflict_local  ;;
    esac
}

# Check for conflicts in /usr/local/bin/ (system mode)
check_alias_conflict_system() {
    while true; do
        local symlinks_to_create=("${SYSTEM_INSTALL_DIR}/git-claude")
        if [[ "$GIT_ALIAS_NAME" != "claude" ]]; then
            symlinks_to_create+=("${SYSTEM_INSTALL_DIR}/git-${GIT_ALIAS_NAME}")
        fi
        local conflict_found=false
        for check_dest in "${symlinks_to_create[@]}"; do
            if [[ -e "$check_dest" ]]; then
                if [[ -L "$check_dest" ]]; then
                    local link_target
                    link_target=$(readlink "$check_dest")
                    if [[ "$link_target" == *"${USER_INSTALL_DIR}"* || "$link_target" == *"git-claude-flow"* ]]; then
                        info_warn "${check_dest} already points to our script (will overwrite): ${link_target}"
                    else
                        info_warn "Conflict: ${check_dest} already exists and points to a different target: ${link_target}"
                        conflict_found=true
                    fi
                else
                    info_warn "Conflict: ${check_dest} already exists as a regular file (not our symlink)."
                    conflict_found=true
                fi
            fi
        done
        if ! $conflict_found; then
            break
        fi
        echo ""
        printf "${COLOR_YELLOW}Alias '${GIT_ALIAS_NAME}' conflicts. Please enter a different alias name: ${COLOR_RESET}"
        local new_alias
        read_tty new_alias
        while [[ -z "$new_alias" ]]; do
            printf "${COLOR_YELLOW}Alias name cannot be empty. Please enter a different alias name: ${COLOR_RESET}"
            read_tty new_alias
        done
        GIT_ALIAS_NAME="$new_alias"
        info_success "Using new alias name: ${COLOR_BOLD}${GIT_ALIAS_NAME}${COLOR_RESET}"
    done
}

# Check for global git alias conflict (user mode)
check_alias_conflict_user() {
    while true; do
        local existing_alias
        existing_alias=$(git config --global "alias.${GIT_ALIAS_NAME}" 2>/dev/null || true)
        if [[ -z "$existing_alias" ]]; then
            break
        fi
        if [[ "$existing_alias" == *"${USER_INSTALL_DIR}"* || "$existing_alias" == *"git-claude-flow"* ]]; then
            info_warn "Global git alias '${GIT_ALIAS_NAME}' already set to our script (will overwrite): ${existing_alias}"
            break
        fi
        info_warn "Conflict: global git alias '${GIT_ALIAS_NAME}' already exists with a different value:"
        echo -e "  ${existing_alias}"
        echo ""
        printf "${COLOR_YELLOW}Alias '${GIT_ALIAS_NAME}' conflicts. Please enter a different alias name: ${COLOR_RESET}"
        local new_alias
        read_tty new_alias
        while [[ -z "$new_alias" ]]; do
            printf "${COLOR_YELLOW}Alias name cannot be empty. Please enter a different alias name: ${COLOR_RESET}"
            read_tty new_alias
        done
        GIT_ALIAS_NAME="$new_alias"
        info_success "Using new alias name: ${COLOR_BOLD}${GIT_ALIAS_NAME}${COLOR_RESET}"
    done
}

# Check for repository-level git alias conflict (local mode)
check_alias_conflict_local() {
    # Check if inside a git repository first
    if ! git rev-parse --is-inside-work-tree &>/dev/null; then
        die "Not a git repository. local mode must be run from a git repository root."
    fi

    while true; do
        local existing_alias
        existing_alias=$(git config "alias.${GIT_ALIAS_NAME}" 2>/dev/null || true)
        if [[ -z "$existing_alias" ]]; then
            break
        fi
        if [[ "$existing_alias" == *"${SCRIPT_INSTALL_NAME}"* || "$existing_alias" == *"git-claude-flow"* ]]; then
            info_warn "Repository git alias '${GIT_ALIAS_NAME}' already set to our script (will overwrite): ${existing_alias}"
            break
        fi
        info_warn "Conflict: repository git alias '${GIT_ALIAS_NAME}' already exists with a different value:"
        echo -e "  ${existing_alias}"
        echo ""
        printf "${COLOR_YELLOW}Alias '${GIT_ALIAS_NAME}' conflicts. Please enter a different alias name: ${COLOR_RESET}"
        local new_alias
        read_tty new_alias
        while [[ -z "$new_alias" ]]; do
            printf "${COLOR_YELLOW}Alias name cannot be empty. Please enter a different alias name: ${COLOR_RESET}"
            read_tty new_alias
        done
        GIT_ALIAS_NAME="$new_alias"
        info_success "Using new alias name: ${COLOR_BOLD}${GIT_ALIAS_NAME}${COLOR_RESET}"
    done
}

# =============================================================================
# Install: system mode
# =============================================================================

install_system() {
    local src="$1"
    local script_dest="${USER_INSTALL_DIR}/${SCRIPT_INSTALL_NAME}"

    # Step 1: Install script to ~/.git-claude-flow/ (shared storage)
    mkdir -p "$USER_INSTALL_DIR"
    local tmp_patched
    tmp_patched=$(mktemp /tmp/git-claude-patched-XXXXXX)
    sed "s|^CLAUDE_CMD=.*|CLAUDE_CMD=\"${CLAUDE_CMD_NAME}\"|" "$src" > "$tmp_patched"
    install -m 755 "$tmp_patched" "$script_dest" || die "Installation failed."
    rm -f "$tmp_patched"
    info_success "Script installed: ${script_dest}"

    # Step 3: Create symlink(s) in /usr/local/bin/ (requires sudo)
    # Git external command mechanism: a file named 'git-<name>' in PATH is
    # automatically invoked as 'git <name>' — no git config alias needed.
    # Always create git-claude (default); also create git-<alias> for custom names.
    local symlink_default="${SYSTEM_INSTALL_DIR}/git-claude"
    info_msg "Creating symlink: ${symlink_default} -> ${script_dest} (requires sudo)"
    sudo ln -sf "$script_dest" "$symlink_default" || die "Failed to create symlink. Please verify sudo permissions."
    info_success "Symlink created: ${symlink_default}"

    if [[ "$GIT_ALIAS_NAME" != "claude" ]]; then
        local symlink_alias="${SYSTEM_INSTALL_DIR}/git-${GIT_ALIAS_NAME}"
        info_msg "Creating symlink for custom alias: ${symlink_alias} -> ${script_dest} (requires sudo)"
        sudo ln -sf "$script_dest" "$symlink_alias" || die "Failed to create symlink. Please verify sudo permissions."
        info_success "Symlink created: ${symlink_alias}"
    fi
    echo ""
    echo -e "  You can now use in any git repository: ${COLOR_BOLD}git ${GIT_ALIAS_NAME} <branch>${COLOR_RESET}"
    echo -e "  (Available to all users on this machine, no git config required)"

    # Save config for future reuse
    save_config
}
# =============================================================================
# Install: user mode
# =============================================================================

install_user() {
    local src="$1"
    local dest="${USER_INSTALL_DIR}/${SCRIPT_INSTALL_NAME}"

    mkdir -p "$USER_INSTALL_DIR"
    # Patch CLAUDE_CMD into the script
    local tmp_patched
    tmp_patched=$(mktemp /tmp/git-claude-patched-XXXXXX)
    sed "s|^CLAUDE_CMD=.*|CLAUDE_CMD=\"${CLAUDE_CMD_NAME}\"|" "$src" > "$tmp_patched"
    install -m 755 "$tmp_patched" "$dest" || die "Installation failed."
    rm -f "$tmp_patched"
    info_success "Installed: ${dest}"

    # Configure global git alias (--global), available to current user in all repositories
    # No PATH modification needed — alias points directly to the script file
    info_msg "Configuring global git alias: ${GIT_ALIAS_NAME} -> ${dest}"
    git config --global "alias.${GIT_ALIAS_NAME}" "!bash \"${dest}\""
    info_success "Global git alias configured: git ${GIT_ALIAS_NAME}"

    echo ""
    echo -e "  You can now use in any git repository: ${COLOR_BOLD}git ${GIT_ALIAS_NAME} <branch>${COLOR_RESET}"
    echo -e "  (Available to current user only, no PATH change required)"

    # Save config for future reuse
    save_config
}
# =============================================================================
# Install: local mode
# =============================================================================

install_local() {
    local src="$1"

    local repo_root
    repo_root=$(git rev-parse --show-toplevel)
    local scripts_dir="${repo_root}/scripts"
    local dest="${scripts_dir}/${SCRIPT_INSTALL_NAME}"

    mkdir -p "$scripts_dir"
    # Patch CLAUDE_CMD and install: source is .sh, dest is without .sh (no conflict)
    sed "s|^CLAUDE_CMD=.*|CLAUDE_CMD=\"${CLAUDE_CMD_NAME}\"|" "$src" > "$dest"
    chmod 755 "$dest" || die "Failed to copy script."
    info_success "Script installed to: ${dest}"

    # Configure repository-level git alias
    info_msg "Configuring repository-level git alias: ${GIT_ALIAS_NAME}..."
    git config "alias.${GIT_ALIAS_NAME}" "!bash \"\$(git rev-parse --show-toplevel)/scripts/${SCRIPT_INSTALL_NAME}\""
    info_success "git alias configured: git ${GIT_ALIAS_NAME}"

    echo ""
    echo -e "  Verify config: ${COLOR_BOLD}git config alias.${GIT_ALIAS_NAME}${COLOR_RESET}"
    echo -e "  You can now use in this repository: ${COLOR_BOLD}git ${GIT_ALIAS_NAME} <branch>${COLOR_RESET}"
    echo ""
    info_warn "Note: this alias only applies to the current repository (${repo_root})."
}
# =============================================================================
# Main
# =============================================================================

echo ""

if $_UNINSTALL; then
    # -------------------------------------------------------------------------
    # Uninstall flow
    # -------------------------------------------------------------------------
    echo -e "${COLOR_BOLD}${COLOR_RED}============================================${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_RED}  git-claude-flow Uninstaller${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_RED}============================================${COLOR_RESET}"
    echo ""

    # Step 1: Select uninstall mode
    if [[ -z "$INSTALL_MODE" ]]; then
        select_uninstall_mode
    fi

    # Validate mode
    case "$INSTALL_MODE" in
        system|user|local|all) ;;
        *) die "Invalid uninstall mode: ${INSTALL_MODE}\n  Valid values: system | user | local | all" ;;
    esac

    # Step 2: Auto-detect alias from config; use --alias flag if provided
    if [[ "$INSTALL_MODE" != "all" ]]; then
        if ! $_ALIAS_SET; then
            detect_uninstall_alias
        fi
        info_msg "Uninstall mode: ${COLOR_BOLD}${INSTALL_MODE}${COLOR_RESET}, alias: ${COLOR_BOLD}${GIT_ALIAS_NAME}${COLOR_RESET}"
    else
        info_msg "Uninstall mode: ${COLOR_BOLD}all${COLOR_RESET}"
    fi
    echo ""

    # Run uninstaller
    case "$INSTALL_MODE" in
        system) uninstall_system ;;
        user)   uninstall_user   ;;
        local)  uninstall_local  ;;
        all)
            # Detect alias from config for system/user cleanup
            if ! $_ALIAS_SET && [[ -f "$CONFIG_FILE" ]]; then
                cfg_alias=$(_config_get "alias")
                [[ -n "$cfg_alias" ]] && GIT_ALIAS_NAME="$cfg_alias"
            fi
            info_msg "Removing system installation..."
            uninstall_system
            echo ""
            info_msg "Removing user installation..."
            uninstall_user
            echo ""
            # Detect local alias if in a git repo
            if git rev-parse --is-inside-work-tree &>/dev/null; then
                local_alias=$(git config --local --get-regexp '^alias\.' 2>/dev/null                    | grep 'git-claude-flow' | head -1 | sed 's/^alias\.\([^ ]*\).*/\1/' || true)
                [[ -n "$local_alias" ]] && GIT_ALIAS_NAME="$local_alias"
            fi
            info_msg "Removing local installation..."
            uninstall_local
            ;;
    esac

    echo ""
    echo -e "${COLOR_BOLD}${COLOR_GREEN}============================================${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_GREEN}  ✓ Uninstall complete!${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_GREEN}============================================${COLOR_RESET}"
    echo ""
else
    # -------------------------------------------------------------------------
    # Install flow
    # -------------------------------------------------------------------------
    echo -e "${COLOR_BOLD}${COLOR_GREEN}============================================${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_GREEN}  git-claude-flow Installer${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_GREEN}============================================${COLOR_RESET}"
    echo ""

    # Step 1: Select install mode (interactive if not specified via flag)
    if [[ -z "$INSTALL_MODE" ]]; then
        select_mode
    fi

    # Validate mode
    case "$INSTALL_MODE" in
        system|user|local) ;;
        *) die "Invalid install mode: ${INSTALL_MODE}\n  Valid values: system | user | local" ;;
    esac

    # Step 2: Check for existing installation (may set _ALIAS_SET/_CMD_SET if reusing)
    check_existing_installation

    # Step 3: Prompt for git alias name (if not set via --alias flag and not reusing)
    if ! $_ALIAS_SET; then
        ask_alias_name
    fi

    # Step 4: Prompt for Claude Code command name (if not set via --cmd flag and not reusing)
    if ! $_CMD_SET; then
        ask_claude_cmd
    fi

    # Step 4.5: Validate Claude command exists (for --cmd flag or reused config)
    if $_CMD_SET && ! check_claude_cmd; then
        prompt_retry_claude_cmd
    fi

    info_msg "Install mode: ${COLOR_BOLD}${INSTALL_MODE}${COLOR_RESET}"
    echo ""

    # Step 5: Check alias conflict (before downloading to avoid unnecessary network requests)
    check_alias_conflict

    # Step 6: Get script file path (download or read local)
    SCRIPT_FILE=$(get_script_content)

    # Run installer
    case "$INSTALL_MODE" in
        system) install_system "$SCRIPT_FILE" ;;
        user)   install_user   "$SCRIPT_FILE" ;;
        local)  install_local  "$SCRIPT_FILE" ;;
    esac

    echo ""
    echo -e "${COLOR_BOLD}${COLOR_GREEN}============================================${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_GREEN}  ✓ Installation complete!${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_GREEN}============================================${COLOR_RESET}"
    echo ""
    echo -e "  Run ${COLOR_BOLD}git ${GIT_ALIAS_NAME} -h${COLOR_RESET} to see usage"
    echo -e "  Run ${COLOR_BOLD}git ${GIT_ALIAS_NAME} --version${COLOR_RESET} to check version"
    echo ""
fi
