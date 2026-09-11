# Act Board 组件

`era.view.Act` 将输入框与预览窗口组合为一个面板，适用于需要输入并实时预览的操作。
实现位于 `lua/era/view/act.lua`。组件只负责输入、预览与生命周期；业务校验和执行由调用方提供。

```text
+-----------------------------+
| Title                       |
| > input                     |
+-----------------------------+
| preview line 1              |
| preview line 2              |
+-----------------------------+
```

## API

```lua
local act = era.view.Act.new({
  name = "my_action",                    -- 唯一标识
  title = "Action Title",                -- 标题栏显示
  initial_input = "default value",       -- 输入框初始值
  preview_lines = 5,                     -- 预览窗口行数
  width = 0.6,                           -- 宽度（0-1 表示比例，>1 表示 screen columns）
  get_width = function()                 -- 动态计算宽度（优先于 width）
    return 80
  end,
  render_preview = function(bufnr, input)
    -- 渲染预览内容
  end,
  on_input_change = function(input)
    -- 输入变化时的回调（可选）
  end,
  on_confirm = function(input)
    -- 确认时的回调
  end,
  on_cancel = function()
    -- 取消时的回调（可选）
  end,
  keymaps = {},                          -- 额外的快捷键（可选）
})
```

| 方法            | 行为                               |
| --------------- | ---------------------------------- |
| `act:open()`    | 打开面板；已可见时聚焦输入框       |
| `act:close()`   | 关闭并释放资源                     |
| `act:confirm()` | 释放资源后调用 `on_confirm(input)` |
| `act:cancel()`  | 释放资源后调用 `on_cancel()`       |
| `act:dispose()` | 幂等释放资源                       |

`<CR>` 确认，`<Esc>` 取消，Normal mode 的 `q` 也取消。实例关闭后即 disposed，不能重新打开。

## 预览回调

`render_preview(bufnr, input)` 接收 preview buffer ID 与当前输入。
输入变化触发 64 ms 的 `stl.timer.debounce`；回调执行期间 buffer 可写，结束后恢复 readonly。
渲染及输入回调失败由组件通过 `stl.reporter.error` 报告。

写入预览内容：

```lua
render_preview = function(bufnr, input)
  local lines = { "line 1", "line 2", "line 3" }
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
end
```

通过 `vim.hl.range` 添加高亮；每次重绘先清理旧 namespace：

```lua
local ns = vim.api.nvim_create_namespace("my_preview_ns")

render_preview = function(bufnr, input)
  local lines = { "source -> target" }
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  vim.hl.range(bufnr, ns, "f_pk_matches", { 0, 0 }, { 0, 6 })  -- 高亮 "source"
end
```

## 展示约定

调用方可用 `source -> target` 展示移动映射，`source +> target` 展示复制映射，
或直接列出待删除项。若展示路径，可使用 CWD-relative filepath，并用 `f_pk_matches` 标记需要突出的片段。
路径生成、目标冲突处理和确认语义均属于调用方，不是 Act 的内置能力。

这些是组件展示示例。Explorer 当前的 `mx/mc/ms` 用于 mark，`p` 直接粘贴到 focused directory；
完整动作契约见 [Explorer](../explorer.md)，此处不重复定义其交互。

## 布局与样式

宽度按以下优先级计算，再限制在最小/最大宽度之间：

1. `get_width()` 返回的 screen columns。
2. `width`：`0 < width <= 1` 表示 editor columns 的比例，`width > 1` 表示 screen columns。
3. 未指定时使用 `0.6`。

最大宽度为 `min(120, vim.o.columns - 4)`，最小宽度为 `min(floor(vim.o.columns * 0.4), 60)`。
预览默认 5 行，最多 10 行；屏幕高度不足时缩减。
窗口使用 editor-relative 坐标，按当前光标的屏幕位置布局，并调整位置避免越界。

| 区域     | Border              | Background           |
| -------- | ------------------- | -------------------- |
| 输入框   | `FloatActiveBorder` | `f_pk_finder_normal` |
| 预览窗口 | `FloatBorder`       | `f_pk_result_normal` |
