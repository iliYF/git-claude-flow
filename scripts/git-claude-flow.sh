#!/usr/bin/env bash
# =============================================================================
# git-claude — Git Worktree + Claude Code shortcut command
# =============================================================================
#
# Description:
#   Creates a git worktree based on the specified branch, switches to the
#   corresponding directory, and launches Claude Code automatically.
#
# Installation (recommended: git alias, no system PATH required):
#   Place the script in your project directory (e.g. scripts/git-claude),
#   then configure a git alias:
#
#   # Repository-scoped alias
#   git config alias.claude '!bash "$(git rev-parse --show-toplevel)/scripts/git-claude"'
#
#   # Global alias (requires absolute path to the script)
#   git config --global alias.claude '!bash "/path/to/scripts/git-claude"'
#
#   Then use:
#   git claude <branch-name>
#
# Alternative installation (install to system PATH):
#   sudo cp git-claude /usr/local/bin/git-claude && sudo chmod +x /usr/local/bin/git-claude
#   # Or install to user directory:
#   cp git-claude ~/.local/bin/git-claude && chmod +x ~/.local/bin/git-claude
#
# Usage:
#   git claude <branch-name>
#   git claude -h | -info
#
# Examples:
#   git claude feature/my-feature
#   git claude bugfix/fix-login
#   git claude origin/feature/remote-branch
#
# Requirements:
#   - bash 3.2+
#   - git 2.5.0+ (minimum version with worktree support)
#   - cc (Claude Code CLI alias, alias cc=claude)
#
# =============================================================================

# Claude Code command name (change this variable to switch commands)
CLAUDE_CMD="claude-internal"

# Version
VERSION="1.0.0"

set -euo pipefail

# =============================================================================
# Color output functions
# =============================================================================

# Detect whether the terminal supports colors
if [ -t 1 ] && command -v tput &>/dev/null && tput colors &>/dev/null && [ "$(tput colors)" -ge 8 ]; then
    COLOR_RESET="\033[0m"
    COLOR_GREEN="\033[0;32m"
    COLOR_YELLOW="\033[0;33m"
    COLOR_RED="\033[0;31m"
    COLOR_CYAN="\033[0;36m"
    COLOR_BOLD="\033[1m"
else
    COLOR_RESET=""
    COLOR_GREEN=""
    COLOR_YELLOW=""
    COLOR_RED=""
    COLOR_CYAN=""
    COLOR_BOLD=""
fi

# Print success message (green)
info_success() {
    echo -e "${COLOR_GREEN}✓ $*${COLOR_RESET}"
}

# Print info message (cyan)
info_msg() {
    echo -e "${COLOR_CYAN}→ $*${COLOR_RESET}"
}

# Print warning message (yellow)
info_warn() {
    echo -e "${COLOR_YELLOW}⚠ $*${COLOR_RESET}"
}

# Print error message (red)
info_error() {
    echo -e "${COLOR_RED}✗ $*${COLOR_RESET}" >&2
}

# Print error message and exit (exit code 1)
die() {
    info_error "$*"
    exit 1
}

# =============================================================================
# Help
# =============================================================================

show_help() {
    echo -e "${COLOR_BOLD}git-claude${COLOR_RESET} — Git Worktree + Claude Code shortcut command"
    echo ""
    echo -e "${COLOR_BOLD}Usage:${COLOR_RESET}"
    echo "  git claude <branch-name>    Create a worktree for the branch and launch Claude Code"
    echo "  git claude list             List all worktrees in the current repository"
    echo "  git claude clean [branch]   Remove a worktree (interactive if branch not specified)"
    echo "  git claude -h | -info       Show this help message"
    echo ""
    echo -e "${COLOR_BOLD}Arguments:${COLOR_RESET}"
    echo "  <branch-name>    Target branch name (local or remote)"
    echo ""
    echo -e "${COLOR_BOLD}Examples:${COLOR_RESET}"
    echo "  git claude feature/my-feature"
    echo "  git claude bugfix/fix-login"
    echo "  git claude origin/feature/remote-branch"
    echo ""
    echo -e "${COLOR_BOLD}Worktree Directory Rules:${COLOR_RESET}"
    echo "  Worktrees are created in the same parent directory as the main repo:"
    echo "  {repo-name}-{branch-name-sanitized}"
    echo "  (Special characters / . # in branch names are replaced with -)" 
    echo ""
    echo -e "${COLOR_BOLD}Requirements:${COLOR_RESET}"
    echo "  - git 2.5.0+"
    echo "  - ${CLAUDE_CMD} (Claude Code CLI, alias cc=claude)"
    echo ""
    echo -e "${COLOR_BOLD}Installation (recommended):${COLOR_RESET}"
    echo "  # Place the script in your project (e.g. scripts/git-claude), configure git alias:"
    echo "  git config alias.claude '!bash \"\$(git rev-parse --show-toplevel)/scripts/git-claude\"'"
    echo ""
    echo "  # Global alias (requires absolute path):"
    echo "  git config --global alias.claude '!bash \"/path/to/scripts/git-claude\"'"
    echo ""
    echo -e "${COLOR_BOLD}Version:${COLOR_RESET} ${VERSION}"
}

