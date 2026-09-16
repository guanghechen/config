---
title: Bash 运行模式与启动排查
tags: [shell, bash]
updated: 2026-09-16
---

# Bash 运行模式与启动排查

Bash 的启动行为取决于两个独立维度：**Login / Non-login** 与 **Interactive / Non-interactive**。Profile 的选择顺序、环境变量配置和启动流程见 [Shell Profile 与 Bash 启动文件](profile.md)。

## 判断当前模式

- **Login**：通过 `--login` / `-l` 启动，或启动时的 `argv[0]` 以 `-` 开头。
- **Interactive**：通过 `-i` 指定，或满足 Bash 对终端输入、错误输出和启动参数的交互式判定；`$-` 包含 `i`。

```bash
shopt -q login_shell && printf 'Login\n' || printf 'Non-login\n'

case $- in
  *i*) printf 'Interactive\n' ;;
  *)   printf 'Non-interactive\n' ;;
esac
```

常见的显式启动方式：

- `bash --login -i`：交互式 login shell。
- `bash -i`：交互式 non-login shell。
- `bash --login script.sh`：非交互式 login shell。
- `bash script.sh`：非交互式 non-login shell。

终端模拟器、SSH、tmux 的名称不足以确定 shell 模式；实际行为取决于启动命令、会话设置和所用 shell。排查时以上面的检测结果为准。

## `.bashrc` 中的交互配置

Alias、prompt、补全和历史设置通常放在 `~/.bashrc`。仅用于交互的配置可以放在以下判断之后：

```bash
case $- in
  *i*) ;;
  *) return ;;
esac

alias ll='ls -alF'
PS1='\u@\h:\w\$ '
```

Alias 不会通过进程环境传给新 shell。Bash 函数默认也不导出，但可通过 `export -f` 传给子 Bash；交互配置通常仍由各自的 `.bashrc` 初始化。

## 常见排查

### SSH 登录后 alias 不生效

先确认当前 shell 是 Bash，再判断是否为交互式 login shell。若是，检查实际选中的用户 profile 是否显式加载 `.bashrc`，以及 `.bashrc` 是否在定义 alias 之前提前返回。配置示例见 [profile 与 bashrc 的衔接](profile.md#推荐的配置分工)。

### 修改 profile 后，新终端仍拿到旧环境变量

新进程继承父进程已导出的环境变量。修改配置文件不会反向更新现有桌面会话、终端进程或 tmux server 的环境；新 shell 若没有读取该文件，也不会自动得到修改。

应确认变量由哪个进程、哪个文件初始化，再重新启动对应会话，或在需要生效的 shell 中明确加载配置。不能假定所有桌面环境都会读取 `~/.profile`。

### `--noprofile --norc` 是否跳过了所有初始化

这两个选项分别跳过 login profile 和 `.bashrc`，不会清空继承的环境，也不负责禁用普通非交互式 Bash 的 `BASH_ENV`。启动一个跳过这些用户启动文件的交互式 Bash，可使用：

```bash
env -u BASH_ENV bash --noprofile --norc -i
```

## 参考

- [GNU Bash Manual — Invoking Bash](https://www.gnu.org/software/bash/manual/html_node/Invoking-Bash.html)
- [GNU Bash Manual — Bash Startup Files](https://www.gnu.org/software/bash/manual/html_node/Bash-Startup-Files.html)
