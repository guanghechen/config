# Wiki

个人 wiki 与 troubleshoot 知识库。agent 工作约定见 [AGENTS.md](AGENTS.md)。

> ⚠️ 本仓库开源。落盘任何内容前请脱敏,勿写入密钥、PII、内网地址等敏感信息。

## 目录与归档

```text
wiki/
├─ cs/                          计算机相关知识
│  ├─ lang/rust/syntax/         Rust 语法
│  ╰─ os/                       操作系统
│     ├─ nix/
│     ╰─ win/
├─ topic/rubiks-cube/5x5/       五阶魔方
│  ╰─ assets/                   配图
╰─ topics/app/canvas/           无限画布应用设计
   ├─ presentation/             演示设计专题
   ╰─ assets/                   配图
```

这里只维护关键目录概览，目录结构变化时同步更新。

- [无限画布应用：白板与知识整理的概念设计](topics/app/canvas/README.md)

FAQ 放在所属主题目录内，例如 `cs/os/win/faq.md`。配图放在条目所在目录的 `assets/` 中，使用相对链接引用。

问题排查记录归入 `troubleshoot/`（按需创建），文件名为 `YYYY-MM-DD-<slug>.md`。

## 记录格式

- Wiki 条目至少包含一级标题与 `tags`，沿用所在目录的 frontmatter 约定。
- Troubleshoot 记录包含 frontmatter：`title`、`date`、`tags`、`env`、`status`；正文说明症状与触发条件、排查证据、根因、处理方法和验证结果。
- 脱敏时用明确的占位符替换真实值，例如 `<API_KEY>`、`user@example.com`、`10.x.x.x`、`/path/to/project`。
