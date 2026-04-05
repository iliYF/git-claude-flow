English | [中文](README.zh.md)

# git-claude-flow

> A Git workflow tool that deeply integrates **Git Worktree** with **Claude Code**, designed for **parallel multi-task AI-assisted development**.

## Quick Install

### One-line Install (Recommended)

```bash
curl -sSL https://raw.githubusercontent.com/iliYF/git-claude-flow/main/install.sh | bash
```

The installer will interactively prompt for three configuration options:

1. **Install mode** (default: `user`)
2. **git alias name** (default: `claude`)
3. **Claude Code command** (default: `claude`)

### Non-interactive Install

```bash
# Install to user directory with defaults
curl -sSL https://raw.githubusercontent.com/iliYF/git-claude-flow/main/install.sh | bash -s -- --mode user

# Full parameter example
curl -sSL https://raw.githubusercontent.com/iliYF/git-claude-flow/main/install.sh | bash -s -- \
  --mode user \
  --alias claude \
  --cmd claude-internal
```

### Local Install

```bash
git clone https://github.com/iliYF/git-claude-flow.git
cd git-claude-flow
bash install.sh
```

---

## Install Modes

| Mode | Script Location | Access Mechanism | Requires sudo | Scope |
|------|----------------|-----------------|---------------|-------|
| `system` | `~/.git-claude-flow/git-claude-flow` | git-subcommand mechanism (symlink in `/usr/local/bin/`) | Yes | All users, all repositories |
| `user` | `~/.git-claude-flow/git-claude-flow` | git config mechanism (`git config --global alias`) | No | Current user, all repositories |
| `local` | `<repo>/scripts/git-claude-flow` | git config mechanism (`git config alias`, repo-level) | No | Current git repository only |

> **`system` mode**: Uses the **git-subcommand mechanism**. Script is stored in `~/.git-claude-flow/`, with a symlink `git-<alias>` created in `/usr/local/bin/`. Git automatically discovers it as an external subcommand — no git config needed.
>
> **`user` mode**: Uses the **git config mechanism**. Script is stored in `~/.git-claude-flow/`, and a global git alias is configured in `~/.gitconfig`. Available to the current user in all repositories, no sudo required.
>
> **`local` mode**: Uses the **git config mechanism**. Script is copied into the repository's `scripts/` directory, with a repo-level git alias configured in `.git/config`. Great for team sharing via git.

---

## Installer Options

```
bash install.sh [options]

Options:
  --mode  <mode>      Install mode: system | user | local
  --alias <name>      git alias name (default: claude)
  --cmd   <command>   Claude Code command name (default: claude)
  --help              Show help information
  --version           Show version information
```

---

## Usage

After installation, run in any git repository:

```bash
# Create a worktree for the specified branch and launch Claude Code
git claude <branch-name>

# List all worktrees in the current repository
git claude list

# Clean up a worktree (interactive selection)
git claude clean

# Clean up the worktree for a specific branch
git claude clean feature/my-feature

# Show help
git claude -h

# Show version
git claude --version
```

---

## The Problem It Solves

Claude Code has a built-in `--worktree` (`-w`) flag that can quickly create a worktree and start a session:

```bash
claude --worktree feature-auth   # create worktree and launch Claude
claude --worktree bugfix-123
```

But this approach has clear limitations:

- **No branch control**: Automatically creates a new `worktree-<name>` branch — can't use existing local or remote branches
- **Fixed path**: Worktrees are created under `<repo>/.claude/worktrees/`, not the standard sibling-directory convention
- **Not a git flow**: `claude -w` is a Claude tool flag, not integrated into the Git workflow — teams can't manage worktrees uniformly via `git` commands

The more common scenario is **manual Git Worktree + multiple Claude sessions**:

```bash
# Manual workflow (tedious)
git worktree add ../myapp-feature-login feature/login  # manually create worktree
cd ../myapp-feature-login                              # manually switch directory
claude                                                 # manually launch Claude Code

# Another task? Repeat the whole thing...
git worktree add ../myapp-bugfix-crash bugfix/crash
cd ../myapp-bugfix-crash
claude
```

Every new task requires repeating this sequence, keeping track of each worktree path, and manually cleaning up when done.

**git-claude-flow compresses all of this into a single `git` command**, forming a complete git flow:

```bash
# One command: smart branch resolution → create worktree → switch directory → launch Claude Code
git claude feature/login     # use existing branch (local or remote)
git claude bugfix/crash      # another terminal, runs in parallel, fully isolated
git claude new-feature       # branch doesn't exist? auto-create from current HEAD
```

---

## Features

### 🌿 Smart Branch Resolution

When a branch name is provided, it is resolved in the following order:

1. **Local branch exists** → Use directly
2. **Remote branch exists** → Auto checkout and set up tracking
3. **Neither exists** → Create a new local branch from current HEAD

```bash
# Use an existing local branch
git claude feature/my-feature

# Auto checkout a remote branch
git claude feature/remote-only-branch

# Create a brand new branch
git claude feature/brand-new-feature
```

### 📁 Automatic Worktree Management

- Worktrees are created in the **same parent directory as the main repository**, named as `{repo-name}-{branch-sanitized}`
- Special characters in branch names (`/`, `.`, `#`, spaces, etc.) are automatically replaced with `-`
- **Existing worktrees are reused** — no duplicate creation
- **If the current directory is already the target worktree**, a notice is shown and Claude Code launches immediately

```
# Example: repo name "myapp", branch "feature/login"
# Worktree path: ../myapp-feature-login
```

### 🔍 Worktree List

```bash
git claude list
```

Example output:
```
Current Repository Worktree List:

  [main repo]  /path/to/myapp
    Branch: main  HEAD: a1b2c3d4

  [worktree 1] /path/to/myapp-feature-login
    Branch: feature/login  HEAD: e5f6g7h8
```

### 🧹 Worktree Cleanup

```bash
# Interactively select a worktree to remove
git claude clean

# Remove the worktree for a specific branch directly
git claude clean feature/login
```

During cleanup, you will be asked:
- Confirm deletion of the worktree directory
- Whether to also delete the local branch

---

## Requirements

| Dependency | Minimum Version | Notes |
|-----------|----------------|-------|
| bash | 3.2+ | macOS built-in version is sufficient |
| git | 2.5.0+ | Minimum version with worktree support |
| Claude Code | Latest | `npm install -g @anthropic-ai/claude-code` |

---

## Custom Claude Code Command

If your Claude Code executable is not named `claude` (e.g., `claude-internal`, `cc`, etc.), specify it during installation:

```bash
bash install.sh --cmd claude-internal
```

Or manually edit the `CLAUDE_CMD` variable in the installed script:

```bash
# Edit the installed script
vim ~/.git-claude-flow/git-claude-flow
# Change the variable at the top:
# CLAUDE_CMD="claude-internal"
```

---

## Workflow Example

```bash
# 1. Start a new Claude Code session on a feature branch
cd ~/projects/myapp
git claude feature/new-api

# → Worktree created: ~/projects/myapp-feature-new-api
# → Switched to that directory and Claude Code launched

# 2. Meanwhile, handle a bugfix in another terminal
git claude bugfix/fix-login

# → Worktree created: ~/projects/myapp-bugfix-fix-login
# → Two Claude Code sessions running in parallel, fully isolated

# 3. View all active worktrees
git claude list

# 4. Clean up when done
git claude clean feature/new-api
```

---

## License

MIT
