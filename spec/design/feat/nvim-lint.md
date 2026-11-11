# nvim-lint 的 Buffer 归属与调度

本文定义 `lua/era/plugin/nvim-lint.lua` 的调度契约，包含 active/visible gating。

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
| `BufWritePost`                 | 显式          | 按 `event.buf` 调度，包括隐藏 buffer                     |
| `InsertLeave`                  | 显式          | `changedtick` 自上次 lint 未变时跳过，否则同上           |
| `lint_schedule_nr`             | 显式          | 保留 observable 发出的 `bufnr`                           |
| `BufDelete`                    | 清理          | 移除该 buffer 的 pending、deferred 与 `linted_ticks`     |

“可见”指 buffer 显示在真实 window 中，Neovim 的临时 `autocmd` window 不计入。
隐藏 `bufload()` 也会产生 `BufWinEnter`，因此消费 deferred request 时必须再次检查。
进入 pending 后仍经过 128 ms debounce，不是立即启动 linter。

## 状态与批处理

模块持有五项状态：

| 状态                         | 用途                                     |
| ---------------------------- | ---------------------------------------- |
| `pending_bufnrs`             | 等待本轮 debounce dispatch 的 buffer set |
| `deferred_bufnrs`            | 等待真实可见的被动请求                   |
| `linted_ticks`               | 各 buffer 上次 lint 的 `changedtick`     |
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

`do_lint(bufnr)` 先拒绝 invalid/unloaded buffer，再通过 `nvim_buf_call()` 执行准入、
路径、linter 解析与 `try_lint()` 流程。

该边界临时将目标设为 current buffer，返回时恢复原 buffer/window。
此用法不触发 `BufEnter`、`BufLeave`、`WinEnter` 或 `WinLeave`。

重新 setup 的顺序：

1. Dispose 旧 debounce timer。
2. Unsubscribe 旧 observable subscription。
3. 清空 pending 与 deferred sets 及 `linted_ticks`。
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

## 决策依据

### Buffer 归属问题

`try_lint()` 与 `lint()` 都通过 `nvim_get_current_buf()` 决定 process owner、filename、stdin
与 diagnostics target，API 没有 `bufnr` 参数。

若只把 buffer ID 传入共享 debounce 并只用它解析配置，延迟执行的 `try_lint()` 会读取另一个 current buffer；
同一 debounce window 内加载多个 buffer 时，共享 timer 还会覆盖前一次参数，请求丢失或作用于错误的 buffer。
手动刷新虽然发送了 `bufnr`，但 `stl.fn.observe()` 丢弃该值，因此 buffer 切换后同样失去归属。

采用 pending set 保留不同 buffer，并用 `nvim_buf_call()` 适配上游 API。
Per-buffer timer 虽能独立 debounce，但增加 handle 和清理状态，也无法减少同时启动的 linter processes。
该选择复用 `era.m.lsp.diagnostic` 的 pending-set 模式，不提取通用 scheduler。

### Process 成本与 gating 选择

Dispatch 本身的开销可以忽略，主要等待来自 buffer 加载与 128 ms debounce；成本来自 linter processes。
同一 buffer 的快速重复事件只启动一个进程；不同 buffer 各启动一个，延迟、CPU 与内存随重叠的进程数增长。

据此选择 active/visible gating：避免隐藏 buffer 批量加载触发大量进程，同时保留显式请求的目标归属。
不选择“执行全部 loaded buffers”，也不引入需要上游可靠 completion contract 的 bounded process queue。
