# nvim-lint Buffer Ownership Design

## 1. Status

- Date: 2026-08-20
- State: finalized
- Scope: lint scheduling and target-buffer ownership in `lua/era/plugin/nvim-lint.lua`
- Dependencies: no new third-party dependency
- Implementation status: complete
- Review outcome: approved in one deep-review round with no findings

## 2. Objective

Every lint request must remain owned by the buffer that triggered it until the request is either executed or discarded.

Success requires all of the following:

1. Requests for different buffers inside one debounce window are all retained.
2. Repeated requests for the same buffer are coalesced into one execution.
3. `lint.try_lint()` observes the requested buffer as the current buffer.
4. The user's current buffer and window are restored after lint dispatch.
5. Invalid or unloaded buffers are skipped without loading them again.
6. Lazy plugin setup schedules the initial buffer exactly once.
7. Reconfiguration disposes the old timer and observable subscription.
8. One buffer-specific dispatch failure does not prevent other pending buffers from running.

## 3. Non-goals

- Do not change `linters_by_ft`, exclusion rules, linter conditions, or cspell arguments.
- Do not change formatter behavior or LSP diagnostics.
- Do not change linter process concurrency or introduce a process queue without profiling evidence.
- Do not change linter `cwd` semantics in this fix.
- Do not add a generic keyed scheduler abstraction for one caller.
- Do not modify upstream `nvim-lint`.

## 4. Validity Audit

### 4.1 Upstream contract is current-buffer based

The installed `nvim-lint` revision is `a219b2c9e5b4765e5c845aba119dad55806fcaf1`.

Its `try_lint()` and `lint()` implementations both call `nvim_get_current_buf()`. The selected buffer determines:

- running-process ownership;
- filename arguments;
- stdin content;
- diagnostic publication target.

The upstream API has no `bufnr` option. A caller that schedules work asynchronously must restore the requested buffer context before calling `try_lint()`.

### 4.2 Native autocmd context does not survive debounce

During a native hidden-buffer `BufReadPost`, Neovim temporarily exposes the event buffer as current. After the callback returns, it restores the previous current buffer.

The existing callback records the temporary current buffer as an argument to a 128 ms debounce. When the timer fires, `do_lint(bufnr)` resolves configuration using the saved buffer, but `lint.try_lint()` independently reads the then-current buffer.

Observed reproduction:

```text
event target: init.lua buffer 2
current after BufReadPost: README.md buffer 1
try_lint current buffer: README.md buffer 1
```

Therefore the issue is valid even without synthetic autocmd execution.

### 4.3 Shared debounce drops independent buffer requests

The existing module owns one `lint_debounced` timer. Each call replaces the stored argument in `stl.timer.debounce()`.

Observed reproduction with two hidden buffer loads inside one debounce window:

```text
pending events: README.md buffer 2, init.lua buffer 3
executions: one
selected linter set: lua-marker
try_lint current buffer: lazy-lock.json buffer 1
```

The Markdown request was lost, and the surviving Lua request executed against the JSON buffer.

This is not an intentional current-buffer optimization:

- the autocmd is global and subscribes to every `BufReadPost` / `BufWritePost`;
- `do_lint()` accepts an explicit `bufnr`;
- manual refresh publishers send a specific `bufnr` through `lint_schedule_nr`.

### 4.4 Manual refresh already carries ownership, but the observer drops it

`era.m.lint` publishes the affected buffer through:

```lua
dot.state.status.lint_schedule_nr:next(bufnr)
```

The plugin consumes it through `stl.fn.observe()`. That helper intentionally discards observable values and schedules a zero-argument callback, so the plugin falls back to `nvim_get_current_buf()`.

The manual refresh path therefore has the same ownership bug after a buffer switch.

### 4.5 Initial lint is currently accidental

`stl.fn.observe()` delivers the observable's initial value unless `ignore_initial` is set. The callback ignores that value and schedules the current buffer. This compensates for the lazy loader installing the plugin's own `BufReadPost` autocmd after the triggering event has already started.

