#!/usr/bin/env bash
# =============================================================================
# install.sh — git-claude-flow 安装脚本
# =============================================================================
#
# 用法：
#   # 在线安装（推荐）
#   curl -sSL https://example.com/scripts/install.sh | bash
#
#   # 指定安装模式
#   curl -sSL https://example.com/scripts/install.sh | bash -s -- --mode system
#   curl -sSL https://example.com/scripts/install.sh | bash -s -- --mode user
#   curl -sSL https://example.com/scripts/install.sh | bash -s -- --mode local
#
#   # 本地执行
#   bash scripts/install.sh
#   bash scripts/install.sh --mode system
#
# 安装模式：
#   system  将脚本安装到 /usr/local/bin/git-claude（需要 sudo）
#           所有用户均可直接使用 git claude 命令
#
#   user    将脚本安装到 ~/.local/bin/git-claude（无需 sudo）
#           当前用户可直接使用 git claude 命令
#
#   local   将脚本复制到当前 git 仓库的 scripts/ 目录
#           并配置仓库级 git alias（仅对当前仓库生效）
#
# =============================================================================

set -euo pipefail

# =============================================================================
# 配置
# =============================================================================

SCRIPT_NAME="git-claude"
SCRIPT_SOURCE_NAME="git-claude-flow"
SCRIPT_URL="https://example.com/scripts/git-claude-flow"
SYSTEM_INSTALL_DIR="/usr/local/bin"
USER_INSTALL_DIR="${HOME}/.local/bin"

# 用户配置（交互式询问后赋值）
GIT_ALIAS_NAME="claude"  # git alias 别名，默认 claude
CLAUDE_CMD_NAME="claude" # Claude Code 命令名，默认 claude

# 标志位：是否已通过命令行参数显式指定（避免重复询问）
_ALIAS_SET=false
_CMD_SET=false

# =============================================================================
# 彩色输出
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
# 帮助信息
# =============================================================================

show_help() {
    echo -e "${COLOR_BOLD}install.sh${COLOR_RESET} — git-claude-flow 安装脚本"
    echo ""
    echo -e "${COLOR_BOLD}用法：${COLOR_RESET}"
    echo "  bash install.sh [选项]"
    echo ""
    echo -e "${COLOR_BOLD}选项：${COLOR_RESET}"
    echo -e "  ${COLOR_CYAN}--mode${COLOR_RESET} <mode>      安装模式：system | user | local"
    echo -e "  ${COLOR_CYAN}--alias${COLOR_RESET} <name>     git alias 别名（默认：claude）"
    echo -e "  ${COLOR_CYAN}--cmd${COLOR_RESET} <command>    Claude Code 命令名（默认：claude）"
    echo -e "  ${COLOR_CYAN}--help${COLOR_RESET}             显示此帮助信息"
    echo ""
    echo -e "${COLOR_BOLD}安装模式（--mode）：${COLOR_RESET}"
    echo -e "  ${COLOR_CYAN}system${COLOR_RESET}   安装到 ${SYSTEM_INSTALL_DIR}/git-claude（需要 sudo，全局生效）"
    echo -e "  ${COLOR_CYAN}user${COLOR_RESET}     安装到 ${USER_INSTALL_DIR}/git-claude（无需 sudo，当前用户生效）"
    echo -e "  ${COLOR_CYAN}local${COLOR_RESET}    安装到当前 git 仓库 scripts/ 目录，并配置仓库级 git alias"
    echo ""
    echo -e "${COLOR_BOLD}在线安装示例：${COLOR_RESET}"
    echo "  curl -sSL ${SCRIPT_URL%/*}/install.sh | bash"
    echo "  curl -sSL ${SCRIPT_URL%/*}/install.sh | bash -s -- --mode system"
    echo "  curl -sSL ${SCRIPT_URL%/*}/install.sh | bash -s -- --mode user --alias cf --cmd claude"
    echo "  curl -sSL ${SCRIPT_URL%/*}/install.sh | bash -s -- --mode local"
}

