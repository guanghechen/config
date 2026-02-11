# Bash Configuration Architecture

本文档定义 `~/.config/bash/` 的设计规范，目标是与 Fish 配置保持一致的结构和体验。

## 设计原则

1. **XDG 兼容** - 配置存放于 `~/.config/bash/`，通过 `~/.bash_profile` 和 `~/.bashrc` 引导
2. **Login/Non-login 分离** - 遵循 Bash 哲学，环境变量与交互配置严格分离
3. **模块化** - 按职责拆分文件，便于维护
4. **平台适配** - 支持 macOS / WSL / Linux 平台差异

## 引导配置

### `~/.bash_profile`

```bash
# Login Shell 入口
[[ -f ~/.config/bash/profile.bash ]] && source ~/.config/bash/profile.bash

# 确保 login shell 也加载交互配置
[[ -f ~/.bashrc ]] && source ~/.bashrc
```

### `~/.bashrc`

```bash
# 非交互模式直接退出
[[ $- != *i* ]] && return

# Interactive Shell 入口
[[ -f ~/.config/bash/bashrc.bash ]] && source ~/.config/bash/bashrc.bash
```

## 核心文件

### `profile.bash` - Login Shell

设置**可继承的环境变量**，只在 Login shell 执行一次：

- 平台检测（`GHC_ENV_PLATFORM`）
- XDG、LANG、TZ 等基础环境变量
- PATH 设置（Homebrew、~/.local/bin、~/.cargo/bin）
- EDITOR、VISUAL
- 应用环境变量（FZF_DEFAULT_COMMAND 等）
- 敏感环境变量（source `local/env.bash`）
- Agent 环境变量（ANTHROPIC_*、GEMINI_* 等）
- 平台特定环境变量（source `platform/*/profile.bash`）

```bash
BASH_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/bash"

# 平台检测
GHC_ENV_PLATFORM="nix"
if [[ "$(uname)" == "Darwin" ]]; then
    GHC_ENV_PLATFORM="osx"
elif [[ -r /proc/version ]] && grep -qEi "(Microsoft|WSL)" /proc/version; then
    GHC_ENV_PLATFORM="wsl"
fi
export GHC_ENV_PLATFORM

# PATH 设置（防重复）
_add_path() {
    [[ ":$PATH:" != *":$1:"* ]] && export PATH="$1:$PATH"
}

_add_path "$HOME/.local/bin"
_add_path "$HOME/.cargo/bin"

# 应用环境变量
export FZF_DEFAULT_COMMAND="fd --hidden --follow --type=f"
export FZF_DEFAULT_OPTS_FILE="$HOME/.config/fzf/fzf.fzfrc"

# 加载本地敏感环境变量
[[ -f "$BASH_CONFIG_DIR/local/env.bash" ]] && source "$BASH_CONFIG_DIR/local/env.bash"

# 加载平台特定环境变量
[[ -f "$BASH_CONFIG_DIR/platform/$GHC_ENV_PLATFORM/profile.bash" ]] && \
    source "$BASH_CONFIG_DIR/platform/$GHC_ENV_PLATFORM/profile.bash"
```

### `bashrc.bash` - Interactive Shell

每次打开终端都执行，负责**不可继承的配置**：

- 加载 `conf/` 下的模块
- 加载平台特定 alias/函数
- 加载函数库和补全

```bash
BASH_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/bash"

# 非 login shell 兜底平台检测（避免 GHC_ENV_PLATFORM 为空）
if [[ -z "${GHC_ENV_PLATFORM:-}" ]]; then
    GHC_ENV_PLATFORM="nix"
    if [[ "$(uname)" == "Darwin" ]]; then
        GHC_ENV_PLATFORM="osx"
    elif [[ -r /proc/version ]] && grep -qEi "(Microsoft|WSL)" /proc/version; then
        GHC_ENV_PLATFORM="wsl"
    fi
    export GHC_ENV_PLATFORM
fi

# 加载配置模块
source "$BASH_CONFIG_DIR/conf/app.bash"
source "$BASH_CONFIG_DIR/conf/alias.bash"
source "$BASH_CONFIG_DIR/conf/keymap.bash"

# 加载平台特定 alias/函数
[[ -f "$BASH_CONFIG_DIR/platform/$GHC_ENV_PLATFORM/bashrc.bash" ]] && \
    source "$BASH_CONFIG_DIR/platform/$GHC_ENV_PLATFORM/bashrc.bash"

# 加载函数库
for f in "$BASH_CONFIG_DIR"/functions/*.bash; do
    [[ -r "$f" ]] && source "$f"
done

# 加载补全
for f in "$BASH_CONFIG_DIR"/completions/*.bash; do
    [[ -r "$f" ]] && source "$f"
done
```

### `conf/app.bash` - 应用初始化

建议对 starship 做简单 guard，未安装时保持默认提示符：

```bash
if command -v starship >/dev/null 2>&1; then
    export STARSHIP_CONFIG="$HOME/.config/starship/bash.toml"
    eval "$(starship init bash)"
fi
```

## 与 Fish 配置的对应关系

| Fish                           | Bash                           | 说明                      |
|--------------------------------|--------------------------------|---------------------------|
| `config.fish`                  | `profile.bash` + `bashrc.bash` | 主入口（Bash 按职责拆分） |
| `conf/app.fish`                | `conf/app.bash`                | 应用初始化（含 starship） |
| `conf/alias.fish`              | `conf/alias.bash`              | 别名定义                  |
| `conf/keymap.fish`             | `conf/keymap.bash`             | 键绑定                    |
| `functions/*.fish`             | `functions/*.bash`             | 自定义函数                |
| `completions/*.fish`           | `completions/*.bash`           | 自定义补全                |
| `conf/platform/{osx,wsl,nix}/` | `platform/{osx,wsl,nix}/`      | 平台特定配置（拆分为 profile.bash + bashrc.bash） |
| `local/env.fish`               | `local/env.bash`               | 本地敏感配置              |
| `samples/env.fish`             | `samples/env.bash`             | 配置模板                  |

## 与 Fish 的关键差异

| 功能             | Fish                    | Bash                                     |
|------------------|-------------------------|------------------------------------------|
| 函数 autoload    | 原生支持                | 不支持，需启动时 source                  |
| Abbreviations    | `abbr` 命令             | 用 `alias` 替代                          |
| 键绑定           | `bind` 命令             | `bind` 命令或 `~/.inputrc`               |
| Prompt           | starship                | starship（~/.config/starship/bash.toml） |
| Universal vars   | `set -U`                | 用 `local/env.bash` 替代                 |
| Event handlers   | `--on-event`            | 用 `trap` 或 `PROMPT_COMMAND`            |

## 文件命名规范

- 核心入口：`profile.bash`（Login）、`bashrc.bash`（Interactive）
- conf 文件：`name.bash`（由 bashrc.bash 显式控制加载顺序）
- 函数文件：与函数同名，如 `ghc-proxy.bash` 定义 `ghc-proxy()`
- 平台配置：`platform/{osx,wsl,nix}/profile.bash` + `platform/{osx,wsl,nix}/bashrc.bash`

## Git 忽略规则

```gitignore
local/
```
