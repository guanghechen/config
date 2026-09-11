# 原生搜索的 Winline 反馈

## 范围

本文定义 Neovim 原生 `/`、`?`、`n`、`N` 的搜索反馈，不涉及 `era.m.searcher` 或 picker 结果位置。

搜索 pattern 以寄存器 `/` 为准；计数使用 Neovim 原生 `search_count` payload 末尾的方括号内容，
保留 `[1/>99]`、`[?/??]` 等边界形式。

## 状态归属与数据流

```text
Neovim ext_messages
  └─ msg_show(search_cmd/search_count)
       └─ era.dressing.ui_attach.messages
            └─ dot.state.status search state
                 ├─ dirty_winline_nr
                 └─ era.m.nvimbar.component.nvim.search_count
                      └─ source window winline (right)
```

`dot.state.status` 持有一个 transient search snapshot：

```lua
{
  winnr = winnr,
  bufnr = bufnr,
  pattern = "query",
  count = "index/total", -- nil until Neovim publishes search_count
}
```

只有 `set_search()`、`clear_search()` 可修改状态。消费者通过 `get_search(winnr)` 分别读取 pattern
与 count，不直接访问内部 table。

仅当目标 window 有效且仍显示 source buffer 时返回数据。替换 snapshot 时，若新旧 window 不同，
两者都要重绘。

## 事件生命周期

| 事件                                    | 状态转换                                                                                       |
| --------------------------------------- | ---------------------------------------------------------------------------------------------- |
| `search_cmd`                            | 设置 `searching = true`，读取寄存器 `/`，发布 count 为 nil 的 snapshot                         |
| `search_count`                          | 设置 `searching = true`，重新读取 `/`，从组合消息或纯计数消息末尾提取 count，发布完整 snapshot |
| 搜索中或 `v:hlsearch == 1` 时按 `<Esc>` | 设置 `searching = false`，清空 snapshot，再 schedule `:nohlsearch`                             |
| Status reset/dispose                    | 清空 transient snapshot                                                                        |

每次事件都发布完整 snapshot，确保 `n/N` 的纯计数事件不会抹去 pattern。
空 pattern 或无效 window/buffer 会清除旧值，避免保留过期反馈。

## Winline 渲染

搜索反馈位于 winline 右侧，按可用宽度裁剪，优先级为 `120`；hunk navigation 为 `110`。
两者同时存在时顺序如下：

```text
<git-icon> hunk-index/hunk-total <search-icon> pattern search-index/search-total
```

搜索项位于最右侧，并优先获得宽度。Count 未到达时显示 `<search-icon> pattern`。
长内容从中间截断，保留 icon 与末尾计数；使用黄色前景 `f_wl_nvim_search_count` 和普通 winline 背景。

反馈不使用 buffer virtual text 或 extmark，因此不受行长、水平滚动及 inline blame 的位置影响。

## 验证

- `__test__/specs/dot/state/status_spec.lua`：状态归属、window/buffer scope、发布与清理。
- `__test__/specs/era/dressing/ui_attach/messages_spec.lua`：原生事件转换，以及 `search_cmd`、组合
  `search_count`、纯计数 `n/N` 的完整 snapshot。
- `__test__/specs/era/dressing/ui_attach/init_spec.lua`：`<Esc>` 清理。
- `__test__/specs/era/m/nvimbar/component/nvim_spec.lua`：搜索 icon、pattern 保留、无方括号计数、
  截断、右侧布局与 source window scope。