# =============================================================================
# 参数解析
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
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            die "未知参数：$1\n  使用 --help 查看帮助"
            ;;
    esac
done

# =============================================================================
# 获取脚本内容（在线安装时从 URL 下载，本地执行时从同目录读取）
# =============================================================================

get_script_content() {
    # 判断是否通过管道执行（stdin 不是终端）
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-/dev/stdin}")" 2>/dev/null && pwd || echo "")"
    local local_script="${script_dir}/${SCRIPT_SOURCE_NAME}"

    if [[ -f "$local_script" ]]; then
        # 本地执行：直接使用同目录的脚本文件
        echo "$local_script"
    else
        # 在线安装：下载脚本到临时文件
        local tmp_file
        tmp_file=$(mktemp /tmp/git-claude-XXXXXX)
        info_msg "正在下载脚本：${SCRIPT_URL}"
        if command -v curl &>/dev/null; then
            curl -sSL "$SCRIPT_URL" -o "$tmp_file" || die "下载失败，请检查网络或 URL：${SCRIPT_URL}"
        elif command -v wget &>/dev/null; then
            wget -qO "$tmp_file" "$SCRIPT_URL" || die "下载失败，请检查网络或 URL：${SCRIPT_URL}"
        else
            die "未找到 curl 或 wget，无法下载脚本。"
        fi
        echo "$tmp_file"
    fi
}

# =============================================================================
# 交互式配置询问
# =============================================================================

# 从终端读取输入（兼容管道执行：curl | bash 时 stdin 不可用，改从 /dev/tty 读取）
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

# 询问 git alias 别名
ask_alias_name() {
    echo ""
    echo -e "${COLOR_BOLD}配置 git alias 别名：${COLOR_RESET}"
    echo -e "  安装后通过 ${COLOR_CYAN}git <alias> <branch>${COLOR_RESET} 调用"
    printf "请输入别名（默认：${COLOR_BOLD}claude${COLOR_RESET}）："
    local input_alias
    read_tty input_alias
    if [[ -n "$input_alias" ]]; then
        GIT_ALIAS_NAME="$input_alias"
    fi
    info_success "git alias 别名：${COLOR_BOLD}${GIT_ALIAS_NAME}${COLOR_RESET}"
}

# 询问 Claude Code 命令名
ask_claude_cmd() {
    echo ""
    echo -e "${COLOR_BOLD}配置 Claude Code 命令名：${COLOR_RESET}"
    echo -e "  脚本内部调用的 Claude Code 可执行命令（如 claude、claude-internal、cc 等）"
    printf "请输入命令名（默认：${COLOR_BOLD}claude${COLOR_RESET}）："
    local input_cmd
    read_tty input_cmd
    if [[ -n "$input_cmd" ]]; then
        CLAUDE_CMD_NAME="$input_cmd"
    fi
    info_success "Claude Code 命令：${COLOR_BOLD}${CLAUDE_CMD_NAME}${COLOR_RESET}"
}

# =============================================================================
# 安装模式选择（交互式）
# =============================================================================

select_mode() {
    echo ""
    echo -e "${COLOR_BOLD}请选择安装模式：${COLOR_RESET}"
    echo ""
    echo -e "  ${COLOR_CYAN}[1]${COLOR_RESET} ${COLOR_BOLD}system${COLOR_RESET}  — 安装到 ${SYSTEM_INSTALL_DIR}/git-claude（需要 sudo，所有用户生效）"
    echo -e "  ${COLOR_CYAN}[2]${COLOR_RESET} ${COLOR_BOLD}user${COLOR_RESET}    — 安装到 ${USER_INSTALL_DIR}/git-claude（无需 sudo，当前用户生效）"
    echo -e "  ${COLOR_CYAN}[3]${COLOR_RESET} ${COLOR_BOLD}local${COLOR_RESET}   — 安装到当前 git 仓库 scripts/ 目录，配置仓库级 git alias"
    echo ""
    echo -e "  ${COLOR_YELLOW}[0]${COLOR_RESET} 取消安装"
    echo ""
    printf "请输入序号 [0-3]（默认 2）："
    local choice
    read_tty choice
    choice="${choice:-2}"
    case "$choice" in
        1) INSTALL_MODE="system" ;;
        2) INSTALL_MODE="user" ;;
        3) INSTALL_MODE="local" ;;
        0) info_msg "已取消安装。"; exit 0 ;;
        *) die "无效的选项：${choice}" ;;
    esac
}

