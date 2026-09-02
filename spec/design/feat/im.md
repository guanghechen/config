# 输入法切换

`era.m.im` 管理 editor lifecycle，`yoz.im` 提供面向 input source 的 Lua contract，独立 crate `rust/im` 负责访问各平台的 input source。

## 职责边界

- `rust/im` 负责 opaque source ID、English source 判定、精确恢复、WSL process supervision，以及 Windows bridge source。
- `yoz.im` 仅暴露 `capture()`、`capture_and_select_english()`、`restore()`、`is_english()`，以及仅 WSL 可用的 `setup()`。
- `era.m.im` 仅暴露 `dressing()`，并持有一个 Insert snapshot 和 editor focus state。
- `Non-English` 仅表示 `not is_english(snapshot)`，不是可选择的目标。恢复非 English source 时，必须使用此前捕获的精确 source ID。

## 状态模型

```text
Focused + command mode    -> English source
Focused + Insert/Replace  -> last Insert snapshot
Unfocused                 -> 不管理 input source
```

Neovim 只在 focused 时管理 input source；unfocused 后不读取或修改目标应用的 input source。

## 生命周期

- `dressing()` 在 `era.m.ui_attach.dressing()` 之后、plugin setup 之前同步注册，确保 focus handler 先于 `UIEnter` 就绪，且不依赖 plugin。
- `UIEnter` 同步获取 ownership，但将首次 source reconciliation 延至下一 event-loop tick，避免 backend I/O 阻塞 UI startup。失焦会推进 focus generation，使尚未执行的 reconciliation 失效；重复 focus event 不会产生额外调用。
- `FocusGained` 和 `VimResume` 幂等地获取 ownership，并同步按当前 mode 对齐：
  - command mode 调用一次 fused `capture_and_select_english()`；
  - Insert/Replace mode 精确恢复已知 Insert snapshot，包括 English snapshot；
  - 其他 mode 不处理。
- `FocusLost`、`VimSuspend`、`VimLeavePre`，以及最后一个 UI 的 `UILeave`，只释放 ownership，不调用 backend。仍有其他 UI 时，`UILeave` 不释放 ownership。
- focused 状态下的 `InsertLeave` 调用一次 `capture_and_select_english()`。只要成功捕获 snapshot，就将其保存为新的 Insert snapshot，即使后续选择 English source 失败。
- focused 状态下的 `InsertEnter` 同步恢复精确 Insert snapshot，确保 Neovim 接受后续 Insert-mode input 前完成切换。已知 snapshot 为 English 时跳过恢复，因为 `InsertLeave` 已将 source 保持为 English。
- 关闭 `auto_im` 会清除 Insert snapshot，但不改变 focus ownership。重新开启时：
  - focused：立即按当前 mode 对齐；
  - unfocused：等待下一次 focus entry。
- tmux 负责传递 focus event。native event 与 tmux event 即使重叠也安全，因为 ownership transition 是幂等的。

## Backend 契约

- `capture()` 返回 `(snapshot, error)`，不修改 input source。
- `capture_and_select_english()` 返回 `(snapshot, ready, error)`：
  - 捕获失败：`(nil, false, error)`，不再尝试选择；
  - 已是 English 或选择成功：`(snapshot, true, nil)`；
  - 捕获成功但选择失败：`(snapshot, false, error)`。
- `restore(snapshot)` 选择 snapshot 对应的精确 source ID。
- `is_english(snapshot)` 仅用于判定；不存在 `InputMethod` enum 或 semantic non-English setter。

## 平台映射

### macOS

- snapshot 是精确的 Text Input Source Services ID。
- ASCII-capable source 视为 English。
- 选择 English 时使用系统当前的 ASCII-capable keyboard input source，不硬编码 source ID。

### Native Windows

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
- command-mode focus entry 或 `InsertLeave` 只启动一个 fused helper process。
- focus exit 不启动 helper process。
- focused `InsertEnter` 仅在已知 snapshot 为 non-English 时启动一个 restore process；Insert/Replace mode 的 focus entry 会精确恢复任意已知 snapshot。
- helper 使用有界的 `SendMessageTimeoutW`，并以 10ms 间隔轮询捕获的 foreground thread，最长 100ms。Linux parent 会 kill 并 reap 超过 1s deadline 的 helper。
- 仅在检测到 WSL 时导出 helper-backed capability；普通 Linux 不提供 IM backend。

## 失败策略

- Native 和 WSL backend 返回 value 与 error；`era.m.im` 是 lifecycle failure 的唯一 reporter。
- 一次 fused operation 最多生成一条 report；捕获失败后不再启动 selection process。
- selection failure 保留已捕获的 snapshot，以便下一次 focused `InsertEnter` 精确恢复 editing source。
- `InsertLeave` 捕获失败会清除 Insert restore target。
- selection 或 restoration failure 不得用猜测值覆盖已有 snapshot。
- 同步恢复消除了可能跨越后续 mode 或 focus transition 的 deferred restore。macOS platform boundary 仍可能异步呈现已完成的 source selection。
