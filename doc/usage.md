# Bash Configuration Usage

本文档说明如何启用 `~/.config/bash/` 配置。

## 快速开始

### 1. 配置 `~/.bash_profile`

```bash
# ~/.bash_profile - Login Shell 入口

# 防止重复加载
[[ -n "$__BASH_PROFILE_LOADED" ]] && return
export __BASH_PROFILE_LOADED=1

# 加载 Login Shell 配置
[[ -f ~/.config/bash/profile.sh ]] && source ~/.config/bash/profile.sh

# 确保 login shell 也加载交互配置
[[ -f ~/.bashrc ]] && source ~/.bashrc
```

### 2. 配置 `~/.bashrc`

```bash
# ~/.bashrc - Interactive Shell 入口

# 非交互模式直接退出
[[ $- != *i* ]] && return

# 防止重复加载
[[ -n "$__BASHRC_LOADED" ]] && return
export __BASHRC_LOADED=1

# 加载 Interactive Shell 配置
[[ -f ~/.config/bash/bashrc.sh ]] && source ~/.config/bash/bashrc.sh
```

## 重复加载检测

### 为什么需要检测？

Bash 在不同场景下会多次 source 配置文件：

| 场景                        | `~/.bash_profile` | `~/.bashrc` |
|-----------------------------|-------------------|-------------|
| 终端登录 (SSH/TTY)          | ✓                 | ✓ (手动)    |
| 终端模拟器 (gnome-terminal) | ✓ (login shell)   | ✓           |
| `bash` 子 shell             | ✗                 | ✓           |
| `bash -l` (login shell)     | ✓                 | ✓ (手动)    |
| `su - user`                 | ✓                 | ✓ (手动)    |
| tmux 新窗口                 | 取决于配置        | ✓           |

不加检测可能导致：
- PATH 重复追加，越来越长
- 环境变量重复 export
- 初始化命令重复执行（starship/zoxide/fnm）

### 检测算法

使用环境变量标记已加载状态：

```bash
# 检测模式
[[ -n "$__BASH_PROFILE_LOADED" ]] && return
export __BASH_PROFILE_LOADED=1
```

**原理**：
1. 首次加载时 `$__BASH_PROFILE_LOADED` 为空，检测通过
2. 设置 `export __BASH_PROFILE_LOADED=1`，标记已加载
3. 再次 source 时检测到变量已设置，直接 `return` 退出

**为什么用 `export`**：
- 子 shell 会继承父 shell 的环境变量
- 确保 `bash` 子 shell 中不会重复加载 `~/.bashrc`

### 重新加载配置

如果修改了配置需要重新加载：

```bash
# 方式 1：使用 alias（推荐）
sss  # 已定义为 source ~/.config/bash/bashrc.sh

# 方式 2：清除标记后重新加载
unset __BASH_PROFILE_LOADED __BASHRC_LOADED
source ~/.bash_profile

# 方式 3：新开终端
```

## 本地敏感配置

敏感数据（API keys、tokens）存放在 `local/env.sh`，该目录已被 `.gitignore` 忽略。

### 创建本地配置

```bash
cp ~/.config/bash/samples/env.sh ~/.config/bash/local/env.sh
```

### 编辑 `local/env.sh`

```bash
# ~/.config/bash/local/env.sh

# Agent API 配置
export GHC_ANTHROPIC_BASE_URL="https://your-api-endpoint"
export GHC_ANTHROPIC_AUTH_TOKEN="your-token"
export GHC_GEMINI_BASE_URL="https://your-gemini-endpoint"
export GHC_GEMINI_AUTH_TOKEN="your-token"

# WSL 专用（可选）
export GHC_WINDOWS_USERNAME="YourWindowsUsername"

# 其他本地变量
export ROOT_SOURCECODES="$HOME/sourcecodes"
```

## 验证安装

```bash
# 新开终端后检查

# 1. 检查平台检测
echo $GHC_ENV_PLATFORM
# 期望: wsl / osx / nix

# 2. 检查 vi mode
set -o | grep -E '^vi\s'
# 期望: vi              on

# 3. 检查 starship
type starship && echo $STARSHIP_CONFIG
# 期望: ~/.config/starship/bash.toml

# 4. 检查环境变量
echo $EDITOR
# 期望: /path/to/nvim

# 5. 检查 PATH 无重复
echo $PATH | tr ':' '\n' | sort | uniq -d
# 期望: 无输出（无重复）
```

## 依赖工具

以下工具可选，缺失时对应功能会自动跳过：

| 工具      | 用途                | 检测方式            |
|-----------|---------------------|---------------------|
| starship  | 跨 shell prompt     | `command -v`        |
| zoxide    | 智能 cd             | `command -v`        |
| fnm       | Node 版本管理       | `command -v`        |
| fzf       | 模糊搜索            | `$HOMEBREW_PREFIX`  |
| fd        | 文件搜索            | fzf 函数内使用      |
| bat       | 语法高亮预览        | fzf 函数内使用      |
| lsd       | 现代 ls             | alias               |
| delta     | Git diff 高亮       | alias               |
| conda     | Python 环境管理     | 路径检测            |

## 故障排除

### PATH 重复

```bash
# 检查重复
echo $PATH | tr ':' '\n' | sort | uniq -d

# 如果有重复，检查是否正确设置了 guard
echo $__BASH_PROFILE_LOADED $__BASHRC_LOADED
# 期望: 1 1
```

### starship 不生效

```bash
# 检查是否安装
command -v starship

# 检查配置路径
echo $STARSHIP_CONFIG
ls -la $STARSHIP_CONFIG

# 手动初始化测试
eval "$(starship init bash)"
```

### vi mode 不生效

```bash
# 检查当前模式
set -o | grep -E '^(vi|emacs)'

# 手动启用
set -o vi
```

### 平台检测错误

```bash
# 检查当前平台
echo $GHC_ENV_PLATFORM

# 手动检测
uname
cat /proc/version 2>/dev/null | grep -Ei "(Microsoft|WSL)"
```