# =============================================================================
# 安装：system 模式
# =============================================================================

install_system() {
    local src="$1"
    local dest="${SYSTEM_INSTALL_DIR}/${SCRIPT_NAME}"
    # 将 CLAUDE_CMD 替换写入脚本
    local tmp_patched
    tmp_patched=$(mktemp /tmp/git-claude-patched-XXXXXX)
    sed "s|^CLAUDE_CMD=.*|CLAUDE_CMD=\"${CLAUDE_CMD_NAME}\"|" "$src" > "$tmp_patched"
    info_msg "安装到系统路径：${dest}（需要 sudo）"
    sudo install -m 755 "$tmp_patched" "$dest" || die "安装失败，请确认 sudo 权限。"
    rm -f "$tmp_patched"
    info_success "安装成功：${dest}"
    echo ""
    # system/user 模式：脚本文件名即为 git 外部命令，alias 别名需单独配置
    if [[ "$GIT_ALIAS_NAME" != "claude" ]]; then
        info_msg "配置全局 git alias：${GIT_ALIAS_NAME} -> git-claude"
        git config --global "alias.${GIT_ALIAS_NAME}" "!git-claude"
        info_success "git alias 配置成功：git ${GIT_ALIAS_NAME}"
    fi
    echo -e "  现在可以在任意 git 仓库中使用：${COLOR_BOLD}git ${GIT_ALIAS_NAME} <branch>${COLOR_RESET}"
}

# =============================================================================
# 安装：user 模式
# =============================================================================

install_user() {
    local src="$1"
    local dest="${USER_INSTALL_DIR}/${SCRIPT_NAME}"
    mkdir -p "$USER_INSTALL_DIR"
    # 将 CLAUDE_CMD 替换写入脚本
    local tmp_patched
    tmp_patched=$(mktemp /tmp/git-claude-patched-XXXXXX)
    sed "s|^CLAUDE_CMD=.*|CLAUDE_CMD=\"${CLAUDE_CMD_NAME}\"|" "$src" > "$tmp_patched"
    install -m 755 "$tmp_patched" "$dest" || die "安装失败。"
    rm -f "$tmp_patched"
    info_success "安装成功：${dest}"

    # 如果别名不是默认的 claude，配置全局 git alias
    if [[ "$GIT_ALIAS_NAME" != "claude" ]]; then
        info_msg "配置全局 git alias：${GIT_ALIAS_NAME} -> git-claude"
        git config --global "alias.${GIT_ALIAS_NAME}" "!git-claude"
        info_success "git alias 配置成功：git ${GIT_ALIAS_NAME}"
    fi

    # 检查 PATH 中是否包含 ~/.local/bin
    if ! echo "$PATH" | grep -q "$USER_INSTALL_DIR"; then
        echo ""
        info_warn "${USER_INSTALL_DIR} 不在 PATH 中，请将以下内容添加到 ~/.bashrc 或 ~/.zshrc："
        echo ""
        echo -e "  ${COLOR_BOLD}export PATH=\"\$HOME/.local/bin:\$PATH\"${COLOR_RESET}"
        echo ""
        echo "  添加后执行：source ~/.bashrc  （或重新打开终端）"
    else
        echo ""
        echo -e "  现在可以在任意 git 仓库中使用：${COLOR_BOLD}git ${GIT_ALIAS_NAME} <branch>${COLOR_RESET}"
    fi
}

# =============================================================================
# 安装：local 模式
# =============================================================================

