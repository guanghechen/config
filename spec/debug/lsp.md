# Neovim LSP Diagnostics Collector

在 headless 模式下运行 Neovim，自动收集整个项目的 LSP diagnostics，输出结构化结果供外部工具（如 Claude Code）解析和自动修复。

> **推荐**: 使用 tmux pane 运行 headless Neovim，可以实时观察 LSP 分析进度。详见 `spec/debug/tmux.md`。

## Usage

```bash
nvim --headless -c "luafile ~/.config/nvim/init-lsp-check.lua"

# 带参数
nvim --headless \
  -c "lua TARGET_DIR='~/my-project'" \
  -c "lua OUTPUT_FILE='/tmp/my-diagnostics.json'" \
  -c "luafile ~/.config/nvim/init-lsp-check.lua"
```

---

## Design Goals

| 目标         | 说明                                                                   |
| ------------ | ---------------------------------------------------------------------- |
| 复用现有配置 | 确保全局变量、LSP 设置、插件等正确加载，避免 `undefined global` 等误报 |
| 智能等待 LSP | 不使用硬编码延时，通过多重信号判断 LSP 分析是否完成                    |
| 结构化输出   | JSON 格式便于程序解析，同时输出人类可读格式到 stdout                   |
| 可配置性     | 目标目录、输出路径、文件过滤规则均可配置                               |

---

## Configuration

### Type Definition

```lua
---@class LspCollectorConfig
---@field target_dir string 要扫描的目录
---@field output_file string JSON 输出路径
---@field file_patterns string[] 要扫描的文件 glob 模式
---@field exclude_patterns string[] 要排除的路径模式（Lua pattern）
---@field timeout_ms number 最大等待时间（毫秒）
---@field poll_interval_ms number 轮询间隔（毫秒）
---@field stable_count_required number 连续多少次"稳定"才认为完成
---@field min_wait_after_open_ms number 打开所有文件后的最小等待时间
---@field min_analysis_time_ms number LSP 分析最小等待时间（毫秒）

---@class LspCollectorState
---@field config LspCollectorConfig
---@field start_time number vim.uv.now() 返回的时间戳
---@field stable_count number LSP idle 时的连续稳定计数
---@field busy_stable_count number LSP busy 时的连续稳定计数
---@field last_diagnostic_count number 上一次轮询的诊断数量
---@field opened_files string[] 成功打开的文件列表
---@field failed_files string[] 打开失败的文件列表

---@class FormattedDiagnostic
---@field file string 文件绝对路径
---@field lnum number 行号（1-based）
---@field col number 列号（1-based）
---@field end_lnum number|nil 结束行号（1-based）
---@field end_col number|nil 结束列号（1-based）
---@field severity string "ERROR" | "WARN" | "INFO" | "HINT"
---@field message string 诊断消息
---@field source string|nil 诊断来源（如 "Lua Diagnostics."）
---@field code string|number|nil 诊断代码（如 "undefined-global"）
```

### Default Values

| 配置项                    | 默认值                                     | 说明                               |
| ------------------------- | ------------------------------------------ | ---------------------------------- |
| `target_dir`              | `vim.fn.getcwd()`                          | 当前工作目录                       |
| `output_file`             | `/tmp/nvim-diagnostics.json`               | JSON 输出路径                      |
| `file_patterns`           | `{ "**/*.lua" }`                           | 扫描所有 Lua 文件                  |
| `exclude_patterns`        | `{ "/lazy/", "/pack/", "%.spec%.lua$" }`   | 排除插件目录和测试文件             |
| `timeout_ms`              | `600000` (10 分钟)                         | 最大等待时间                       |
| `poll_interval_ms`        | `15000` (15 秒)                            | 轮询检查间隔                       |
| `stable_count_required`   | `3`                                        | 连续稳定次数阈值                   |
| `min_wait_after_open_ms`  | `3000` (3 秒)                              | 打开文件后的最小等待时间           |
| `min_analysis_time_ms`    | `120000` (2 分钟)                          | LSP 分析的最小等待时间             |

---

## Output Format

### JSON

```json
{
  "meta": {
    "target_dir": "/home/user/.config/nvim",
    "total_files": 42,
    "failed_files": [],
    "total_diagnostics": 5,
    "elapsed_ms": 165000,
    "timestamp": "2024-01-15T10:30:00Z"
  },
  "diagnostics": [
    {
      "file": "/home/user/.config/nvim/lua/config/lsp.lua",
      "lnum": 25,
      "col": 10,
      "end_lnum": 25,
      "end_col": 15,
      "severity": "ERROR",
      "message": "Undefined global `vim`.",
      "source": "Lua Diagnostics.",
      "code": "undefined-global"
    }
  ]
}
```

