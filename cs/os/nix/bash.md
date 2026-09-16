# Bash Configuration Files

Bash 配置文件的加载机制取决于 shell 的两个维度：**Login / Non-login** 和 **Interactive / Non-interactive**。

## Shell 类型

### 维度一：Login vs Non-login

| 类型          | 触发场景                                           |
|---------------|----------------------------------------------------|
| **Login**     | SSH 登录、`su -`、TTY 登录、`bash --login`         |
| **Non-login** | 打开终端模拟器、执行脚本、`su`（无 `-`）、子 shell |

### 维度二：Interactive vs Non-interactive

| 类型                | 特征                     |
|---------------------|--------------------------|
| **Interactive**     | 有 prompt，等待用户输入  |
| **Non-interactive** | 执行脚本，无交互         |

### 为什么要区分 Login / Non-login？

核心原因：**性能优化 + 职责分离**。

**1. 环境变量只需设置一次**

环境变量会被子进程继承，无需重复设置：

```
SSH 登录 (Login Shell) → 设置 PATH
    ↓
tmux (Non-login) → 继承 PATH
    ↓
new pane (Non-login) → 继承 PATH
```

如果每个 shell 都执行 `export PATH="$HOME/bin:$PATH"`，会导致 `PATH` 重复追加、越来越长。

**2. alias / 函数不可继承**

| 配置类型              | 可继承？ | 应放在            |
|-----------------------|----------|-------------------|
| 环境变量              | ✓        | `~/.bash_profile` |
| alias / 函数 / prompt | ✗        | `~/.bashrc`       |

alias 和函数不会被子进程继承，所以每个 interactive shell 都需要加载 `~/.bashrc`。

**总结**：Login Shell 负责"一次性初始化"，Non-login Shell 负责"每次都需要的配置"。

## 四种组合及加载顺序

两个维度组合形成 4 种场景，日常最常见：**Login + Interactive**（SSH）和 **Non-login + Interactive**（终端模拟器）。

### Login Shell（Interactive / Non-interactive）

Bash 对 Login Shell 的配置加载逻辑相同，不区分 Interactive / Non-interactive：

:::info 加载顺序
```
/etc/profile
    ├── source /etc/profile.d/*.sh
    ↓
~/.bash_profile  ─┬─  若不存在 → ~/.bash_login
                  └─  若仍不存在 → ~/.profile
```
:::

:::warn 互斥加载
`~/.bash_profile`、`~/.bash_login`、`~/.profile` 三者**只加载第一个找到的**，互斥关系。
:::

虽然加载的文件相同，但 `~/.bashrc` 是否生效取决于**惯例**：

| 场景                                         | `~/.bashrc` 是否生效？                             |
|----------------------------------------------|----------------------------------------------------|
| Login + Interactive（SSH 登录）              | 通常生效（`~/.bash_profile` 中手动 source）        |
| Login + Non-interactive（`bash -l script.sh`）| 通常不生效（即使 source，bashrc 开头会检测并退出）|

`~/.bashrc` 开头的 `[[ $- != *i* ]] && return` 会在 non-interactive 时直接退出，所以即使被 source 也不会执行后续配置。

### Non-login Shell（Interactive / Non-interactive）

与 Login Shell 不同，Non-login Shell 的 Interactive 和 Non-interactive 加载逻辑**完全不同**：

| 场景                                    | 加载的配置                       |
|-----------------------------------------|----------------------------------|
| Non-login + Interactive（终端模拟器）   | `/etc/bash.bashrc` + `~/.bashrc` |
| Non-login + Non-interactive（执行脚本） | 仅 `$BASH_ENV`（若已设置）       |

**Non-login + Interactive**（如打开终端模拟器）：

:::info 加载顺序
```
/etc/bash.bashrc  (Debian/Ubuntu 系；Red Hat 系为 /etc/bashrc)
    ↓
~/.bashrc
```
:::

**Non-login + Non-interactive**（如 `bash script.sh`）：

:::info 加载顺序
```
(不加载 /etc/bash.bashrc 和 ~/.bashrc)
    ↓
若设置了 $BASH_ENV，则 source $BASH_ENV
    ↓
执行脚本
```
:::

执行脚本时不需要 alias、prompt 等交互功能，跳过这些配置可以**提升启动速度**。

## 配置文件一览

