# 敏感路径误操作检查

两道 `PreToolUse` hooks 减少直接操作敏感路径的失误。需要强制隔离时，应使用执行环境的文件权限或沙箱。

| 入口                     | 检查范围                                           |
| ------------------------ | -------------------------------------------------- |
| `pre-tool-use.mjs`       | `apply_patch` 的增删改，以及移动的源路径和目标路径 |
| `pre-bash-sensitive.mjs` | 单条简单命令中明确的文件输入                       |

## 保护范围

规则集中在 [util.mjs](../util.mjs)：规范化路径并解析现存符号链接，仅查询元数据。

- `.env`、`.env.*`，精确豁免 `.env.example`、`.env.sample`、`.env.template`。
- `auth.json`、`.git-credentials`、`*.http_request`、`*.http_response`。
- `.ssh` 及目录内容、`local/config.fish`、`local/config.ps1`、`local/env.*`。

模板位于敏感目录或链接到敏感文件时仍会被拦截。

## Bash 的有限范围

只检查一条简单命令，支持字面量引号、转义、注释、`~/` 和以下输入：

| 命令或语法 | 检查对象 |
| ---------- | -------- |
| `cat`、`head`、`tail` | 文件参数；支持常见无值选项和 `head/tail` 的 `-n/--lines`、`-c/--bytes` |
| `<`、`<>`、`<&` | 输入文件，排除文件描述符复制 |
| `curl -T/--upload-file` | 上传文件 |
| `curl -d/--data/--data-binary @文件` | 从文件读取的正文 |
| `curl file://…` | 本地文件 URL，包括 `localhost` 和 `127.0.0.1` |

带值的短选项采用 `-n 10` 或 `-n10`，不解析 `-qn10` 这类组合。未知选项会跳过该命令的参数检查；明确的输入重定向仍会检查。完整的选项表在 [bash-policy.mjs](bash-policy.mjs)。

遇到命令链、管道、多条命令、heredoc、here-string、通配符或动态展开时，整段 Bash 输入跳过。不剥离环境变量赋值前缀或 wrapper，不展开嵌套 shell，不模拟 `cd`，也不解析搜索、归档、编辑器等其他命令的参数。这些情况允许继续执行，不代表已确认安全。

普通复制、写入和清理由执行环境权限控制。`apply_patch` 拒绝敏感路径的增删改是独立规则，Bash 不提供同等的写入限制。

CLI `0.161.0` 实测只传入会话 `cwd`，省略 `exec_command.workdir`，因此相对路径判断仍可能与实际工作目录不同。两道 hooks 也不覆盖悬空链接、硬链接、检查后文件变化及 MCP 等其他工具；`write_stdin` 不会再次触发检查。

## 测试与维护

在 Codex 配置目录运行：

```sh
node --test script/hook/sensitive.spec.mjs script/cli/sync.spec.mjs
```

测试使用虚构文件，不执行命令字符串。配置源为 `config.shared.toml`，通过 `script/cli/sync.mjs` 同步；定义变化后用 `/hooks` 检查信任，保留本机信任记录。

暂不迁移原生权限配置：2026-10-08 在 Linux / CLI `0.161.0` 中验证，通配 `deny` 仍放过新建文件，模板 `write` 豁免还会导致沙箱启动失败。

参考：[Hooks 文档](https://learn.chatgpt.com/docs/hooks) · [权限文档](https://learn.chatgpt.com/docs/permissions)