### Stdout (Human Readable)

```
[init-lsp-check] Target: /home/user/.config/nvim
[init-lsp-check] Output: /tmp/nvim-diagnostics.json
[init-lsp-check] Found 457 files (skipped 5)
[init-lsp-check] Opened 457/457 files
[init-lsp-check] [15s] Waiting for LSP to attach... (attached=100/457, expected=457)
[init-lsp-check] [30s] LSP busy (attached=457/457), diagnostics=0
[init-lsp-check] [120s] LSP busy (attached=457/457), diagnostics=5
[init-lsp-check] [135s] LSP idle (attached=457/457), diagnostics=5, stable=1/3
[init-lsp-check] [150s] LSP idle (attached=457/457), diagnostics=5, stable=2/3
[init-lsp-check] [165s] LSP idle (attached=457/457), diagnostics=5, stable=3/3
[init-lsp-check] LSP analysis complete!

=== Found 5 diagnostics ===
/home/user/.config/nvim/lua/config/lsp.lua:25:10: [ERROR] Undefined global `vim`.
...

JSON output: /tmp/nvim-diagnostics.json
```

---

## LSP Completion Detection Strategy

多重信号综合判断：

### 1. Client Requests 检查

- 遍历所有 LSP clients
- 检查 `client.requests` 是否为空
- 有 pending request → **busy**

### 2. `vim.lsp.status()` 检查 (Neovim 0.10+)

- 返回空字符串 → **idle**
- 返回非空（如 `"Indexing..."`）→ **busy**

### 3. Diagnostics 数量稳定性检查

- 记录上一次的诊断数量
- 必须等待 `min_analysis_time_ms` 后才开始计数
- 连续 N 次数量不变 + LSP idle → **完成**
- 连续 3N 次数量不变 + LSP busy → **完成**（fallback，某些 LSP 可能持续报告 busy）
- 防止 LSP 分阶段报告导致的"假完成"

### 4. 超时兜底

- 超过最大等待时间后强制收集当前结果
- 输出警告信息

### Flow Chart

```
                        ┌─────────────┐
                        │  开始轮询   │
                        └──────┬──────┘
                               ▼
                      ┌────────────────┐
                      │  检查是否超时  │
                      └────────┬───────┘
               ┌───────────────┴───────────────┐
               ▼                               ▼
        ┌─────────────┐               ┌────────────────┐
        │ Yes: 超时   │               │ No: 继续检查   │
        └──────┬──────┘               └────────┬───────┘
               ▼                               ▼
     ┌──────────────────┐            ┌──────────────────┐
     │ 输出警告并收集   │            │  检查 LSP 状态   │
     │ 当前结果后退出   │            │ client.requests  │
     └──────────────────┘            │ vim.lsp.status() │
                                     └────────┬─────────┘
                                              ▼
                                   ┌─────────────────────┐
                                   │ 已过 min_analysis   │
                                   │ _time_ms?           │
                                   └──────────┬──────────┘
                                   ┌──────────┴──────────┐
                                   ▼                     ▼
                          ┌──────────────┐      ┌──────────────┐
                          │ No: 继续轮询 │      │ Yes: 检查    │
                          │ 重置计数     │      │ 稳定性       │
                          └──────────────┘      └──────┬───────┘
                                                       ▼
                                            ┌────────────────────┐
                                            │  诊断数量变化？    │
                                            └─────────┬──────────┘
                                         ┌────────────┴────────────┐
                                         ▼                         ▼
                                ┌──────────────┐          ┌──────────────┐
                                │ Yes: 变化    │          │ No: 稳定     │
                                │ 重置所有计数 │          └──────┬───────┘
                                └──────────────┘                 ▼
                                                      ┌────────────────────┐
                                                      │  LSP busy?         │
                                                      └─────────┬──────────┘
                                                   ┌────────────┴────────────┐
                                                   ▼                         ▼
                                          ┌──────────────┐          ┌──────────────┐
                                          │ Yes: busy    │          │ No: idle     │
                                          │ busy_cnt++   │          │ stable_cnt++ │
                                          └──────┬───────┘          └──────┬───────┘
                                                 ▼                         ▼
                                      ┌─────────────────────┐   ┌─────────────────────┐
                                      │ busy_cnt >= 3N?     │   │ stable_cnt >= N?    │
                                      └──────────┬──────────┘   └──────────┬──────────┘
                                           ┌─────┴─────┐             ┌─────┴─────┐
                                           ▼           ▼             ▼           ▼
                                     ┌────────┐  ┌────────┐    ┌────────┐  ┌────────┐
                                     │ No:    │  │ Yes:   │    │ No:    │  │ Yes:   │
                                     │ 继续   │  │ 完成！ │    │ 继续   │  │ 完成！ │
                                     │ 轮询   │  │ 收集   │    │ 轮询   │  │ 收集   │
                                     └────────┘  └────────┘    └────────┘  └────────┘
```