| 文件               | 作用域 | 加载时机          | 主要用途                   |
|--------------------|--------|-------------------|----------------------------|
| `/etc/profile`     | 全局   | Login Shell       | 系统级环境变量、PATH 设置  |
| `/etc/bash.bashrc` | 全局   | Interactive Shell | 系统级 alias、prompt 设置  |
| `~/.bash_profile`  | 用户   | Login Shell       | 用户环境变量（优先级最高） |
| `~/.bash_login`    | 用户   | Login Shell       | 同上（备选，较少使用）     |
| `~/.profile`       | 用户   | Login Shell       | 同上（兼容 sh，优先级最低）|
| `~/.bashrc`        | 用户   | Interactive Shell | 用户 alias、函数、prompt   |

### `/etc/profile`

- **作用域**：所有用户
- **时机**：Login Shell
- **内容**：系统级 `PATH`、`umask`、环境变量
- **特点**：通常会 source `/etc/profile.d/*.sh`

### `/etc/bash.bashrc`

- **作用域**：所有用户
- **时机**：Interactive Non-login Shell
- **内容**：系统级 alias、prompt、补全设置

:::info 发行版差异
Debian/Ubuntu 使用 `/etc/bash.bashrc`，Red Hat 系使用 `/etc/bashrc`。
:::

### `~/.bash_profile`

- **作用域**：当前用户
- **时机**：Login Shell（优先级最高）
- **惯用法**：设置环境变量，然后 source `~/.bashrc`

### `~/.bash_login`

- **作用域**：当前用户
- **时机**：Login Shell（`~/.bash_profile` 不存在时）
- **现状**：历史遗留，很少使用

### `~/.profile`

- **作用域**：当前用户
- **时机**：Login Shell（前两者都不存在时）
- **特点**：兼容 POSIX sh，不能包含 bash-only 语法
- **用途**：在多种 shell 间共享配置

### `~/.bashrc`

- **作用域**：当前用户
- **时机**：Interactive Non-login Shell
- **内容**：alias、函数、prompt (`PS1`)、补全、历史设置

## 最佳实践

### `~/.bash_profile`

```bash
# 环境变量
export PATH="$HOME/bin:$PATH"
export EDITOR=vim

# 关键：确保 login shell 也能加载 .bashrc
[[ -f ~/.bashrc ]] && source ~/.bashrc
```

### `~/.bashrc`

```bash
# 非交互模式直接退出
[[ $- != *i* ]] && return

# alias、函数、prompt 等配置
alias ll='ls -alF'
PS1='\u@\h:\w\$ '
```

## FAQ

### Q: SSH 登录后 alias 不生效？

SSH 是 Login Shell，只读 `~/.bash_profile`，不读 `~/.bashrc`。

:::hint 解决方案
在 `~/.bash_profile` 中添加 `[[ -f ~/.bashrc ]] && source ~/.bashrc`。
:::

### Q: 环境变量应该放哪里？

- **环境变量**（如 `PATH`, `EDITOR`）→ `~/.bash_profile` 或 `~/.profile`
- **alias / 函数 / prompt** → `~/.bashrc`

### Q: 终端模拟器是 Non-login Shell，不读 `~/.bash_profile`，为什么还能访问环境变量？

因为**进程继承**。桌面环境登录时已经是一个 Login Session：

:::info 进程继承链
```
桌面环境启动 (Login Session)
    ↓ 读取 ~/.profile，设置 PATH
    ↓
桌面环境进程（GNOME Shell 等）
    ↓ 继承 PATH
    ↓
终端模拟器进程（GNOME Terminal 等）
    ↓ 继承 PATH
    ↓
Bash (Non-login Shell) → 继承 PATH，无需再读 ~/.bash_profile
```
:::

:::hint 修改环境变量后需重新登录
如果你在 `~/.bash_profile` 中**新增或修改**了环境变量，需要**重新登录桌面**（或手动 `source ~/.bash_profile`）才能生效。仅仅打开新终端窗口是**不够的**，因为终端模拟器继承的是桌面环境的旧环境变量。
:::

### Q: macOS Terminal 的行为？

:::info macOS 差异
macOS Terminal.app 默认每个窗口都是 **Login Shell**，所以会读 `~/.bash_profile` 而非 `~/.bashrc`（与 Linux 桌面终端行为不同）。
:::

### Q: 如何判断当前 shell 类型？

```bash
# Login shell 判断
shopt -q login_shell && echo "Login shell" || echo "Non-login shell"

# Interactive 判断
[[ $- == *i* ]] && echo "Interactive" || echo "Non-interactive"
```
