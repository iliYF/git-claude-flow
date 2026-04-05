[English](README.md) | 中文 

# git-claude-flow

> 一个将 **Git Worktree** 与 **Claude Code** 深度整合的 Git 工作流工具，专为**多任务并行 AI 编程**场景设计。

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
  --version           显示版本信息
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
git claude -h

# 显示版本
git claude --version
```

---

## 解决的问题

Claude Code 虽然内置了 `--worktree`（`-w`）标志，可以快速创建 worktree 并启动会话：

```bash
claude --worktree feature-auth   # 创建 worktree 并启动 Claude
claude --worktree bugfix-123
```

但这种方式有明显局限：

- **分支不可控**：自动创建 `worktree-<name>` 新分支，无法基于已有的本地/远程分支
- **路径固定**：worktree 创建在 `<repo>/.claude/worktrees/` 下，不符合 Git 标准的同级目录惯例
- **不是 git flow**：`claude -w` 是 Claude 工具的参数，不融入 Git 工作流，团队协作时无法通过 `git` 命令统一管理

更常见的场景是**手动 Git Worktree + 多 Claude 会话**：

```bash
# 手动流程（繁琐）
git worktree add ../myapp-feature-login feature/login  # 手动创建 worktree
cd ../myapp-feature-login                              # 手动切换目录
claude                                                 # 手动启动 Claude Code

# 另一个任务，再重复一遍...
git worktree add ../myapp-bugfix-crash bugfix/crash
cd ../myapp-bugfix-crash
claude
```

每次开启新任务都要重复这套流程，还要记住各个 worktree 的路径，完成后还要手动清理。

**git-claude-flow 将这一切压缩为一条 `git` 命令**，形成完整的 git flow：

```bash
# 一条命令完成：智能分支解析 → 创建 worktree → 切换目录 → 启动 Claude Code
git claude feature/login     # 基于已有分支（本地或远程）
git claude bugfix/crash      # 另一个终端，并行运行，互不干扰
git claude new-feature       # 不存在则自动从当前 HEAD 创建新分支
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