# =============================================================================
# Argument parsing
# =============================================================================

# Show help and exit when no arguments are provided
if [ $# -eq 0 ]; then
    show_help
    exit 1
fi

# =============================================================================
# Subcommand: list — display all worktrees
# =============================================================================

cmd_list() {
    # Get main repository root
    if ! git rev-parse --is-inside-work-tree &>/dev/null; then
        die "Not a git repository. Please run this command inside a git repository."
    fi
    local git_common_dir repo_root
    git_common_dir=$(git rev-parse --git-common-dir 2>/dev/null)
    if [[ "$git_common_dir" != ".git" ]]; then
        repo_root=$(dirname "$git_common_dir")
    else
        repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
    fi

    echo -e "${COLOR_BOLD}Worktree List:${COLOR_RESET}"
    echo ""

    local index=0
    while IFS= read -r line; do
        if [[ "$line" == worktree\ * ]]; then
            local wt_path="${line#worktree }"
            local wt_branch wt_head wt_bare
            # Read subsequent fields
            IFS= read -r head_line
            IFS= read -r branch_line
            wt_head="${head_line#HEAD }"
            if [[ "$branch_line" == branch\ * ]]; then
                wt_branch="${branch_line#branch refs/heads/}"
            elif [[ "$branch_line" == "bare" ]]; then
                wt_branch="(bare)"
            else
                wt_branch="(detached HEAD)"
            fi

            index=$((index + 1))
            if [[ "$wt_path" == "$repo_root" ]]; then
                echo -e "  ${COLOR_BOLD}${COLOR_GREEN}[main repo]${COLOR_RESET}  ${COLOR_BOLD}${wt_path}${COLOR_RESET}"
            else
                echo -e "  ${COLOR_CYAN}[worktree ${index}]${COLOR_RESET} ${wt_path}"
            fi
            echo -e "    Branch: ${COLOR_BOLD}${wt_branch}${COLOR_RESET}  HEAD: ${wt_head:0:8}"
            echo ""
        fi
    done < <(git -C "$repo_root" worktree list --porcelain 2>/dev/null)
}

# =============================================================================
# Subcommand: clean — remove a worktree
# =============================================================================

cmd_clean() {
    local target_branch="$1"

    # Get main repository root
    if ! git rev-parse --is-inside-work-tree &>/dev/null; then
        die "Not a git repository. Please run this command inside a git repository."
    fi
    local git_common_dir repo_root
    git_common_dir=$(git rev-parse --git-common-dir 2>/dev/null)
    if [[ "$git_common_dir" != ".git" ]]; then
        repo_root=$(dirname "$git_common_dir")
    else
        repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
    fi

    # Collect all non-main-repo worktree paths and branches
    local wt_paths=() wt_branches=()
    local current_path="" current_branch=""
    while IFS= read -r line; do
        if [[ "$line" == worktree\ * ]]; then
            current_path="${line#worktree }"
        elif [[ "$line" == branch\ * ]]; then
            current_branch="${line#branch refs/heads/}"
        elif [[ -z "$line" && -n "$current_path" ]]; then
            # Empty line marks end of a record; exclude the main repo
            if [[ "$current_path" != "$repo_root" ]]; then
                wt_paths+=("$current_path")
                wt_branches+=("${current_branch:-detached}")
            fi
            current_path=""
            current_branch=""
        fi
    done < <(git -C "$repo_root" worktree list --porcelain 2>/dev/null; echo "")

    if [ ${#wt_paths[@]} -eq 0 ]; then
        info_msg "No worktrees available to clean."
        return 0
    fi

    local target_path=""
    local target_idx=-1

    if [[ -n "$target_branch" ]]; then
        # Branch specified — find the corresponding worktree
        for i in "${!wt_branches[@]}"; do
            if [[ "${wt_branches[$i]}" == "$target_branch" ]]; then
                target_path="${wt_paths[$i]}"
                target_idx=$i
                break
            fi
        done
        if [[ -z "$target_path" ]]; then
            die "No worktree found for branch '${target_branch}'.\n  Run 'git claude list' to see all current worktrees."
        fi
    else
        # No branch specified, interactive selection
        echo -e "${COLOR_BOLD}Select a worktree to remove:${COLOR_RESET}"
        echo ""
        for i in "${!wt_paths[@]}"; do
            echo -e "  ${COLOR_CYAN}[$((i+1))]${COLOR_RESET} ${wt_branches[$i]}"
            echo "      Path: ${wt_paths[$i]}"
            echo ""
        done
            echo -e "  ${COLOR_YELLOW}[0]${COLOR_RESET} Cancel"
            echo ""
            printf "Enter number: "
            local choice
            read -r choice
            if [[ "$choice" == "0" || -z "$choice" ]]; then
                info_msg "Cancelled."
                return 0
            fi
            if ! [[  "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#wt_paths[@]} ]; then
                die "Invalid selection: ${choice}"
            fi
        target_idx=$((choice - 1))
        target_path="${wt_paths[$target_idx]}"
        target_branch="${wt_branches[$target_idx]}"
    fi

    echo ""
    echo -e "  ${COLOR_BOLD}Branch:${COLOR_RESET} ${target_branch}"
    echo -e "  ${COLOR_BOLD}Path:${COLOR_RESET}   ${target_path}"
    echo ""
    printf "${COLOR_YELLOW}Confirm removal of this worktree? [y/N] ${COLOR_RESET}"
    read -r confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        info_msg "Cancelled."
        return 0
    fi

    info_msg "Removing worktree..."
    if ! git -C "$repo_root" worktree remove "$target_path" 2>/dev/null; then
        # Worktree has uncommitted changes, prompt for force removal
        info_warn "The worktree has uncommitted changes."
        printf "${COLOR_YELLOW}Force remove anyway? [y/N] ${COLOR_RESET}"
        read -r force_confirm
        if [[ "$force_confirm" != "y" && "$force_confirm" != "Y" ]]; then
            info_msg "Cancelled."
            return 0
        fi
        if ! git -C "$repo_root" worktree remove --force "$target_path"; then
            die "Force removal failed. Please run manually:\n  git worktree remove --force '${target_path}'"
        fi
    fi
    info_success "Worktree removed: ${target_path}"

    # Ask whether to also delete the local branch
    if [[ "$target_branch" != "detached" ]]; then
        echo ""
        printf "${COLOR_YELLOW}Also delete local branch '${target_branch}'? [y/N] ${COLOR_RESET}"
        read -r del_branch
        if [[ "$del_branch" == "y" || "$del_branch" == "Y" ]]; then
            if git -C "$repo_root" branch -d "$target_branch" 2>/dev/null; then
                info_success "Local branch deleted: ${target_branch}"
            elif git -C "$repo_root" branch -D "$target_branch" 2>/dev/null; then
                info_success "Local branch force-deleted: ${target_branch}"
            else
                info_warn "Failed to delete local branch. Please run manually: git branch -d ${target_branch}"
            fi
        fi
    fi
}

# =============================================================================
# Subcommand dispatch
# =============================================================================

case "$1" in
    -h|-info)
        show_help
        exit 0
        ;;
    -v|--version)
        echo "git-claude-flow ${VERSION}"
        exit 0
        ;;
    list)
        cmd_list
        exit 0
        ;;
    clean)
        cmd_clean "${2:-}"
        exit 0
        ;;
esac

BRANCH_NAME="$1"

# =============================================================================
# Environment and dependency checks
# =============================================================================

# Check if inside a git repository
check_git_repo() {
    if ! git rev-parse --is-inside-work-tree &>/dev/null; then
        die "Not a git repository. Please run this command inside a git repository."
    fi
    # Ensure we can get info from the main repo root (not a worktree subdirectory)
    local git_dir
    git_dir=$(git rev-parse --git-dir 2>/dev/null)
    # If git_dir is not .git but a worktree gitdir file, we are inside a worktree
    # Still allow execution but notify the user
    if [[ "$git_dir" != ".git" && "$git_dir" != *"/.git" ]]; then
        info_warn "Current directory appears to be a worktree. A new worktree will be created from the main repository."
    fi
}

# Check git version >= 2.5.0
check_git_version() {
    if ! command -v git &>/dev/null; then
        die "git not found. Please install git: https://git-scm.com/downloads"
    fi

    local git_version
    git_version=$(git --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    local major minor patch
    IFS='.' read -r major minor patch <<< "$git_version"

    if [ "$major" -lt 2 ] || { [ "$major" -eq 2 ] && [ "$minor" -lt 5 ]; }; then
        die "git version too old (current: ${git_version}, required: >= 2.5.0).\n  Please upgrade git: https://git-scm.com/downloads"
    fi
}

# Check if Claude Code command is available
check_claude_installed() {
    if ! command -v "$CLAUDE_CMD" &>/dev/null; then
        die "'${CLAUDE_CMD}' command not found. Please install Claude Code CLI:\n  npm install -g @anthropic-ai/claude-code\n  alias cc=claude\n  See: https://docs.anthropic.com/claude-code"
    fi
}

info_msg "Checking environment dependencies..."
check_git_version
check_git_repo
check_claude_installed
info_success "Environment check passed"

# =============================================================================
# Branch resolution: identify local/remote branch
# =============================================================================

# Get main repository root (compatible with running inside a worktree)
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
# If inside a worktree, find the main repository root
GIT_COMMON_DIR=$(git rev-parse --git-common-dir 2>/dev/null)
if [[ "$GIT_COMMON_DIR" != ".git" ]]; then
    # Inside a worktree: git-common-dir points to the main repo's .git directory
    MAIN_REPO_ROOT=$(dirname "$GIT_COMMON_DIR")
else
    MAIN_REPO_ROOT="$REPO_ROOT"
fi

# Strip origin/ prefix for local branch lookup
LOCAL_BRANCH="$BRANCH_NAME"
REMOTE_PREFIX=""
if [[ "$BRANCH_NAME" == origin/* ]]; then
    LOCAL_BRANCH="${BRANCH_NAME#origin/}"
    REMOTE_PREFIX="origin/"
fi

info_msg "Resolving branch: ${BRANCH_NAME}..."

# Check if local branch exists
LOCAL_EXISTS=false
if git -C "$MAIN_REPO_ROOT" branch --list "$LOCAL_BRANCH" | grep -q "$LOCAL_BRANCH"; then
    LOCAL_EXISTS=true
fi

# Check if remote branch exists
REMOTE_EXISTS=false
if git -C "$MAIN_REPO_ROOT" ls-remote --heads origin "$LOCAL_BRANCH" 2>/dev/null | grep -q "$LOCAL_BRANCH"; then
    REMOTE_EXISTS=true
fi

if $LOCAL_EXISTS; then
    # Case 1: local branch exists, use directly
    info_success "Found local branch: ${LOCAL_BRANCH}"
    FINAL_BRANCH="$LOCAL_BRANCH"
elif $REMOTE_EXISTS; then
    # Case 2: local branch missing, but remote branch exists — checkout and track
    info_msg "Local branch not found. Checking out remote branch origin/${LOCAL_BRANCH} with tracking..."
    if ! git -C "$MAIN_REPO_ROOT" branch --track "$LOCAL_BRANCH" "origin/$LOCAL_BRANCH" 2>/dev/null; then
        die "Failed to checkout remote branch.\n  Verify that origin/${LOCAL_BRANCH} is accessible, or run manually:\n  git fetch origin && git branch --track ${LOCAL_BRANCH} origin/${LOCAL_BRANCH}"
    fi
    info_success "Checked out remote branch: ${LOCAL_BRANCH} -> origin/${LOCAL_BRANCH}"
    FINAL_BRANCH="$LOCAL_BRANCH"
else
    # Case 3: neither local nor remote exists — create a new local branch
    info_warn "Branch '${LOCAL_BRANCH}' not found locally or remotely. Creating new branch from current HEAD..."
    if ! git -C "$MAIN_REPO_ROOT" branch "$LOCAL_BRANCH" 2>/dev/null; then
        die "Failed to create new branch.\n  Check that '${LOCAL_BRANCH}' is a valid branch name, or run manually:\n  git branch ${LOCAL_BRANCH}"
    fi
    info_success "Created new local branch: ${LOCAL_BRANCH}"
    FINAL_BRANCH="$LOCAL_BRANCH"
fi

# =============================================================================
# Worktree directory path generation
# =============================================================================

# Get repository name (main repo directory name)
REPO_NAME=$(basename "$MAIN_REPO_ROOT")

# Replace special characters (/ . # spaces etc.) in branch name with -
BRANCH_SANITIZED=$(echo "$FINAL_BRANCH" | sed 's|[/\.# ]|-|g')

# Generate worktree target path (sibling of main repo)
PARENT_DIR=$(dirname "$MAIN_REPO_ROOT")
WORKTREE_DIR="${PARENT_DIR}/${REPO_NAME}-${BRANCH_SANITIZED}"

info_msg "Worktree target path: ${WORKTREE_DIR}"

# =============================================================================
# Worktree existence check and creation
# =============================================================================

# Find the worktree path already associated with the branch (returns empty if none)
find_worktree_by_branch() {
    local branch="$1"
    local found_path=""
    local cur_path="" cur_branch=""
    while IFS= read -r line; do
        if [[ "$line" == worktree\ * ]]; then
            cur_path="${line#worktree }"
        elif [[ "$line" == branch\ * ]]; then
            cur_branch="${line#branch refs/heads/}"
        elif [[ -z "$line" ]]; then
            if [[ "$cur_branch" == "$branch" && -n "$cur_path" ]]; then
                found_path="$cur_path"
                break
            fi
            cur_path=""; cur_branch=""
        fi
    done < <(git -C "$MAIN_REPO_ROOT" worktree list --porcelain 2>/dev/null; echo "")
    echo "$found_path"
}

# Check if the target path is already managed by git worktree
is_git_worktree() {
    local target_dir="$1"
    git -C "$MAIN_REPO_ROOT" worktree list --porcelain 2>/dev/null \
        | grep "^worktree " \
        | awk '{print $2}' \
        | grep -qF "$target_dir"
}

# Priority check: does the branch already have an associated worktree (regardless of path)
EXISTING_WORKTREE=$(find_worktree_by_branch "$FINAL_BRANCH")

if [[ -n "$EXISTING_WORKTREE" ]]; then
    # Branch already has a worktree — check if it's the current directory
    CURRENT_DIR=$(pwd -P)
    EXISTING_REAL=$(cd "$EXISTING_WORKTREE" 2>/dev/null && pwd -P || echo "$EXISTING_WORKTREE")
    if [[ "$CURRENT_DIR" == "$EXISTING_REAL" ]]; then
        info_warn "Current directory is already the worktree for branch '${FINAL_BRANCH}'. No switch needed."
        echo ""
        echo -e "  ${COLOR_BOLD}Branch:${COLOR_RESET} ${FINAL_BRANCH}"
        echo -e "  ${COLOR_BOLD}Path:${COLOR_RESET}   ${EXISTING_WORKTREE}"
        echo ""
        info_msg "Launching Claude Code in current directory..."
        echo ""
        exec "$CLAUDE_CMD"
    else
        info_warn "Branch '${FINAL_BRANCH}' already has a worktree. Reusing: ${EXISTING_WORKTREE}"
        WORKTREE_DIR="$EXISTING_WORKTREE"
    fi
elif [ -d "$WORKTREE_DIR" ]; then
    if is_git_worktree "$WORKTREE_DIR"; then
        info_warn "Target path is already a worktree. Reusing: ${WORKTREE_DIR}"
    else
        die "Directory '${WORKTREE_DIR}' already exists but is not managed by git (directory conflict).\n  Please resolve manually:\n  rm -rf '${WORKTREE_DIR}'"
    fi
else
    info_msg "Creating worktree..."
    if ! git -C "$MAIN_REPO_ROOT" worktree add "$WORKTREE_DIR" "$FINAL_BRANCH" 2>&1; then
        die "Failed to create worktree.\n  Please check:\n  1. Write permission for '${WORKTREE_DIR}'\n  2. Run 'git claude list' to inspect current worktree state"
    fi
    info_success "Worktree created: ${WORKTREE_DIR}"
fi

# =============================================================================
# Print success summary and launch Claude Code
# =============================================================================

echo ""
echo -e "${COLOR_BOLD}${COLOR_GREEN}========================================${COLOR_RESET}"
echo -e "${COLOR_BOLD}${COLOR_GREEN}  ✓ Worktree ready${COLOR_RESET}"
echo -e "${COLOR_BOLD}${COLOR_GREEN}========================================${COLOR_RESET}"
echo -e "  ${COLOR_BOLD}Branch:${COLOR_RESET} ${FINAL_BRANCH}"
echo -e "  ${COLOR_BOLD}Path:${COLOR_RESET}   ${WORKTREE_DIR}"
echo -e "${COLOR_BOLD}${COLOR_GREEN}========================================${COLOR_RESET}"
echo ""
info_msg "Switching to worktree directory and launching Claude Code..."
echo ""

# Switch to the worktree directory and launch Claude Code
# Use exec to hand over shell control to the Claude Code process
cd "$WORKTREE_DIR" || die "Cannot switch to directory: ${WORKTREE_DIR}"
exec "$CLAUDE_CMD"
