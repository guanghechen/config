# Terminal 设计

`era.m.term` 提供运行 shell job 的浮动 widget，与 Notepad 共用相近的导航和 winbar 交互。

## 模块边界

| 模块                                   | 职责                                                                    |
| -------------------------------------- | ----------------------------------------------------------------------- |
| `lua/era/m/term/state.lua`             | Terminal metadata、顺序与当前 UUID                                      |
| `lua/era/m/term/action.lua`            | Profile 选择、create/rename/destroy、focus/swap，以及 yazi/lazygit 入口 |
| `lua/era/m/term/widget.lua`            | 浮窗、mask/terminal buffers、job 启动与内容发送                         |
| `lua/era/m/term/event.lua`             | 将 terminal 退出事件同步回 state                                        |
| `lua/era/m/nvimbar/component/term.lua` | Terminal 列表与新增按钮                                                 |

State 使用 `metamap` 按 UUID 保存 name、cmd、cwd、env、jobid 等 metadata，`termlist` 保存顺序。
CRUD、`focus`、`put`、`iterator` 与 `pick_next_term` 供 widget/action 使用；左右交换由 action 层完成。
`o_termuuid` 通知当前 terminal 变化。
进程生命周期由 widget 管理。

## 窗口与 buffer

浮窗相对 editor 居中，使用 rounded border。初始挂载 `stl.filetype.TERM_MASK` buffer，
再切换为实际 terminal buffer，避免窗口结构在 job 启动期间变化。

默认窗口选项：

| 选项                                                      | 值                                              |
| --------------------------------------------------------- | ----------------------------------------------- |
| `cursorline`、`list`、`number`、`relativenumber`、`spell` | `false`                                         |
| `signcolumn`                                              | `"no"`                                          |
| `winfixbuf`、`wrap`                                       | `true`                                          |
| `winblend`                                                | `0`                                             |
| `winhighlight`                                            | `widget.lua` 中的 `TERMINAL_WIN_HIGHLIGHT` 映射 |

每个 terminal 使用独立 buffer，其 metadata 由 `era.m.term.state.create` 创建。
Buffer 初始化时设为 unlisted、`filetype = stl.filetype.TERM`，关闭 `modifiable`、`readonly` 与 `swapfile`。
`hidewipe` 为 true 时设置 `bufhidden = "wipe"`。

Widget 提供 `focus`、`toggle`、`toggle_and_focus`、`hide`、`resize`、`isvisible`、`isfocused`。
Resize 时重新计算 termline 最大宽度并渲染；宽度读取实际 terminal window 的 `nvim_win_get_width`。

## Job 生命周期

`focus()` 显示当前 terminal，确保 buffer/浮窗存在，仅在 `jobid == nil` 时通过
`vim.fn.jobstart(..., { pty = true, term = true })` 启动 job。没有当前 metadata 时关闭浮窗并返回。

`toggle_and_focus(params)` 先创建或更新目标 metadata，再按可见性与 `autofocus` 分派；
未指定 `autofocus` 时按 false 处理：

1. 浮窗已可见，且满足以下任一条件：目标是调用开始时的当前 terminal，或 `autofocus = false`。
   此时隐藏浮窗并返回，不发送文本。
2. 其他情况进入显示流程；`autofocus = true` 时先切换当前 UUID，再调用 `focus()`。
3. 进入显示流程后，非空 `selected_text` 通过 scheduled `vim.api.nvim_chan_send` 发送。
   Callback 执行时仍须满足 widget 有焦点、目标 `jobid` 非空，否则跳过。

`TermClose` 与 `jobstart.on_exit` 均通过 `era.m.term.event.on_closed` 更新 state；
`on_exit` 只处理仍与退出 `jobid` 匹配的 metadata。启动失败先报告，再延迟确认 metadata 仍属于失败的
buffer 且没有新 job，随后清理，避免影响后续启动。

Widget 订阅 `o_termuuid` 切换可见 buffer，通过 `dot.state.status.dirtier_termline` 合并 winbar 更新。

## Termline

`items(position)` 渲染列表，`add_button(position)` 渲染新增按钮；`M.terms` 是 `M.items` 的 alias。

- 名称最多显示 12 个字符，带 1-based index badge 与统一分隔符。
- 空间允许时居中显示当前 terminal；溢出时显示可点击的左右箭头与隐藏数量，调用已有 focus actions。
- 宽度允许时显示 `+`，触发 `Ftermcreate`。
- 当前项使用 focused palette，高亮复用 `dot.theme.hlgroup`。

## 命令与交互

命令位于 `dot.command.definitions.term`，包括 `Ftermtoggle`、`Ftermcreate`、`Ftermrename`、
`Ftermdestroy`、`Ftermfocus{1-9}`、`Ftermfocusleft/right` 与 `Ftermswapleft/right`。

Action 层选择包含 launch command 与 type 的 profile，处理重命名输入和删除确认，删除后选择后备 terminal。
状态变化时标记 `dirtier_termline`，通知统一使用 `stl.reporter`。
