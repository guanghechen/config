# nvim-lint 的 Buffer 归属与调度

本文定义 `lua/era/plugin/nvim-lint.lua` 的最终调度契约，已包含 active/visible gating。
实现已完成，不引入第三方依赖。设计与历史验证记录始于 2026-08-20。

## 目标与边界

Lint request 从触发到执行或丢弃，始终归属于触发它的 buffer：

- 同一 debounce window 保留不同 buffer 的请求，同一 buffer 的重复请求合并。
- `lint.try_lint()` 必须在目标 buffer context 中执行，结束后恢复用户原来的 buffer/window。
- 不重新加载无效或 unloaded buffer。
- 隐藏 buffer 的被动加载延迟到真实可见时处理；显式请求即使目标隐藏也保留。
- Lazy setup 显式安排一次初始请求；重新配置释放旧 timer、subscription 与待处理状态。
- 单个 buffer 的 dispatch 失败不阻止同批其他 buffer。

本设计不调整 `linters_by_ft`、排除规则、linter condition、cspell 参数、linter `cwd`、formatter
或 LSP diagnostics，也不修改上游 `nvim-lint`。Process concurrency 不由本地队列限制；
减少隐藏 buffer 的被动请求，以控制批量加载的进程开销。

## 事件策略

| 入口                           | 请求类型      | 行为                                                     |
| ------------------------------ | ------------- | -------------------------------------------------------- |
| `BufReadPost` / `BufNewFile`   | 被动          | 真实可见时进入 pending，否则进入 deferred                |
| Setup 当前 buffer              | 被动          | 显式安排一次，使用同一可见性规则                         |
| `BufWinEnter`                  | Deferred 激活 | 再次确认真实可见后，将已有 deferred request 转为 pending |
| `BufWritePost` / `InsertLeave` | 显式          | 按 `event.buf` 调度，包括隐藏 buffer                     |
| `lint_schedule_nr`             | 显式          | 保留 observable 发出的 `bufnr`                           |
| `BufDelete`                    | 清理          | 移除该 buffer 的 pending 与 deferred 状态                |

“可见”指 buffer 显示在真实 window 中，Neovim 的临时 `autocmd` window 不计入。
隐藏 `bufload()` 也会产生 `BufWinEnter`，因此消费 deferred request 时必须再次检查。
进入 pending 后仍经过 128 ms debounce，不是立即启动 linter。

## 状态与批处理

模块持有四项状态：

| 状态                         | 用途                                     |
| ---------------------------- | ---------------------------------------- |
| `pending_bufnrs`             | 等待本轮 debounce dispatch 的 buffer set |
| `deferred_bufnrs`            | 等待真实可见的被动请求                   |
| `lint_debounced`             | 唯一 debounce timer                      |
| `lint_schedule_subscription` | 手动刷新 subscription                    |

`schedule_lint(bufnr)` 校验正数 buffer ID 与 timer，移除该 buffer 的 deferred 标记，
设置 `pending_bufnrs[bufnr] = true`，再触发 debounce。该函数是 pending 新增项的唯一入口。

`flush_pending_lints()` 先用空表替换 `pending_bufnrs`，再遍历取出的 batch；
执行期间的新请求进入下一轮。每个 `do_lint(bufnr)` 单独由 `pcall` 保护，
失败通过 `stl.reporter.error` 报告 `bufnr` 与原始 error，随后继续处理其他目标。

Autocmd 使用 `event.buf`。手动刷新直接订阅 `dot.state.status.lint_schedule_nr`，
设置 `ignore_initial = true`；不使用会丢弃 observable value 的 `stl.fn.observe()`。
Setup 最后显式调度当前 buffer 的被动请求，避免依赖 observable 的初始通知。

## 目标 context 与资源生命周期

`do_lint(bufnr)` 先拒绝 invalid/unloaded buffer，再通过 `nvim_buf_call()` 执行原有准入、
路径、linter 解析与 `try_lint()` 流程：

```lua
vim.api.nvim_buf_call(bufnr, function()
  -- Existing do_lint body.
end)
```

该边界临时将目标设为 current buffer，返回时恢复原 buffer/window。
历史验证中，此用法没有触发 `BufEnter`、`BufLeave`、`WinEnter` 或 `WinLeave`。

重新 setup 的顺序：

1. Dispose 旧 debounce timer。
2. Unsubscribe 旧 observable subscription。
3. 清空 pending 与 deferred sets。
4. 创建新 timer/subscription，通过已有 augroup helper 替换 autocmds。
5. 显式安排一次初始被动请求。

不创建 per-buffer timer；buffer 删除由 `BufDelete` 清理，dispatch 再检查有效性。

## 失败语义

| 条件                                             | 行为                                               |
| ------------------------------------------------ | -------------------------------------------------- |
| Invalid/unloaded、unsupported 或 excluded buffer | 静默跳过                                           |
| 配置的 linter 不存在                             | 保留原 warning，继续其余 linters                   |
| 单个 buffer 的 Lua dispatch 失败                 | 报告 `bufnr` 与 error，继续 batch                  |
| 上游进程失败                                     | 保留 `nvim-lint` 的通知与取消行为                  |
| Process 启动后 buffer 被删除                     | 沿用上游行为，不向 invalid buffer 发布 diagnostics |

## 验证要求

