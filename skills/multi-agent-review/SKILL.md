---
name: multi-agent-review
description: 用于在 tmux panes、TUI sessions 或 inline handoffs 中协调 primary agent 和 reviewer agent 进行结构化 code review、讨论 review comments、处理 findings，并达成 consensus。Use when the user asks one agent to ask another agent to review work, resolve findings, or reach consensus between agents. For lightweight agent messaging without the review-loop structure, use tmux-pane-collab.
argument-hint: "[pane-ref | review scope]"
---

# Multi-Agent Review

在一个 primary agent 与一个 independent reviewer agent 之间跑一轮**对抗式**结构化 review。它的价值不是「传消息」（那是 `tmux-pane-collab` 的事），而是逆住 LLM-to-LLM review 的两个默认失效：reviewer 倾向 rubber-stamp、primary 倾向 defend。用结构和 guardrail 强制 evidence-backed findings 与诚实收尾。

## 何时用

- 有具体 review object（diff / patch / changed files / design doc / test artifact）时才跑。
- tiny local change 直接 self-check，别套 review loop。
- 没有具体 artifact 的开放讨论 / brainstorming 不属于本 skill。

## 流程

1. 定 roles 与 transport。Reviewer 默认 read-only（不改文件、不 stage、不 commit），除非用户明确要求 patch。
2. Primary 发 **Review Packet**：goal、scope、changed files、diff source、tests run（没跑写 "not run" + 原因）、known unverified areas。Primary summary 不能替代 diff/test evidence。
3. Reviewer 回 **Findings**：按 severity 排序，每条带 stable `Finding ID`、trigger、evidence、impact、suggested fix、confidence；无 blocking finding 就明说并列 residual risks。
4. Primary 回 **Resolution Notes**：逐条按 `Finding ID` 标 `accept | reject | needs-discussion`；accept 要 action + verification，reject 要 code/test evidence 或 invariant。
5. 至多再 re-review 一轮，只针对 changed/disputed item，复用原 `Finding ID`。
6. 收尾必须落一个 label：
   - `Consensus`：blocking findings 全关，且验证已跑或有充分替代 evidence。
   - `Consensus with residual risks`：无 blocking，但有未跑测试 / 低信心区 / 环境限制。
   - `No consensus / user decision needed`：两轮内无法用 evidence 收敛的 material risk。

格式见下方 **Templates**。

## Templates

三个产物的格式。`Finding ID`（如 `F-001`）在 Findings、Resolution Notes 与 re-review 中保持不变。

### Review Packet（primary → reviewer）

mandatory artifacts 与 optional context 分开；primary summary 不替代 evidence。diff 大时给 artifact link / file list / 最小 snippets，不粘 noisy scrollback。

```text
Review Request
Goal: <要解决什么 / 应实现什么 behavior>
Scope: <correctness / security / regressions / tests / API contract / maintainability 的重点>
Changed files: <路径 + 一句作用>
Diff source: <git diff / patch / explicit snippets / artifact path>
Tests run: <command + pass/fail；没跑写 "not run" + 原因>
Known unverified: <未验证路径 / 环境限制 / missing tests / assumptions>
Behavior changed: <user-visible 或 API-visible 变化>
```

### Findings（reviewer → primary）

evidence-backed，按 severity 排序；给不出 trigger+evidence 的降级成 residual risk。re-review 复用原 `Finding ID`，status 更新为 `confirmed-fixed | still-open | withdrawn | escalated`，不重新编号。

```text
Finding ID: F-001
Severity: Critical | High | Medium | Low
Trigger: <触发问题的 condition 或 code path>
Evidence: <file / function / line / diff hunk / command output / observable behavior>
Impact: <什么坏、影响谁、为什么重要>
Suggested fix: <最窄的修复>
Confidence: High | Medium | Low

No blocking findings: <仅当无 Critical/High/Medium 时>
Residual risks: <未验证区 / missing tests / 低信心>
```

### Resolution Notes（primary → reviewer）

逐条回应，每个 finding 只回一次；needs-discussion 只提一个 narrow question。

```text
Finding ID: F-001
Decision: accept | reject | needs-discussion
Reason: <为什么这个 decision 对>
Action: <patch / test / doc，或 "none">
Verification: <command/test/evidence，或 "not run" + 原因>
Residual risk: <剩余风险，或 "none">
```

## Guardrails

- Reviewer 不许 rubber-stamp、不许提没有 trigger+evidence 的抽象 concern、不许绕过 `Finding ID` 直接改代码。
- Primary 不许藏 unrun tests / known failures；有未解决 high-severity finding 时不许称 `Consensus`，有未验证风险时只能用 `Consensus with residual risks`。
- 任一阶段缺 mandatory artifact：要求补齐或把终态降级，别拿 primary summary 当完整 evidence。

## Transport

- **tmux**：用 `tmux-pane-collab` 投递。整轮 review = 一条 `discuss` thread，primary 为 `original`，`goal` = 达成 consensus 或收敛到 bounded risk，`cap=2`，每条 message 用对应 template。pane 定位、send-confirm、turn/cap/exit、liveness 全归该 skill，本 skill 不重复 tmux 机械。
- **inline**：primary 生成 Packet 交用户转给 reviewer，等用户贴回 Findings；别拿 primary 的 self-review 冒充 independent reviewer。
