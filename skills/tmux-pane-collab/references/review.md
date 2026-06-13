# review flow（对抗式 code review）

在一个 primary agent 与一个 independent reviewer agent 之间跑一轮**对抗式**结构化 review。价值是逆住 LLM-to-LLM review 的两个默认失效：reviewer 倾向 rubber-stamp、primary 倾向 defend。用结构和 guardrail 强制 evidence-backed findings 与诚实收尾。

## 与协议的关系

review 不是独立通信格式，而是 `mode: review` 的 body 约定：默认每个产物 = 一条 pane-collab 消息，外层信封按 SKILL.md「消息格式」。

- 信封复用：review 目标写 `goal`，review 对象写 `topic`，轮次用 `turn`——这些**不在 body 重复**。
- body（`--------` 之后）只放协议没有的 review 专属字段，沿用小写 `key: value` + 空行分隔。
- review = `discuss` flow + 结构化 body，primary 为 `original`；turn / 退出 / 上限见「多轮契约」，寻址（to/from 互换）见「回写侧流程」，投递见「发送与确认」。
- transport：默认走 pane-collab（两个 agent pane）；无第二 pane 时 inline 跑——primary 生成 Packet 交用户转给 reviewer，等用户贴回 Findings，沿用同一套结构化产物。任何形态都不得用 primary 的 self-review 冒充 independent reviewer。
- roles：primary 持有改动并发起，reviewer 默认 read-only（不改文件 / 不 stage / 不 commit），除非用户明确要求 patch。

| 产物             | mode   | turn |
|------------------|--------|------|
| Review Packet    | review | 1    |
| Findings         | review | 1    |
| Resolution Notes | review | 2    |
| re-review        | review | 2    |
| Consensus label  | final  | 2    |

> 下表为**典型 2 轮**路径。Findings 明确 `no blocking findings` 时，primary 可在 turn 1 后直接收尾（`Consensus` 或 `Consensus with residual risks`），跳过 Resolution / re-review；有 Medium+ finding 则走 Resolution / re-review，未收敛项按 turn 循环，直到 `original` 判定收敛或 `turn` 达硬上限 `10`，能早收就早收。

## 何时用

- 有具体 review object（diff / patch / changed files / design doc / test artifact）时才跑。
- tiny local change 直接 self-check，别套 review loop。
- 没有具体 artifact 的开放讨论 / brainstorming 用 `mode: discuss`，不属于 `review`。

## 完整样例（turn 1 · Review Packet）

一条完整的 review 消息长这样；后面的 body 模板只给 `--------` 之后那段。

```text
[tmux-pane-collab] 请用 tmux-pane-collab skill 处理本消息，并按 mode/expect 约定处理。
to: %5
from: %3
original: %3
mode: review
turn: 1

topic: auth middleware patch
goal: 确认 patch 正确实现 session 校验且无 regression，达成 consensus 或收敛到 bounded risk
expect: 回 Findings（mode: review 同格式回写，保留 topic / goal / original / turn）

context: 重写 auth middleware，legal 要求改 session token 存储方式

--------

scope: correctness / security / regressions
changed files: src/auth/mw.ts（重写校验）, src/auth/store.ts（token 存储）
diff source: git diff main...HEAD
tests run: pnpm test auth — pass; e2e not run（无 staging）
known unverified: 并发刷新 token 路径未测
behavior changed: session 校验失败现返回 401（原 500）
```

## body 模板

`finding` id（如 `F-001`）在 Findings、Resolution、re-review 中保持不变。

### Review Packet（turn 1, primary → reviewer）

primary summary 不替代 diff/test evidence；diff 大时给 artifact link / file list / 最小 snippets，不粘 noisy scrollback。

```text
scope: <correctness / security / regressions / tests / API contract / maintainability 的重点>
changed files: <路径 + 一句作用>
diff source: <git diff / patch / explicit snippets / artifact path>
tests run: <command + pass/fail；没跑写 not run + 原因>
known unverified: <未验证路径 / 环境限制 / missing tests / assumptions>
behavior changed: <user-visible 或 API-visible 变化>
```

### Findings（turn 1 回写, reviewer → primary）

按 severity 排序，每条一个块、空行分隔；给不出 trigger+evidence 的降级成 residual risk。re-review 复用 `finding` id 并加 `status: confirmed-fixed | still-open | withdrawn | escalated`，不重新编号。

```text
finding: F-001
severity: Critical | High | Medium | Low
trigger: <触发问题的 condition 或 code path>
evidence: <file / function / line / diff hunk / command output / observable behavior>
impact: <什么坏、影响谁、为什么重要>
fix: <最窄的修复>
confidence: High | Medium | Low

no blocking findings: <仅当无 Critical/High/Medium 时>
residual risks: <未验证区 / missing tests / 低信心>
```

### Resolution Notes（turn 2, primary → reviewer）

逐条回应，每个 finding 只回一次；needs-discussion 只提一个 narrow question。

```text
finding: F-001
decision: accept | reject | needs-discussion
reason: <为什么这个 decision 对>
action: <patch / test / doc，或 none>
verification: <command/test/evidence，或 not run + 原因>
residual risk: <剩余风险，或 none>
```

### Consensus label（收尾 · mode: final）

由 primary（= `original`）在收到 re-review 后发：primary 判退出（退出判据见「多轮契约」），按 reviewer 给出的 finding severity 与 status **机械映射** label、无裁量，并整理交用户；reviewer 不切 `final`。

- `Consensus`：blocking findings 全 `confirmed-fixed` / `withdrawn`，验证已跑或有充分替代 evidence，且无 residual risk。
- `Consensus with residual risks`：blocking 全清，但留有未跑测试 / 低信心区 / 环境限制 / 未修的 Low finding。
- `No consensus / user decision needed`：有 blocking（Medium+）finding 仍 `still-open` / `escalated`，或硬上限 `10` 内仍无法用 evidence 收敛的 material risk。

## Guardrails

- reviewer 不许 rubber-stamp、不许提没有 trigger+evidence 的抽象 concern、不许绕过 `finding` id 直接改代码。
- primary 不许藏 unrun tests / known failures；有未解决 blocking（Medium+）finding 时不许称 `Consensus`，有未验证风险时只能用 `Consensus with residual risks`。
- 任一阶段缺 mandatory artifact：要求补齐或把终态降级，别拿 primary summary 当完整 evidence。
