# Session Navigation 最终设计

> 状态：Final
>
> 实现入口：`rust/ghc-tmux-status/src/session`、`runtime.rs`、`tmux.rs`

本文定义 session grouping、virtual order、focus、swap 与 last-session 行为。
Status rendering 和 commit contract 仍由 `statusline.md` 定义。

## 1. 目标与非目标

### 1.1 目标

- Statusline、numeric focus 与 prev/next focus 使用同一顺序。
- Session rename 不影响顺序。
- Stale persisted state 可自动降级并最终收敛。
- Session domain 保持 pure，不直接调用 tmux。
- Last-session jump 复用 tmux native per-client state。

### 1.2 非目标

- 不改变 session group membership。
- 不实现原生 `swap-session`；使用 virtual order 表达展示顺序。
- 不维护另一套 last-session stack。
- 不让 status widget 自己切换或重排 session。

## 2. Ownership

| State / behavior | Owner | Writer |
|---|---|---|
| group classification | `session::group` | pure derivation |
| virtual order | `@GHC_SL_SESSION_ORDER` | `session swap` command |
| focus target | `session::list` | pure derivation |
| client current session | tmux client | `switch-client` |
| client last session | tmux client | tmux native history |
| rendered item order/style | statusline renderer | guarded Rust commit |

模块职责：

| Module | Responsibility |
|---|---|
| `session::group` | session name -> group key |
| `session::list` | order normalization、focus 与 swap math |
| `session::item` | typed targets、directions 与 outcomes |
| `runtime` | tmux snapshot 与 side-effect orchestration |
| `tmux` | navigation snapshot、switch、order persistence |
| `widget::session_list` | 渲染已排序 group |
| keymaps/scripts | 暴露 focus、swap 与 native last-session actions |

## 3. Session grouping

Current session 决定唯一 visible group：

| Name pattern | Group |
|---|---|
| `_popup@*` | popup |
| `{claude\|codex\|gemini}-<hex>` | agent |
| `G<digits>-*` | matching numbered group |
| other | default |

Default group 排除 popup、agent 与所有 numbered-group sessions。Status rendering、focus、
swap 和 numeric index 必须共享同一个 group result。

## 4. Virtual order

### 4.1 Persistent contract

```text
@GHC_SL_SESSION_ORDER = $2\t$7\t$1...
```

只存 tmux session id，不存 name。ID 在 server 生命周期内稳定，因此 rename 不会改变
顺序。

### 4.2 Normalization

每次读取都重新归一化：

1. 解析 tab-separated ids。
2. 删除 stale ids。
3. 去重。
4. 保留仍存活 id 的相对顺序。
5. 将缺失的 live sessions 按 numeric session id 追加。

Order option 因此可以容忍 session close、new session 与旧格式残留，无需 migration。

### 4.3 Group-preserving swap

Swap 只交换当前 visible group 中两个 session 在 global order 的位置。其他 group 的 id
保持原来的相对 slot，不会因一次局部 swap 被整体搬移。

## 5. Focus contract

```text
ghc-tmux-status session focus <prev|next|index>
```

- `index`：visible ordered group 内的一基索引。
- `prev` / `next`：在当前 group 内 wrap。
- Target 不存在：显示 tmux message，不修改状态。
- Target 是 current session：idempotent no-op。
- Target 有效：通过 session id 执行 `tmux switch-client`。

`script/focus-session.sh` 优先调用 Rust。只有 release binary 缺失或不支持 session command
时才使用 shell fallback；fallback 不是 virtual-order owner。

## 6. Swap contract

```text
ghc-tmux-status session swap <prev|next>
```

- visible group 多于一个 session 时，prev/next 与 focus 一样 wrap；
- 只有一个 visible session 时返回 typed no-op，并显示边界 message；
- changed order 先写入 `@GHC_SL_SESSION_ORDER`；
- 写入成功后触发 `manual-apply` 刷新 statusline；
- persistence 失败时，旧 order 继续作为 source of truth。

Swap 只改变展示/导航顺序，不切换 current session。

## 7. Last session

tmux 持有 per-client `client_last_session`，Rust 只读取它。

Visual contract：

- last session 仅在当前 group 可见且非 active 时高亮；
- active style 优先；
- last session 位于其他 group 时不显示 marker；
- prefix `"` 与 platform keymap 使用 native `switch-client -l`。

### 7.1 Multi-client limitation

`client_last_session` 是 client-scoped，而 rendered status cache 是 session-scoped。两个
client 同时 attach 到同一 session 时，visual marker 可能由最后一次 reconcile 覆盖。
这是已接受的显示限制；native `switch-client -l` 仍对每个 client 保持正确。

## 8. Data flow

```text
tmux navigation snapshot
  -> classify group
  -> normalize virtual order
  -> derive focus/swap/render result
  -> optional tmux side effect
```

Render、focus 与 swap 必须调用同一 `ordered_group` path，禁止各自推导不同的 numeric order。

## 9. Failure contract

| Failure | Strategy | Result |
|---|---|---|
| stale/duplicate order ids | degrade | 忽略并归一化 |
| new session 不在 order | converge | 按 session id 追加 |
| current session 不可见 | no-op / abort boundary | 不产生错误切换 |
| focus target 不存在 | no-op | 显示 message |
| order persistence 失败 | abort mutation | 旧 order 保持有效 |
| Rust focus unavailable | fallback | shell 使用 tmux 当前顺序 |
| native last session 不存在 | native error | tmux 显示 message/error |

## 10. 不变量

- Rendered index 与 numeric focus index 完全一致。
- Reorder 不改变 group membership。
- Persisted order 只包含 session ids。
- Rename 不改变 order。
- Focus 不修改 order。
- Swap 修改 order，但不切换 session。
- Last-session state 由 tmux 持有，且独立于 virtual order。

## 11. 验证

必须覆盖：

- stale、duplicate、missing-new ids；
- index focus 与 wrapped prev/next；
- wrapped swap、single-session no-op；
- 其他 group interleaved slots 不变；
- render/focus/swap 共享 ordered group；
- last-session snapshot 与 visible/invisible marker；
- shell fallback 的 output/error isolation。
