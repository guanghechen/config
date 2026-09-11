# 输入法切换

`era.dressing.im` 管理编辑器生命周期，`yoz.im` 提供面向 input source 的 Lua contract，独立 crate `rust/im` 负责访问各平台的 input source。

## 职责边界

- `rust/im` 负责 opaque source ID、English source 判定、精确恢复、WSL process supervision，以及 Windows bridge source。
- `yoz.im` 仅暴露 `capture()`、`capture_and_select_english()`、`restore()`、`is_english()`，以及仅 WSL 可用的 `setup()`。
- `era.dressing.im` 仅暴露 `dressing()`，持有 Insert snapshot、editor focus state，以及最近一次成功的 English 对齐是否仍可用于跳过恢复。
- `Non-English` 仅表示 `not is_english(snapshot)`，不是可选择的目标。恢复非 English source 时，必须使用此前捕获的精确 source ID。

## 状态模型

```text
InsertLeave               -> capture source, select English
InsertEnter               -> restore last Insert snapshot
Focus entry + command     -> select English
Focus entry + Insert      -> restore last Insert snapshot
Focus exit                -> no backend call
```

`auto_im` 控制全部 input source 操作。Insert 事件独立触发，不以 focus state 为前置条件；
未收到 focus event 的 headless host，以及收到 `FocusLost` 后的 mode 切换，均按相同规则处理。
初始状态为 unfocused，headless 初始化本身不操作 source；mode 事件不改变 focus state。
focus state 仅用于 focus event 去重、取消延迟的 UI reconciliation，以及设置变更时的立即协调。
source 操作遵守下述失败冷却策略，不启动后台重试。

## 生命周期

- `dressing()` 由 vendor composition root 同步注册，确保 focus handler 先于 `UIEnter` 就绪；如有 plugin setup，IM 先于其注册：
  - Neovim/Neovide 调用 `era.dressing.setup({ "notifier", "ui_attach", "im" })`，`im` 在 `ui_attach` 之后注册；
  - VSCode/Yuivim 调用 `era.dressing.setup({ "im" })`，不启用 `ui_attach` dressing；
  - Yozvim 不启用 `im` 或 `ui_attach` dressing，input source 由宿主管理。
- `UIEnter` 仅在存在 attached UI 时同步记录 focused 状态，将首次 source reconciliation 延至下一 event-loop tick，避免 backend I/O 阻塞 UI startup。失焦会推进 focus generation，使尚未执行的 reconciliation 失效；重复 focus event 不会产生额外调用。
- 显式 `FocusGained` 幂等地记录 focused 状态，不要求 attached UI，并同步按当前 mode 对齐：
  - command mode 调用一次 fused `capture_and_select_english()`；
  - Insert/Replace mode 精确恢复已知 Insert snapshot，包括 English snapshot；
  - 其他 mode 不处理。
- `VimResume` 仅在存在 attached UI 时复用上述获取焦点流程；headless 的 `VimResume` 不主动协调，后续 Insert 或显式 focus event 各自触发。
- `FocusLost`、`VimSuspend`、`VimLeavePre`，以及最后一个 UI 的 `UILeave`，清除 focus 状态并取消待执行的 focus 协调，不调用 backend。即使未收到过 focus entry，也会使 English restore 快捷缓存失效。仍有其他 UI 时，`UILeave` 不清除 focus 状态。
- 启用 `auto_im` 时，`InsertLeave` 正常调用一次 `capture_and_select_english()`；仅 English selection 冷却时改用一次只读 `capture()`。只要成功捕获 snapshot，就将其保存为新的 Insert snapshot，即使后续选择 English source 失败。
- 启用 `auto_im` 时，`InsertEnter` 同步调用 backend 恢复精确 Insert snapshot，不在 Lua 中延迟执行。只有最近的 English 对齐或 English restore 成功、之后未发生使 source 不确定的操作或失焦，且 snapshot 为 English 时才跳过恢复。`can_skip_english_restore` 仅表示该快捷路径仍可使用，不代表 OS IME 已完成切换；只读 capture 不建立该条件。
- 关闭 `auto_im` 会清除 Insert snapshot，但不改变 focus 状态。重新开启时：
  - focused：立即按当前 mode 对齐；
  - unfocused：等待下一次 Insert 或 focus entry 事件。
- UI host 可传递 focus event 以支持焦点切换时的额外协调：terminal Neovim 接收 native/tmux event，VSCode/Yuivim 的 embedded host 可转发对应 event；未转发不影响 Insert 事件。重复或重叠 event 安全，因为 focus 状态转换是幂等的。

## Backend 契约

- `capture()` 返回 `(snapshot, error)`，不修改 input source。
- `capture_and_select_english()` 返回 `(snapshot, ok, error)`：
  - 捕获失败：`(nil, false, error)`，不再尝试选择；
  - 无需选择或平台接受选择请求：`(snapshot, true, nil)`；
  - 捕获成功但选择失败：`(snapshot, false, error)`。