install_local() {
    local src="$1"

    # 检查是否在 git 仓库中
    if ! git rev-parse --is-inside-work-tree &>/dev/null; then
        die "当前目录不是 git 仓库，local 模式需要在 git 仓库根目录下执行。"
    fi

    local repo_root
    repo_root=$(git rev-parse --show-toplevel)
    local scripts_dir="${repo_root}/scripts"
    local dest="${scripts_dir}/${SCRIPT_SOURCE_NAME}"

    mkdir -p "$scripts_dir"
    # 将 CLAUDE_CMD 替换写入脚本
    sed "s|^CLAUDE_CMD=.*|CLAUDE_CMD=\"${CLAUDE_CMD_NAME}\"|" "$src" > "$dest"
    chmod 755 "$dest" || die "复制脚本失败。"
    info_success "脚本已复制到：${dest}"

    # 配置仓库级 git alias
    info_msg "配置仓库级 git alias：${GIT_ALIAS_NAME}..."
    git config "alias.${GIT_ALIAS_NAME}" "!bash \"\$(git rev-parse --show-toplevel)/scripts/${SCRIPT_SOURCE_NAME}\""
    info_success "git alias 配置成功：git ${GIT_ALIAS_NAME}"

    echo ""
    echo -e "  验证配置：${COLOR_BOLD}git config alias.${GIT_ALIAS_NAME}${COLOR_RESET}"
    echo -e "  现在可以在当前仓库中使用：${COLOR_BOLD}git ${GIT_ALIAS_NAME} <branch>${COLOR_RESET}"
    echo ""
    info_warn "注意：此 alias 仅对当前仓库（${repo_root}）生效。"
    echo "  如需全局生效，请选择 system 或 user 模式，或手动配置全局 alias："
    echo -e "  ${COLOR_BOLD}git config --global alias.${GIT_ALIAS_NAME} '!bash \"/path/to/scripts/${SCRIPT_SOURCE_NAME}\"'${COLOR_RESET}"
}

# =============================================================================
# 主流程
# =============================================================================

echo ""
echo -e "${COLOR_BOLD}${COLOR_GREEN}============================================${COLOR_RESET}"
echo -e "${COLOR_BOLD}${COLOR_GREEN}  git-claude-flow 安装程序${COLOR_RESET}"
echo -e "${COLOR_BOLD}${COLOR_GREEN}============================================${COLOR_RESET}"
echo ""

# 步骤一：选择安装模式（未通过参数指定时交互询问）
if [[ -z "$INSTALL_MODE" ]]; then
    select_mode
fi

# 步骤二：询问 git alias 别名（未通过 --alias 参数指定时）
if ! $_ALIAS_SET; then
    ask_alias_name
fi

# 步骤三：询问 Claude Code 命令名（未通过 --cmd 参数指定时）
if ! $_CMD_SET; then
    ask_claude_cmd
fi

# 验证模式
case "$INSTALL_MODE" in
    system|user|local) ;;
    *) die "无效的安装模式：${INSTALL_MODE}\n  可选值：system | user | local" ;;
esac

info_msg "安装模式：${COLOR_BOLD}${INSTALL_MODE}${COLOR_RESET}"
echo ""

# 获取脚本文件路径
SCRIPT_FILE=$(get_script_content)

# 执行安装
case "$INSTALL_MODE" in
    system) install_system "$SCRIPT_FILE" ;;
    user)   install_user   "$SCRIPT_FILE" ;;
    local)  install_local  "$SCRIPT_FILE" ;;
esac

echo ""
echo -e "${COLOR_BOLD}${COLOR_GREEN}============================================${COLOR_RESET}"
echo -e "${COLOR_BOLD}${COLOR_GREEN}  ✓ 安装完成！${COLOR_RESET}"
echo -e "${COLOR_BOLD}${COLOR_GREEN}============================================${COLOR_RESET}"
echo ""
echo -e "  使用 ${COLOR_BOLD}git ${GIT_ALIAS_NAME} --help${COLOR_RESET} 查看帮助"
echo ""
