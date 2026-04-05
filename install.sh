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
#   bash install.sh --uninstall --alias cf
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

# =============================================================================
# Configuration
# =============================================================================

SCRIPT_NAME="git-claude"
SCRIPT_SOURCE_NAME="git-claude-flow"
GITHUB_REPO="iliYF/git-claude-flow"
GITHUB_BRANCH="main"
SCRIPT_URL="https://raw.githubusercontent.com/${GITHUB_REPO}/${GITHUB_BRANCH}/scripts/${SCRIPT_SOURCE_NAME}"
SYSTEM_INSTALL_DIR="/usr/local/bin"
USER_INSTALL_DIR="${HOME}/.git-claude-flow"

# User configuration (set via interactive prompts or CLI flags)
GIT_ALIAS_NAME="claude"  # git alias name, default: claude
CLAUDE_CMD_NAME="claude" # Claude Code command name, default: claude

# Flags: whether explicitly set via CLI flags (to skip interactive prompts)
_ALIAS_SET=false
_CMD_SET=false
_UNINSTALL=false

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
    echo -e "  ${COLOR_CYAN}--mode${COLOR_RESET} <mode>      Install mode: system | user | local"
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
    echo "  bash install.sh --uninstall --alias cf"
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
    local local_script="${script_dir}/scripts/${SCRIPT_SOURCE_NAME}"

    if [[ -f "$local_script" ]]; then
        # Local execution: use the script from the same repo's scripts/ directory
        echo "$local_script"
    else
        # Online install: download script from GitHub to a temp file
        local tmp_file
        tmp_file=$(mktemp /tmp/git-claude-XXXXXX)
        info_msg "Downloading script from GitHub: ${SCRIPT_URL}"
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
}

# =============================================================================
# Install mode selection (interactive)
# =============================================================================

select_mode() {
    echo ""
    echo -e "${COLOR_BOLD}Select install mode:${COLOR_RESET}"
    echo ""
    echo -e "  ${COLOR_CYAN}[1]${COLOR_RESET} ${COLOR_BOLD}system${COLOR_RESET}  — Script to ${USER_INSTALL_DIR}/, symlink ${SYSTEM_INSTALL_DIR}/git-<alias> (all users, requires sudo, no git config needed)"
    echo -e "  ${COLOR_CYAN}[2]${COLOR_RESET} ${COLOR_BOLD}user${COLOR_RESET}    — Script to ${USER_INSTALL_DIR}/, --global alias (current user, no sudo)"
    echo -e "  ${COLOR_CYAN}[3]${COLOR_RESET} ${COLOR_BOLD}local${COLOR_RESET}   — Copy to <repo>/scripts/, repo-level alias (current repo only, team-friendly)"
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

# Select uninstall mode interactively
select_uninstall_mode() {
    echo ""
    echo -e "${COLOR_BOLD}Select uninstall mode:${COLOR_RESET}"
    echo ""
    echo -e "  ${COLOR_CYAN}[1]${COLOR_RESET} ${COLOR_BOLD}system${COLOR_RESET}  — Remove symlink(s) ${SYSTEM_INSTALL_DIR}/git-<alias> + script ${USER_INSTALL_DIR}/"
    echo -e "  ${COLOR_CYAN}[2]${COLOR_RESET} ${COLOR_BOLD}user${COLOR_RESET}    — Remove script ${USER_INSTALL_DIR}/ + global alias"
    echo -e "  ${COLOR_CYAN}[3]${COLOR_RESET} ${COLOR_BOLD}local${COLOR_RESET}   — Remove <repo>/scripts/git-claude-flow + repo alias"
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
        0) info_msg "Uninstall cancelled."; exit 0 ;;
        *) die "Invalid option: ${choice}" ;;
    esac
}

# Prompt for alias name during uninstall
ask_alias_name_for_uninstall() {
    echo ""
    echo -e "${COLOR_BOLD}Which git alias should be removed?${COLOR_RESET}"
    printf "Enter alias name (default: ${COLOR_BOLD}claude${COLOR_RESET}): "
    local input_alias
    read_tty input_alias
    if [[ -n "$input_alias" ]]; then
        GIT_ALIAS_NAME="$input_alias"
    fi
    info_success "Will remove alias: ${COLOR_BOLD}${GIT_ALIAS_NAME}${COLOR_RESET}"
}