---

## Key Implementation Notes

### Headless Output

- `print()` 在 headless 模式下无效
- 必须使用 `io.stdout:write()` + `io.stdout:flush()`

### File Opening

- 使用 `vim.cmd.edit(vim.fn.fnameescape(filepath))` 安全打开文件
- 处理包含空格和特殊字符的路径

### Diagnostics Collection

- `vim.diagnostic.get(nil)` 获取**所有** buffer 的诊断（传 `nil` 而非不传参数）
- 诊断位置需要从 0-based 转换为 1-based

### LSP Attach Detection

- 等待至少 90% 的 buffer 都 attach LSP client 后才开始稳定性判断
- 使用 `vim.lsp.get_clients({ bufnr = bufnr })` 检查 attach 状态

---

## Error Handling

| 场景               | 检测方式                                   | 处理策略                                   |
| ------------------ | ------------------------------------------ | ------------------------------------------ |
| LSP 未启动         | `vim.lsp.get_clients()` 返回空             | 等待一段时间后重试，最终超时报错           |
| 文件打开失败       | `safe_edit()` 返回 `false`                 | 记录到 `failed_files`，继续处理其他文件    |
| JSON 编码失败      | `pcall(vim.fn.json_encode)` 返回 `false`   | 降级为纯文本输出，使用 `cq!` 非零退出      |
| 输出文件写入失败   | `vim.fn.writefile` 返回 `-1`               | 输出错误信息到 stdout，仍输出人类可读格式  |

---

## Integration with Claude Code

### Workflow

```
┌─────────────────────────────────────────────────────┐
│  1. Claude Code 运行 headless nvim 收集诊断         │
│  2. 读取 /tmp/nvim-diagnostics.json                 │
│  3. 解析并逐个修复 diagnostics                      │
│  4. 重新运行诊断，验证修复                          │
│  5. 循环直到 diagnostics 为空                       │
└─────────────────────────────────────────────────────┘
```

### Agent Wait Time Guidelines

**重要**: 当 Agent 调用 `init-lsp-check.lua` 后，需要等待 LSP 分析完成。以下是建议的等待策略：

| 配置项                      | 默认值       | Agent 建议等待时间        |
| --------------------------- | ------------ | ------------------------- |
| `min_analysis_time_ms`      | 2 分钟       | **至少 2.5 分钟**         |
| `poll_interval_ms`          | 15 秒        | 每次轮询检查              |
| `stable_count_required`     | 3 次         | 额外 45 秒稳定性确认      |
| `timeout_ms`                | 10 分钟      | 最大等待不超过 10 分钟    |

**典型等待时间计算**:
- 最小等待: `min_analysis_time_ms` + `stable_count_required * poll_interval_ms`
- 实际值: 120s + 3 × 15s = **165 秒 (约 2.75 分钟)**
- **Agent 建议**: 等待 **3 分钟** 后再读取结果，确保 LSP 分析已完全稳定

**Agent 实现建议**:
```bash
# 启动 headless nvim (在 tmux pane 中运行)
nvim --headless \
  -c "lua TARGET_DIR='$TARGET_DIR'" \
  -c "luafile ~/.config/nvim/init-lsp-check.lua"

# 等待至少 3 分钟让 LSP 完成分析
sleep 180

# 读取结果
cat /tmp/nvim-diagnostics.json
```

---

## Future Improvements (Out of Scope)

- **增量检查**: 只检查 `git diff` 中变更的文件
- **多语言支持**: 自动检测项目语言，配置对应的 `file_patterns`
- **并行打开文件**: 使用 `vim.schedule_wrap` 批量打开
- **实时输出**: 支持进度条显示
- **CI 集成**: 输出 GitHub Actions 格式的 annotations，支持 exit code