The replacement must preserve initial lint explicitly rather than relying on an unrelated observable's initial notification.

## 5. Candidate Designs

### 5.1 Keep one debounce and the latest buffer

Rejected. This preserves current behavior but violates independent buffer ownership and loses write/read events.

### 5.2 One debounce timer per buffer

Valid but not recommended.

- Advantage: independent debounce deadlines.
- Cost: timer map, per-buffer cleanup, reconfiguration cleanup, and more libuv handles.
- Result: a multi-buffer load burst can still launch all linters concurrently when the timers expire.

The additional lifecycle state does not solve a measured requirement that the simpler batching design cannot satisfy.

### 5.3 One debounce plus a pending-buffer set

Recommended.

- One timer owns the debounce window.
- `pending_bufnrs[bufnr] = true` retains every distinct buffer and deduplicates repeated events.
- Flush swaps the pending table before dispatch, so new events belong to the next window.
- Each dispatch runs inside `nvim_buf_call(bufnr, ...)`.

This copies the established pending-set pattern from `era.m.lsp.diagnostic` without extracting a new abstraction.

A headless prototype produced exactly two executions for three requests (`markdown`, duplicate `markdown`, `lua`), used the correct target buffer inside each execution, and restored the original JSON buffer afterwards.

## 6. Final Contract

### 6.1 State ownership

`lua/era/plugin/nvim-lint.lua` owns:

```lua
local pending_bufnrs = {} ---@type table<integer, true>
local lint_debounced = nil ---@type stl.timer.IDisposableCallable|nil
local lint_schedule_subscription = nil ---@type stl.c.IUnsubscribable|nil
```

- `pending_bufnrs` is the single source of truth for scheduled work.
- `schedule_lint()` is the only writer that adds work.
- `flush_pending_lints()` atomically swaps the table and becomes the owner of that batch.
- Setup owns and replaces the timer and subscription.

### 6.2 Scheduling

```lua
local function schedule_lint(bufnr)
  if type(bufnr) ~= "number" or bufnr < 1 then
    return
  end
  pending_bufnrs[bufnr] = true
  lint_debounced()
end
```

Autocmd callbacks must use `event.buf`:

```lua
callback = function(event)
  schedule_lint(event.buf)
end
```

The manual refresh channel must subscribe directly so the emitted `bufnr` is preserved:

```lua
lint_schedule_subscription = dot.state.status.lint_schedule_nr:subscribe(
  stl.c.Subscriber.new({
    on_next = function(bufnr)
      schedule_lint(bufnr)
    end,
  }),
  true
)
```

`ignore_initial = true` is required. Setup then calls `schedule_lint(nvim_get_current_buf())` once explicitly.

### 6.3 Batch dispatch

```lua
local function flush_pending_lints()
  local bufnrs = pending_bufnrs
  pending_bufnrs = {}

  for bufnr in pairs(bufnrs) do
    local ok, err = pcall(do_lint, bufnr)
    if not ok then
      stl.reporter.error({
        from = __module_name__,
        subject = "lint buffer",
        message = "Failed to lint buffer.",
        details = { bufnr = bufnr, error = err },
      })
    end
  end
end
```

Per-buffer failure isolation is required because batching otherwise creates a new failure coupling where one bad buffer prevents unrelated buffers from dispatching.

### 6.4 Target context

`do_lint(bufnr)` must reject invalid or unloaded buffers before entering the buffer context:

```lua
if not vim.api.nvim_buf_is_valid(bufnr) or not vim.api.nvim_buf_is_loaded(bufnr) then
  return
end
```

The existing eligibility, filepath, linter resolution, and `try_lint()` flow then runs inside:

```lua
vim.api.nvim_buf_call(bufnr, function()
  -- Existing do_lint body.
end)
```

`nvim_buf_call()` temporarily makes the target buffer current and restores the previous buffer/window. A local verification confirmed that it did not emit `BufEnter`, `BufLeave`, `WinEnter`, or `WinLeave` in this use case.

### 6.5 Reconfiguration lifecycle

Before creating new state, setup must:

