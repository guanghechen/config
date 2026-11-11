# Neovim LSP Diagnostics Collector

在 headless 模式下运行 Neovim，自动收集整个项目的 LSP diagnostics，输出结构化结果供外部工具（如 Claude Code）解析和自动修复。

> **基线检查**: 仓库的 LuaLS 零 Warning/Error 基线使用 `node script/luals-check.mjs`（固定 LuaLS 版本、只检查
> tracked 与未忽略的 Lua 文件）。本 collector 复现交互式编辑器会话，适合排查编辑器内的 diagnostics。

## Usage

> **重要**: `OUTPUT_FILE` 是必填参数，未指定时脚本会报错退出。
>
> 推荐输出路径: `local/debug/lsp/{YYYYMMDD-HHmmss}.json`（相对于 nvim config 目录）

### 全量扫描

```bash
# 基本用法（在 nvim config 目录下运行）
nvim --headless \
  -c "lua OUTPUT_FILE='local/debug/lsp/$(date +%Y%m%d-%H%M%S).json'" \
  -c "luafile ./init-debug-lsp.lua"

# 指定目标目录
nvim --headless \
  -c "lua TARGET_DIR='~/my-project'" \
  -c "lua OUTPUT_FILE='local/debug/lsp/$(date +%Y%m%d-%H%M%S).json'" \
  -c "luafile ./init-debug-lsp.lua"
```

### 指定文件扫描（快速模式）

当已知需要检查的文件列表时，使用 `FILE_PATHS` 参数可以跳过全量扫描，大幅提升分析速度：

```bash
# 指定单个文件
nvim --headless \
  -c "lua FILE_PATHS={'lua/era/m/nvimbar/nvimbar.lua'}" \
  -c "lua OUTPUT_FILE='local/debug/lsp/$(date +%Y%m%d-%H%M%S).json'" \
  -c "luafile ./init-debug-lsp.lua"

# 指定多个文件
nvim --headless \
  -c "lua FILE_PATHS={'lua/era/m/nvimbar/nvimbar.lua', 'lua/era/dressing/statusline.lua'}" \
  -c "lua OUTPUT_FILE='local/debug/lsp/$(date +%Y%m%d-%H%M%S).json'" \
  -c "luafile ./init-debug-lsp.lua"
```

快速模式只打开 `FILE_PATHS` 中可读的文件（不可读的输出 `WARN` 后跳过），不应用 `FILE_PATTERNS` 与
`EXCLUDE_PATTERNS`，并将 `min_analysis_time_ms` 缩短为 45 秒。

> **Agent 工作流建议**:
>
> 1. 首次运行：全量扫描收集所有 diagnostics
> 2. 修复问题后：仅对修改过的文件进行快速检查（使用 `FILE_PATHS`）
> 3. 确认无新问题后：最后再全量扫描一次确保完整性

---

## Configuration

在 `luafile` 之前用 `-c "lua NAME=value"` 设置以下全局变量：

| 全局变量           | 默认值                                   | 说明                                                     |
| ------------------ | ---------------------------------------- | -------------------------------------------------------- |
| `TARGET_DIR`       | `vim.fn.getcwd()`                        | 要扫描的目录                                             |
| `OUTPUT_FILE`      | **必填**                                 | JSON 输出路径，未指定时报错退出                          |
| `FILE_PATHS`       | `nil`                                    | 指定文件列表，优先于 `FILE_PATTERNS`                     |
| `FILE_PATTERNS`    | `{ "**/*.lua" }`                         | 要扫描的文件 glob 模式                                   |
| `EXCLUDE_PATTERNS` | `{ "/lazy/", "/pack/", "%.spec%.lua$" }` | 要排除的路径模式（Lua pattern）                          |
| `MIN_SEVERITY`     | `"HINT"`                                 | 最低 severity：`"ERROR"`、`"WARN"`、`"INFO"` 或 `"HINT"` |

- `TARGET_DIR`、`OUTPUT_FILE` 与 `FILE_PATHS` 中的路径经 `expand()` 展开；列表参数整体替换默认值。
- `FILE_PATTERNS` 由 `globpath()` 在 `TARGET_DIR` 下展开；`EXCLUDE_PATTERNS` 对 `/` 分隔的完整路径执行 `match()`。
- 默认规则排除路径含 `/lazy/`、`/pack/` 的文件与 `*.spec.lua`。本仓库的 spec 命名为 `*_spec.lua`，不会被排除；
  需要排除时设置 `EXCLUDE_PATTERNS={'/lazy/', '/pack/', '_spec%.lua$'}`。

以下等待参数固定在脚本中，不能通过全局变量覆盖：