uninstall_system() {
    local script_dest="${USER_INSTALL_DIR}/${SCRIPT_SOURCE_NAME}"

    # Step 1: Remove symlink(s) from /usr/local/bin/
    # Always remove git-claude (default symlink)
    # Also remove git-<alias> if alias differs from 'claude'
    local symlinks_to_remove=("${SYSTEM_INSTALL_DIR}/git-claude")
    if [[ "$GIT_ALIAS_NAME" != "claude" ]]; then
        symlinks_to_remove+=("${SYSTEM_INSTALL_DIR}/git-${GIT_ALIAS_NAME}")
    fi
    for symlink_dest in "${symlinks_to_remove[@]}"; do
        if [[ -L "$symlink_dest" ]]; then
            info_msg "Removing symlink: ${symlink_dest} (requires sudo)"
            sudo rm -f "$symlink_dest" || die "Failed to remove symlink. Please verify sudo permissions."
            info_success "Removed symlink: ${symlink_dest}"
        elif [[ -f "$symlink_dest" ]]; then
            info_msg "Removing file: ${symlink_dest} (requires sudo)"
            sudo rm -f "$symlink_dest" || die "Failed to remove ${symlink_dest}. Please verify sudo permissions."
            info_success "Removed: ${symlink_dest}"
        else
            info_warn "Not found: ${symlink_dest} (already removed or never installed)"
        fi
    done

    # Step 2: Remove script from ~/.git-claude-flow/
    if [[ -f "$script_dest" ]]; then
        info_msg "Removing script: ${script_dest}"
        rm -f "$script_dest" || die "Failed to remove ${script_dest}."
        info_success "Removed script: ${script_dest}"
        rmdir "${USER_INSTALL_DIR}" 2>/dev/null && info_success "Removed empty directory: ${USER_INSTALL_DIR}" || true
    else
        info_warn "Not found: ${script_dest} (already removed or never installed)"
    fi
}

uninstall_user() {
    local dest="${USER_INSTALL_DIR}/${SCRIPT_SOURCE_NAME}"
    if [[ -f "$dest" ]]; then
        info_msg "Removing: ${dest}"
        rm -f "$dest" || die "Failed to remove ${dest}."
        info_success "Removed: ${dest}"
        # Remove directory if empty
        rmdir "${USER_INSTALL_DIR}" 2>/dev/null && info_success "Removed empty directory: ${USER_INSTALL_DIR}" || true
    else
        info_warn "Not found: ${dest} (already removed or never installed)"
    fi
    # Remove global git alias (--global)
    if git config --global "alias.${GIT_ALIAS_NAME}" &>/dev/null; then
        info_msg "Removing global git alias: ${GIT_ALIAS_NAME}"
        git config --global --unset "alias.${GIT_ALIAS_NAME}"
        info_success "Removed global git alias: git ${GIT_ALIAS_NAME}"
    else
        info_warn "Global git alias '${GIT_ALIAS_NAME}' not found (already removed or never configured)"
    fi
}

uninstall_local() {
    # Check if inside a git repository
    if ! git rev-parse --is-inside-work-tree &>/dev/null; then
        die "Not a git repository. local mode must be run from a git repository root."
    fi

    local repo_root
    repo_root=$(git rev-parse --show-toplevel)
    local dest="${repo_root}/scripts/${SCRIPT_SOURCE_NAME}"

    if [[ -f "$dest" ]]; then
        info_msg "Removing: ${dest}"
        rm -f "$dest" || die "Failed to remove ${dest}."
        info_success "Removed: ${dest}"
    else
        info_warn "Not found: ${dest} (already removed or never installed)"
    fi

    # Remove repository-level git alias
    if git config "alias.${GIT_ALIAS_NAME}" &>/dev/null; then
        info_msg "Removing repository-level git alias: ${GIT_ALIAS_NAME}"
        git config --unset "alias.${GIT_ALIAS_NAME}"
        info_success "Removed git alias: git ${GIT_ALIAS_NAME}"
    else
        info_warn "Repository git alias '${GIT_ALIAS_NAME}' not found (already removed or never configured)"
    fi
}

# =============================================================================
# Install: system mode
# =============================================================================

install_system() {
    local src="$1"
    local script_dest="${USER_INSTALL_DIR}/${SCRIPT_SOURCE_NAME}"

    # Step 1: Check for conflicts in /usr/local/bin/
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
        printf "${COLOR_YELLOW}Please enter a different alias name (or press Enter to abort): ${COLOR_RESET}"
        local new_alias
        read_tty new_alias
        if [[ -z "$new_alias" ]]; then
            die "Installation aborted due to alias conflict."
        fi
        GIT_ALIAS_NAME="$new_alias"
        info_success "Using new alias name: ${COLOR_BOLD}${GIT_ALIAS_NAME}${COLOR_RESET}"
    done

    # Step 2: Install script to ~/.git-claude-flow/ (shared storage)
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
}
# =============================================================================
# Install: user mode
# =============================================================================

install_user() {
    local src="$1"
    local dest="${USER_INSTALL_DIR}/${SCRIPT_SOURCE_NAME}"

    # Check for global git alias conflict
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
        printf "${COLOR_YELLOW}Please enter a different alias name (or press Enter to abort): ${COLOR_RESET}"
        local new_alias
        read_tty new_alias
        if [[ -z "$new_alias" ]]; then
            die "Installation aborted due to alias conflict."
        fi
        GIT_ALIAS_NAME="$new_alias"
        info_success "Using new alias name: ${COLOR_BOLD}${GIT_ALIAS_NAME}${COLOR_RESET}"
    done

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
}
# =============================================================================
# Install: local mode
# =============================================================================