1. dispose the previous debounce timer;
2. unsubscribe the previous observable subscription;
3. replace `pending_bufnrs` with an empty table.

The existing augroup helpers already clear and replace autocmds.

No per-buffer timer cleanup autocmd is required: pending integers live for at most one debounce window, and invalid/unloaded buffers are rejected at dispatch.

## 7. Failure Semantics

- Invalid or unloaded target: skip silently.
- Unsupported or excluded buffer: preserve existing silent skip behavior.
- Missing configured linter: preserve the existing warning and continue with remaining linters.
- Per-buffer Lua failure: report with `bufnr`, continue the batch.
- Upstream process failure: preserve `nvim-lint` notification and cancellation behavior.
- Buffer deleted after process start: preserve upstream behavior; diagnostics are not published to an invalid buffer.

## 8. Test Matrix

Add `__test__/specs/era/plugin/nvim-lint_spec.lua` using the existing harness and an isolated plugin spec load.

Required cases:

1. Two different buffer requests in one window both execute.
2. Repeated requests for one buffer execute once.
3. `try_lint()` sees the requested buffer as current and the original current buffer is restored.
4. Autocmd callbacks forward `event.buf`.
5. Manual `lint_schedule_nr` notification forwards its emitted buffer.
6. Initial setup schedules the current buffer exactly once.
7. Invalid and unloaded buffers are skipped without `nvim_buf_call()`.
8. Reconfiguration disposes the old timer and unsubscribes the old observer.
9. A failure in one pending buffer does not suppress another buffer.

Validation commands after implementation:

```sh
nvim -l __test__/run.lua __test__/specs/era/plugin/nvim-lint_spec.lua
nvim -l __test__/run.lua
```

## 9. Expected Changeset

- Modify `lua/era/plugin/nvim-lint.lua`.
- Add `__test__/specs/era/plugin/nvim-lint_spec.lua`.
- Update this design with implementation and validation results.

No other runtime module or interface contract should change.

## 10. Resolved Decisions

| Question | Decision | Rationale |
| --- | --- | --- |
| Is the intended target the current buffer or triggering buffer? | Triggering buffer | Existing APIs and publishers already carry `bufnr`. |
| How are repeated events coalesced? | One pending-set entry per buffer | Preserves all buffers without per-buffer timers. |
| How is upstream current-buffer API adapted? | `nvim_buf_call()` | Official Neovim buffer-context boundary; no upstream patch. |
| Are unloaded buffers linted? | No | Avoids reopening hidden state and unexpected work. |
| Is initial lint driven by observable initial delivery? | No | Explicit scheduling makes the contract visible. |
| Is process concurrency changed? | No | No profiling evidence justifies a queue or limiter. |

## 11. Implementation Results

Implemented files:

- `lua/era/plugin/nvim-lint.lua`
- `__test__/specs/era/plugin/nvim-lint_spec.lua`

The implementation follows the final contract:

- one debounced pending-buffer set retains distinct buffers and deduplicates repeated requests;
- autocmds forward `event.buf`;
- the manual observable subscription preserves the emitted `bufnr`;
- `do_lint()` rejects invalid or unloaded buffers and executes inside `nvim_buf_call()`;
- setup replaces the owned timer and subscription and explicitly schedules the initial buffer;
- batch dispatch reports a per-buffer Lua failure and continues with the remaining buffers.

Validation results:

```text
nvim -l __test__/run.lua __test__/specs/era/plugin/nvim-lint_spec.lua
6 passed, 0 failed

nvim -l __test__/run.lua
108 suites, 0 failed
```

Additional integration verification loaded Markdown and Lua buffers while a JSON buffer remained current. Both target
buffers were dispatched exactly once, `try_lint()` observed the correct target in each call, and the JSON buffer was
restored as current afterwards.

Formatting and whitespace validation:

```text
stylua --syntax LuaJIT --check lua/era/plugin/nvim-lint.lua __test__/specs/era/plugin/nvim-lint_spec.lua
passed

git diff --check
passed
```

## 12. Pane `%33` E2E Cost Profile