`__test__/specs/era/plugin/nvim-lint_spec.lua` 使用现有 harness 与隔离的 plugin spec load，覆盖：

- 不同 buffer 请求均保留，同 buffer 请求去重。
- `try_lint()` 看到正确 target，dispatch 后恢复原 current buffer。
- Autocmd 与手动 observable 保留触发 `bufnr`。
- Setup 只安排一次初始请求；重新配置释放旧 timer/subscription。
- Invalid/unloaded buffer 在进入 `nvim_buf_call()` 前跳过。
- 单 buffer 失败不影响同批其他 buffer。
- 隐藏被动请求不启动进程；真实可见后执行；隐藏目标的显式请求仍执行。

```sh
nvim -l __test__/run.lua __test__/specs/era/plugin/nvim-lint_spec.lua
nvim -l __test__/run.lua
```

## 决策依据

### Buffer 归属问题

历史审计使用上游 revision `a219b2c9e5b4765e5c845aba119dad55806fcaf1`。
`try_lint()` 与 `lint()` 都通过 `nvim_get_current_buf()` 决定 process owner、filename、stdin
与 diagnostics target，API 没有 `bufnr` 参数。

原实现将 buffer ID 传入共享 debounce，但只用它解析配置；延迟执行的 `try_lint()` 读取另一个
current buffer。原生隐藏 buffer `BufReadPost` 即可触发：

```text
event target: init.lua buffer 2
current after BufReadPost: README.md buffer 1
try_lint current buffer: README.md buffer 1
```

同一 debounce window 内加载两个隐藏 buffer 时，共享 timer 还会覆盖前一次参数：

```text
pending events: README.md buffer 2, init.lua buffer 3
executions: one
selected linter set: lua-marker
try_lint current buffer: lazy-lock.json buffer 1
```

Markdown 请求丢失，Lua 请求则错误地作用于 JSON buffer。手动刷新虽然发送了 `bufnr`，
但 `stl.fn.observe()` 丢弃该值，因此 buffer 切换后同样失去归属。

采用 pending set 保留不同 buffer，并用 `nvim_buf_call()` 适配上游 API。
Per-buffer timer 虽能独立 debounce，但增加 handle 和清理状态，也无法减少同时启动的 linter processes。
该选择复用 `era.m.lsp.diagnostic` 的 pending-set 模式，不提取通用 scheduler。

### 历史功能验证

首轮实现通过一次 deep review，无 findings。当时记录：目标 spec 为 `6 passed, 0 failed`，
全量为 `108 suites, 0 failed`，StyLua 与 `git diff --check` 通过。这些记录只说明当时的实现状态。

额外 integration 验证保持 JSON buffer 为 current，加载 Markdown 与 Lua targets：
两个目标各执行一次，`try_lint()` context 正确，最后恢复 JSON buffer。

### Process 成本与 gating 选择

历史 E2E 环境为 Neovim 0.12.4、Mason cspell 10.0.1，使用隔离的 XDG state/cache。
每个场景执行三次并取中位数；真实进程场景使用相同的八个 Lua/Markdown 文件。

将 `try_lint()` 替换为进程内 recorder 后，调度成本如下：

| 不同 buffer 数 | 加载耗时 | 从首次加载到完成 | Dispatch span |
| -------------: | -------: | ---------------: | ------------: |
|              1 |  26.9 ms |         135.3 ms |           n/a |
|              4 |  62.8 ms |         189.9 ms |      0.145 ms |
|              8 |  96.5 ms |         223.0 ms |      0.362 ms |

八次 dispatch 少于 0.5 ms，主要等待来自 buffer 加载与 128 ms debounce。
未引入 gating 时，真实 cspell 成本如下：

| 不同 buffer 数 | cspell processes | 内部完成时间 | Shell wall time | User CPU | 子进程 RSS 合计采样峰值 |
| -------------: | ---------------: | -----------: | --------------: | -------: | ----------------------: |
|              1 |                1 |       739 ms |          1.82 s |   1.87 s |                 242 MiB |
|              4 |                4 |       846 ms |          1.94 s |   4.87 s |                 913 MiB |
|              8 |                8 |      1238 ms |          2.34 s |  10.11 s |                1569 MiB |

RSS 合计会重复计算共享页，但能反映进程重叠带来的开销。相较一个 buffer，八个 buffer 增加
约 499 ms 内部延迟、0.52 s wall time、8.24 s user CPU 和超过 1 GiB 的 RSS 合计峰值。
同一 buffer 的八次快速事件只启动一个进程，wall time 为 1.83 s、user CPU 为 1.81 s，接近单事件基线。

据此选择 active/visible gating：避免隐藏 buffer 批量加载触发大量进程，同时保留显式请求的目标归属。
不选择“执行全部 loaded buffers”，也不引入需要上游可靠 completion contract 的 bounded process queue。

Gating 后在 pane `%33` 记录的八个隐藏 buffer E2E 结果：

```json
{
  "hidden_count": 8,
  "hidden_started": 0,
  "visible_started": 1,
  "total_started": 2,
  "total_finished": 2,
  "visible_completed": true,
  "explicit_completed": true
}
```

批量隐藏加载没有启动 cspell；显示一个 deferred buffer 后启动一个，另一个隐藏 buffer 的显式写入
再启动一个，两者均完成。这验证了 gating 对批量加载开销的控制，以及显式请求的 buffer 归属。