- `restore(snapshot)` 请求选择 snapshot 对应的精确 source ID。
- macOS 的成功返回不是完成 acknowledgement：source 查询可能暂时滞后，也不据此保证 OS IME 已能处理后续首字。backend 当前不等待 selection 的可观测完成。
- `is_english(snapshot)` 仅用于判定；不存在 `InputMethod` enum 或 semantic non-English setter。

## 平台映射

### macOS

- snapshot 是精确的 Text Input Source Services ID。
- ASCII-capable source 视为 English。
- 选择 English 时使用系统当前的 ASCII-capable keyboard input source，不硬编码 source ID。
- 查询前处理已到达的 CFRunLoop 通知，每次最多执行 32 轮零等待处理；预算耗尽或 RunLoop 被中止时返回 capture failure，避免阻塞 Neovim 或将未完成的刷新视作成功。该过程不等待未来通知或 IME readiness。
- backend 保留最近一次成功提交的 source ID，直到下一次成功提交替换它。相同 ID 的查询结果可能早于队列中的请求生效，不能作为 acknowledgement 清除此记录。
- `restore()` 刷新 current source，只有当前 ID 与目标一致、且最近提交的 target 不冲突时才跳过系统 selection。刷新失败时仍尝试原有的精确恢复路径。
- fused capture 即使读到 English source，最近提交的另一个 source 仍可能随后生效；此时继续提交 English request。selection 失败不覆盖最近成功提交的 target。
- 外部变化可能已让当前 source 符合目标，但最近提交的 target 仍冲突；此时保守地再提交一次，不根据一次匹配查询推断队列已完成。

### 原生 Windows

- snapshot 是完整的十进制 HKL。
- primary language 为 English 的标准 LANGID 均视为 English。
- 选择 English 时使用 Windows 返回的第一个已加载 English HKL。
- HKL classification 只描述 keyboard-layout language，不包含 IME 内部 conversion state。

### WSL

- snapshot 同样是完整的十进制 HKL；Linux backend 不截断为 16-bit LANGID。
- helper protocol：
  - 无参数：查询当前 HKL；
  - `--english`：捕获当前 HKL，并选择一个已加载的 English HKL；
  - 十进制 HKL：精确恢复对应 source。
- no-allocator bridge 最多接受 64 个已加载 layout；超过上限时明确失败。
- `--english` 在请求选择前先输出原始 HKL。因此，即使选择阶段失败或超时，Linux backend 仍能保留 snapshot。
- command-mode focus entry 或 `InsertLeave` 正常只启动一个 fused helper process；English selection 冷却期间可启动一个 query-only helper，以保留准确 snapshot。
- focus exit 不启动 helper process。
- `InsertEnter` 在 snapshot 为 non-English、或 English reconciliation 未确认时启动一个 restore process；Insert/Replace mode 的 focus entry 会精确恢复任意已知 snapshot。
- helper 使用有界的 `SendMessageTimeoutW`，并以 10ms 间隔轮询捕获的 foreground thread，最长 100ms。Linux parent 会 kill 并 reap 超过 1s deadline 的 helper。
- 仅在检测到 WSL 时导出 helper-backed capability；普通 Linux 不提供 IM backend。

## 失败策略

- Native 和 WSL backend 返回 value 与 error；`era.dressing.im` 是 lifecycle failure 的唯一 reporter。
- 一次 fused operation 最多生成一条 report；捕获失败后不再启动 selection process。
- selection failure 保留已捕获的 snapshot，以便下一次 `InsertEnter` 精确恢复 editing source。
- `InsertLeave` 查询失败或因 capture 冷却跳过查询时，会清除 Insert restore target，避免恢复本轮 Insert 期间可能已改变的旧 source。仅 selection 冷却时仍查询当前 source，不丢弃健康查询得到的 snapshot。
- selection 或 restoration failure 不得用猜测值覆盖已有 snapshot。
- Lua 分别管理 capture、English selection 与 restore 的失败冷却。Native backend 固定冷却 1 秒，避免恢复延迟随失败次数增长；WSL helper 存在 1 秒 process deadline，连续失败按 1、2、4、8 秒退避，上限 8 秒。使用 monotonic clock，从 backend 返回后开始计时；report 附带 `retry_after_ms`。
- fused operation 根据 snapshot 是否存在区分 capture failure 与 selection failure。仅 selection 冷却时继续调用只读 `capture()`；该查询也失败后进入 capture 冷却，暂停 query 和 fused operation。
- 被冷却跳过的操作不重复 report；到期后由下一次 eligible lifecycle event 尝试，不使用 timer 自动重试。focus 往返不重置冷却。
- 操作成功只清除自身冷却：健康的只读 capture 不提前重试 English selection。修改 `auto_im` 清除三侧冷却；restore target 变化也会清除 restore 冷却，旧 source 的失败不阻塞新 source。
- selection failure 返回的 snapshot 仍可在下一次 `InsertEnter` 恢复：三侧冷却彼此独立。restore 被冷却跳过时保留 snapshot。
- 同步调用避免在 Lua 中排入跨越后续 mode 或 focus transition 的 deferred restore；macOS 平台仍可能异步应用或呈现选择请求。