Environment:

- Neovim 0.12.4
- cspell 10.0.1 from Mason
- isolated XDG state and cache
- three timing runs per scenario; values below are medians
- real process cases use the same eight Lua/Markdown files for each run

### 12.1 Scheduler-only cost

`lint.try_lint()` was replaced with an in-process recorder so this measures buffer loading, debounce, target-context
switching, and dispatch without linter process work.

| Distinct buffers | Buffer load | Completion from first load | Dispatch span |
| ---: | ---: | ---: | ---: |
| 1 | 26.9 ms | 135.3 ms | n/a |
| 4 | 62.8 ms | 189.9 ms | 0.145 ms |
| 8 | 96.5 ms | 223.0 ms | 0.362 ms |

The pending-set iteration and `nvim_buf_call()` boundary are not a meaningful CPU cost: eight dispatches complete in
less than 0.5 ms. Most measured time is buffer loading plus the configured 128 ms debounce window.

### 12.2 Real cspell process cost

| Distinct buffers | cspell processes | Internal completion | Shell wall time | User CPU | Sampled child RSS aggregate peak |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 1 | 739 ms | 1.82 s | 1.87 s | 242 MiB |
| 4 | 4 | 846 ms | 1.94 s | 4.87 s | 913 MiB |
| 8 | 8 | 1238 ms | 2.34 s | 10.11 s | 1569 MiB |

The RSS value sums process RSS and therefore double-counts shared pages, but it accurately demonstrates that every
distinct buffer creates another large Node/cspell process during the overlapping execution window.

Compared with one buffer, eight distinct buffers add approximately:

- 499 ms to internal completion latency;
- 0.52 s to shell wall time;
- 8.24 s of user CPU;
- more than 1 GiB of aggregate child RSS in the sampled window.

### 12.3 Same-buffer burst

Eight rapid events for one buffer started exactly one cspell process. Median wall time was 1.83 s and median user CPU
was 1.81 s, effectively the same as the single-event baseline. The pending set correctly deduplicates high-frequency
events for one buffer.

### 12.4 Updated conclusion

The implementation's Lua scheduling cost is negligible. The material cost is unbounded process fan-out across distinct
buffers, especially during bulk hidden-buffer loading.

The previous decision to leave process concurrency unchanged was superseded by this evidence. At that review checkpoint,
a product-level scheduling policy still had to be selected:

1. **Active/visible gating (recommended):** passive read/load events lint only displayed buffers; hidden buffers lint when
   they become visible. Explicit write and manual requests retain their target buffer.
2. **Execute every loaded buffer:** retain the current implementation and accept CPU/RSS fan-out.
3. **Bounded process queue:** preserve all requests with a concurrency limit, but requires a reliable completion contract
   around upstream `nvim-lint` and materially increases scheduler complexity.

Recommendation: revise passive event semantics to active/visible gating. It retains correct target ownership for work the
user can observe, avoids hidden-buffer load bursts, and does not introduce a custom process lifecycle layer.

## 13. Active/Visible Gating Revision

Selected policy:

- `BufReadPost` and `BufNewFile` are passive requests.
- Passive requests execute immediately only when the buffer is displayed in a real window.
- Neovim's temporary `autocmd` window does not count as visible.
- Hidden passive requests remain deferred until a real `BufWinEnter`.
- `BufWritePost`, `InsertLeave`, and manual observable requests remain explicit and retain their target buffer even when
  hidden.
- `BufDelete` removes pending and deferred state.

The implementation keeps a separate `deferred_bufnrs` set. `BufWinEnter` consumes an entry only after rechecking actual
visibility; this second check is required because hidden `bufload()` also creates an autocmd window and emits
`BufWinEnter` for it.

Pane `%33` E2E verification with eight hidden buffers produced:

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

Interpretation:

- bulk hidden-buffer loading started no cspell process;
- displaying one deferred buffer started exactly one process;
- an explicit write request for another hidden buffer started exactly one additional process;
- both processes completed successfully.

This removes the measured bulk-load fan-out without reverting target-buffer correctness.
