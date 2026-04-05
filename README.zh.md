[English](README.md) | 中文 

# git-claude-flow

> 一个将 **Git Worktree** 与 **Claude Code** 深度整合的 Git 工作流工具。

基于指定分支自动创建独立的 worktree 工作目录，并在其中启动 Claude Code，让你可以同时在多个分支上并行开发，互不干扰。


---

## 目录结构

```
git-claude-flow/
├── install.sh              # 安装脚本（根目录）
└── scripts/
    └── git-claude-flow     # 核心脚本
```

---

## 快速安装

### 一键安装（推荐）

```bash
curl -sSL https://raw.githubusercontent.com/iliYF/git-claude-flow/main/install.sh | bash
```

安装过程会交互式询问三个配置项：

1. **安装模式**（默认 `user`）
2. **git alias 别名**（默认 `claude`）
3. **Claude Code 命令名**（默认 `claude`）

### 指定参数安装（非交互）

```bash
# 安装到用户目录，使用默认配置
curl -sSL https://raw.githubusercontent.com/iliYF/git-claude-flow/main/install.sh | bash -s -- --mode user

# 完整参数示例
curl -sSL https://raw.githubusercontent.com/iliYF/git-claude-flow/main/install.sh | bash -s -- \
  --mode user \
  --alias claude \
  --cmd claude-internal
```

### 本地安装

```bash
git clone https://github.com/iliYF/git-claude-flow.git
cd git-claude-flow
bash install.sh
```

---

## 安装模式说明

| 模式 | 安装位置 | 权限 | 生效范围 |
|------|---------|------|---------|
| `system` | `/usr/local/bin/git-claude` | 需要 sudo | 所有用户、所有仓库 |
| `user` | `~/.local/bin/git-claude` | 无需 sudo | 当前用户、所有仓库 |
| `local` | `<仓库>/scripts/git-claude-flow` | 无需 sudo | 仅当前 git 仓库 |

> **`system` / `user` 模式**：脚本安装到 PATH 后，git 会自动识别 `git-claude` 为外部命令，直接支持 `git claude` 调用。
>
> **`local` 模式**：脚本安装到仓库内，通过配置仓库级 git alias 调用。

---

## 安装脚本参数

```
bash install.sh [选项]

选项：
  --mode  <mode>      安装模式：system | user | local
  --alias <name>      git alias 别名（默认：claude）
  --cmd   <command>   Claude Code 命令名（默认：claude）
  --help              显示帮助信息
```

---

## 使用方法

安装完成后，在任意 git 仓库中执行：

```bash
# 基于指定分支创建 worktree 并启动 Claude Code
git claude <branch-name>

# 查看当前仓库所有 worktree
git claude list

# 清理 worktree（交互式选择）
git claude clean

# 清理指定分支的 worktree
git claude clean feature/my-feature

# 显示帮助
git claude --help
```

---

## 核心功能

### 🌿 智能分支识别

传入分支名时，自动按以下顺序处理：

1. **本地分支存在** → 直接使用
2. **远程同名分支存在** → 自动 checkout 并建立跟踪
3. **均不存在** → 基于当前 HEAD 创建新本地分支

```bash
# 使用本地分支
git claude feature/my-feature

# 自动 checkout 远程分支
git claude feature/remote-only-branch

# 创建全新分支
git claude feature/brand-new-feature
```

### 📁 Worktree 自动管理

- worktree 创建在**主仓库同级目录**，命名规则：`{repo-name}-{branch-sanitized}`
- 分支名中的 `/` `.` `#` 等特殊字符自动替换为 `-`
- **已存在的 worktree 自动复用**，不重复创建
- **当前目录已是对应 worktree** 时，直接提示并启动 Claude Code

```
# 示例：仓库名 myapp，分支 feature/login
# worktree 路径：../myapp-feature-login
```

### 🔍 Worktree 列表

```bash
git claude list
```

输出示例：
```
当前仓库 Worktree 列表：

  [主仓库]  /path/to/myapp
    分支：main  HEAD：a1b2c3d4

  [worktree 1] /path/to/myapp-feature-login
    分支：feature/login  HEAD：e5f6g7h8
```

### 🧹 Worktree 清理

```bash
# 交互式选择要清理的 worktree
git claude clean

# 直接指定分支名清理
git claude clean feature/login
```

清理时会询问：
- 是否确认删除 worktree 目录
- 是否同时删除本地分支

---

## 环境要求

| 依赖 | 最低版本 | 说明 |
|------|---------|------|
| bash | 3.2+ | macOS 自带版本即可 |
| git | 2.5.0+ | 支持 worktree 的最低版本 |
| Claude Code | 最新版 | `npm install -g @anthropic-ai/claude-code` |

---

## 手动配置（不使用安装脚本）

### 方式一：配置 git alias（推荐，无需系统权限）

```bash
# 克隆仓库到本地
git clone https://github.com/iliYF/git-claude-flow.git ~/.git-claude-flow

# 配置全局 git alias
git config --global alias.claude '!bash "$HOME/.git-claude-flow/scripts/git-claude-flow"'
```

### 方式二：安装到系统路径

```bash
# 安装到 /usr/local/bin（需要 sudo）
sudo install -m 755 scripts/git-claude-flow /usr/local/bin/git-claude

# 或安装到用户目录（无需 sudo）
mkdir -p ~/.local/bin
install -m 755 scripts/git-claude-flow ~/.local/bin/git-claude
# 确保 ~/.local/bin 在 PATH 中
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
```

### 方式三：仅对当前仓库生效

```bash
# 复制脚本到仓库
mkdir -p scripts
cp /path/to/git-claude-flow/scripts/git-claude-flow scripts/

# 配置仓库级 alias
git config alias.claude '!bash "$(git rev-parse --show-toplevel)/scripts/git-claude-flow"'
```

---

## 自定义 Claude Code 命令

如果你的 Claude Code 命令不是 `claude`（例如 `claude-internal`、`cc` 等），可以在安装时指定：

```bash
bash install.sh --cmd claude-internal
```

或安装后手动修改脚本中的 `CLAUDE_CMD` 变量：

```bash
# 编辑已安装的脚本
vim ~/.local/bin/git-claude
# 修改第一行变量：
# CLAUDE_CMD="claude-internal"
```

---

## 工作流示例

```bash
# 1. 在主仓库中，基于 feature 分支开启新的 Claude Code 会话
cd ~/projects/myapp
git claude feature/new-api

# → 自动创建 worktree：~/projects/myapp-feature-new-api
# → 切换到该目录并启动 Claude Code

# 2. 同时，在另一个终端处理 bugfix
git claude bugfix/fix-login

# → 自动创建 worktree：~/projects/myapp-bugfix-fix-login
# → 两个 Claude Code 会话并行运行，互不干扰

# 3. 查看所有工作区
git claude list

# 4. 完成后清理
git claude clean feature/new-api
```

---

## License

MIT