| 配置项                   | 值                 | 说明                                     |
| ------------------------ | ------------------ | ---------------------------------------- |
| `timeout_ms`             | `600000` (10 分钟) | 最大等待时间                             |
| `poll_interval_ms`       | `15000` (15 秒)    | 轮询检查间隔                             |
| `stable_count_required`  | `3`                | 连续稳定次数阈值                         |
| `min_wait_after_open_ms` | `3000` (3 秒)      | 打开文件后的最小等待时间                 |
| `min_analysis_time_ms`   | `120000` (2 分钟)  | LSP 分析的最小等待时间；快速模式为 45 秒 |

---

## Output Format

诊断来自 `vim.diagnostic.get(nil)`，即所有 buffer 的诊断，按 `MIN_SEVERITY` 过滤；位置从 0-based 转换为 1-based。

### JSON

```json
{
  "meta": {
    "target_dir": "/home/user/.config/nvim",
    "total_files": 42,
    "failed_files": [],
    "total_diagnostics": 5,
    "min_severity": "HINT",
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
[init-debug-lsp] Target: /home/user/.config/nvim
[init-debug-lsp] Output: local/debug/lsp/20240115-103000.json
[init-debug-lsp] Found 457 files (skipped 5)
[init-debug-lsp] Opened 457/457 files
[init-debug-lsp] [15s] Waiting for LSP to attach... (attached=100/457, expected=457)
[init-debug-lsp] [30s] [5%] LSP busy (attached=457/457), diagnostics=0
[init-debug-lsp] [120s] [20%] LSP busy (attached=457/457), diagnostics=5
[init-debug-lsp] [135s] [22%] LSP idle (attached=457/457), diagnostics=5, stable=1/3
[init-debug-lsp] [150s] [25%] LSP idle (attached=457/457), diagnostics=5, stable=2/3
[init-debug-lsp] [165s] [27%] LSP idle (attached=457/457), diagnostics=5, stable=3/3
[init-debug-lsp] LSP analysis complete!

=== Found 5 diagnostics ===
/home/user/.config/nvim/lua/config/lsp.lua:25:10: [ERROR] Undefined global `vim`.
...

JSON output: local/debug/lsp/20240115-103000.json
```

---

## LSP Completion Detection Strategy

多重信号综合判断：

### 1. Client Requests 检查

- 遍历所有 LSP clients
- 检查 `client.requests` 是否为空
- 有 pending request → **busy**

### 2. `vim.lsp.status()` 检查

- 返回空字符串 → **idle**
- 返回非空（如 `"Indexing..."`）→ **busy**

### 3. Diagnostics 数量稳定性检查

- 等待至少 90% 的 buffer 都 attach LSP client（`vim.lsp.get_clients({ bufnr = bufnr })`）后才开始稳定性判断
- 记录上一次的诊断数量
- 必须等待 `min_analysis_time_ms` 后才开始计数
- 连续 N（`stable_count_required`）次数量不变 + LSP idle → **完成**
- 连续 3N 次数量不变 + LSP busy → **完成**（fallback，某些 LSP 可能持续报告 busy）
- 防止 LSP 分阶段报告导致的"假完成"

### 4. 超时兜底

- 超过最大等待时间后强制收集当前结果
- 输出警告信息

---

## Error Handling

| 场景             | 检测方式                                 | 处理策略                                                                        |
| ---------------- | ---------------------------------------- | ------------------------------------------------------------------------------- |
| LSP 未启动       | attach 的 buffer 不足 90%                | 持续等待；超过 `timeout_ms` 后输出 `WARNING: Timeout reached!` 并按当前结果退出 |
| 文件打开失败     | `safe_edit()` 返回 `false`               | 记录到 `failed_files`，继续处理其他文件                                         |
| JSON 编码失败    | `pcall(vim.fn.json_encode)` 返回 `false` | 输出错误信息，使用 `cq!` 非零退出，不写 JSON                                    |
| 输出文件写入失败 | `vim.fn.writefile` 抛出错误              | 收集中断：不输出诊断列表，进程不会自行退出                                      |

---

## Exit Codes

| 退出码 | 含义                                                                        |
| ------ | --------------------------------------------------------------------------- |
| 0      | 成功完成，无 diagnostics                                                    |
| 1      | 成功完成，存在 diagnostics（需要修复）；或缺少 `OUTPUT_FILE`、JSON 编码失败 |

> **Agent 提示**: 可通过 `$?` 判断是否需要进一步修复。超时同样按当前结果退出：stdout 出现
> `WARNING: Timeout reached!` 时，`exit 0` 不表示代码已无问题。

---

## Integration with Claude Code

- 需要实时观察进度时，在用户指定的 tmux pane（`%N`）中运行上述命令；不扫描或自动选择 pane。
- Collector 完成或超时后自行退出，正常结束时 stdout 以 `JSON output: <path>` 结尾；以进程退出为准，不用固定 sleep。
  诊断数量稳定且 LSP idle 时，全量扫描约在打开文件后 2.5 分钟完成，快速模式约 1.3 分钟；最长等待 `timeout_ms`。
- 读取本次 `OUTPUT_FILE` 指定的 JSON 并修复，按上述工作流复查，直到 diagnostics 为空。