install_local() {
    local src="$1"

    # Check if inside a git repository
    if ! git rev-parse --is-inside-work-tree &>/dev/null; then
        die "Not a git repository. local mode must be run from a git repository root."
    fi

    local repo_root
    repo_root=$(git rev-parse --show-toplevel)
    local scripts_dir="${repo_root}/scripts"
    local dest="${scripts_dir}/${SCRIPT_SOURCE_NAME}"

    # Check for repository-level git alias conflict
    while true; do
        local existing_alias
        existing_alias=$(git config "alias.${GIT_ALIAS_NAME}" 2>/dev/null || true)
        if [[ -z "$existing_alias" ]]; then
            break
        fi
        if [[ "$existing_alias" == *"${SCRIPT_SOURCE_NAME}"* || "$existing_alias" == *"git-claude-flow"* ]]; then
            info_warn "Repository git alias '${GIT_ALIAS_NAME}' already set to our script (will overwrite): ${existing_alias}"
            break
        fi
        info_warn "Conflict: repository git alias '${GIT_ALIAS_NAME}' already exists with a different value:"
        echo -e "  ${existing_alias}"
        echo ""
        printf "${COLOR_YELLOW}Please enter a different alias name (or press Enter to abort): ${COLOR_RESET}"
        local new_alias
        read_tty new_alias
        if [[ -z "$new_alias" ]]; then
            die "Installation aborted due to alias conflict."
        fi
        GIT_ALIAS_NAME="$new_alias"
        info_success "Using new alias name: ${COLOR_BOLD}${GIT_ALIAS_NAME}${COLOR_RESET}"
    done

    mkdir -p "$scripts_dir"
    # Patch CLAUDE_CMD into the script
    sed "s|^CLAUDE_CMD=.*|CLAUDE_CMD=\"${CLAUDE_CMD_NAME}\"|" "$src" > "$dest"
    chmod 755 "$dest" || die "Failed to copy script."
    info_success "Script copied to: ${dest}"

    # Configure repository-level git alias
    info_msg "Configuring repository-level git alias: ${GIT_ALIAS_NAME}..."
    git config "alias.${GIT_ALIAS_NAME}" "!bash \"\$(git rev-parse --show-toplevel)/scripts/${SCRIPT_SOURCE_NAME}\""
    info_success "git alias configured: git ${GIT_ALIAS_NAME}"

    echo ""
    echo -e "  Verify config: ${COLOR_BOLD}git config alias.${GIT_ALIAS_NAME}${COLOR_RESET}"
    echo -e "  You can now use in this repository: ${COLOR_BOLD}git ${GIT_ALIAS_NAME} <branch>${COLOR_RESET}"
    echo ""
    info_warn "Note: this alias only applies to the current repository (${repo_root})."
    echo "  For global access, choose system or user mode, or configure a global alias manually:"
    echo -e "  ${COLOR_BOLD}git config --global alias.${GIT_ALIAS_NAME} '!bash \"/path/to/scripts/${SCRIPT_SOURCE_NAME}\"'${COLOR_RESET}"
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

    # Step 2: Prompt for alias name (if not set via --alias flag)
    if ! $_ALIAS_SET; then
        ask_alias_name_for_uninstall
    fi

    # Validate mode
    case "$INSTALL_MODE" in
        system|user|local) ;;
        *) die "Invalid uninstall mode: ${INSTALL_MODE}\n  Valid values: system | user | local" ;;
    esac

    info_msg "Uninstall mode: ${COLOR_BOLD}${INSTALL_MODE}${COLOR_RESET}"
    echo ""

    # Run uninstaller
    case "$INSTALL_MODE" in
        system) uninstall_system ;;
        user)   uninstall_user   ;;
        local)  uninstall_local  ;;
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

    # Step 2: Prompt for git alias name (if not set via --alias flag)
    if ! $_ALIAS_SET; then
        ask_alias_name
    fi

    # Step 3: Prompt for Claude Code command name (if not set via --cmd flag)
    if ! $_CMD_SET; then
        ask_claude_cmd
    fi

    # Validate mode
    case "$INSTALL_MODE" in
        system|user|local) ;;
        *) die "Invalid install mode: ${INSTALL_MODE}\n  Valid values: system | user | local" ;;
    esac

    info_msg "Install mode: ${COLOR_BOLD}${INSTALL_MODE}${COLOR_RESET}"
    echo ""

    # Get script file path
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
    echo -e "  Run ${COLOR_BOLD}git ${GIT_ALIAS_NAME} --help${COLOR_RESET} to see usage"
    echo -e "  Run ${COLOR_BOLD}git ${GIT_ALIAS_NAME} --version${COLOR_RESET} to check version"
    echo ""
fi
