# Window 最大化

Maximize 是当前 window 的临时全屏投影；任意时刻最多存在一个普通 window 的 maximize context。

## 普通 window

- 从 source window 执行 `tab split`，创建只含一个普通 window 的临时 tab。
- 临时 tab 使用 `TabTypeEnum.MAXIMIZE`，专属 nvimbar 只显示 `MAXIMIZED`；应用级 tab focus/new 与 window split 在该类型下不可用。
- Source 与 maximize window 初始显示同一 buffer，共享编辑内容。
- `dot.win.fork()` 复制 window metadata。Feature 的 fork factory 为 maximize window 创建独立的 Winline Nvimbar；
  source render 同时驱动 live forks，target search state 只重绘 target owner。
- Target 负责释放自己的 Nvimbar/scheduler；source 只保留 borrowed render link，任一端关闭时解除连接。
- 退出时将 maximize window 的最终 buffer 与 view 同步回 source。通过 toggle/close 退出时，关闭临时 tab 并返回原 source tab/window。
- 原生命令/API 切换 tab 时，自动关闭临时 tab，并保留用户新选择的焦点。Source tab/window 已失效时只清理，不覆盖其他 window。

Neovim 无法锁定 tabpage；`:tabs` 仍可观察该 tab，原生命令/API 仍可切换。
`TabLeave` 负责处理这些绕过应用入口的切换。

## 浮动 window

- 在原 window 上最大化，不创建 tab 或复制 widget buffer。最大化后从第 0 行起覆盖 tabline、占满全宽，止于全局
  statusline 之上，statusline 与命令行保持可见；外框统一为完整圆角，zindex 比原 window 高一级。
- 保存原 window config、`winblend` 与 `winhighlight`，再次 toggle 时恢复。
- Widget resize 通过 `dot.state.maximized.resolve_resize_config()` 更新原 config，同时维持最大化后的尺寸。调用方以屏幕上的
  config 为基础，其边框与 zindex 属于最大化，因此原 config 只接收其余字段，边框与 zindex 保持原值。
- Widget 在最大化期间修改边框等呈现字段时经 `dot.state.maximized.set_float_config()` 写入原 config，恢复后生效，
  不改动最大化外框。

## 窗口自管的最大化

窗口类型（`vim.w.wintype`）可以经 `era.m.maximize.register(wintype, handler)` 声明自己的最大化方式。Toggle 先按目标
window 的类型查找 handler，找到就交给它，否则按上文处理普通 window 与浮动 window。

- Handler 提供 `toggle(winnr)` 与 `is_maximized(winnr)`；`era.m.maximize.is_maximized(winnr)` 统一回答三种方式。
- 模块在 window 关闭或转作他用之前调用 `era.m.maximize.restore(winnr)`，结束 handler 对它的放大；调用时 window 仍须
  带着注册 handler 的类型。
- 自己记录窗口尺寸的模块，在 `is_maximized` 期间不记录尺寸变化，也不把放大后的尺寸保存为原尺寸。

`era.m.maximize.in_place` 是现成的 handler，在原 tab 内放大：

- 用 `wincmd _`、`wincmd |` 把 window 放到最大，window 与 buffer 不变，并记下 tab 中每个普通 window 的宽高；浮动
  window 不在其中。同一时间最多一个 window 原地放大。
- 再次 toggle、焦点进入同 tab 的另一个普通 window、或离开该 tab 时恢复；进入浮动 window 不恢复。被放大的 window 关闭时，
  其余 window 在关闭完成后恢复。
- 恢复把记下的尺寸还给仍在 tab 中的 window：宽度都还原；高度只还原与其他 window 同在一列（自身或所在的行处于纵向堆叠中）
  的 window，独占整列高度的 window 还原高度会把差额交给命令行。

Explorer 使用 `in_place`：树视图与按 tab 的记录都绑定在原 window 上，换到临时 tab 会失去图标、缩进线与按键。

## 侧栏沉浸

带纵向堆叠侧栏的界面在侧栏 pane 中把 `z;` 绑定为沉浸切换；侧栏之外（preview、SBS）的 `z;` 仍是上述 window 最大化。

- 沉浸时侧栏只显示当前 pane（界面固定的输入框保留），占满侧栏高度；其余 pane 隐藏，保留各自的 Treeview State
  （展开、选择与逻辑 cursor）。再次 `z;` 按原顺序恢复隐藏的 pane 与默认高度，当前 pane 的窗口与焦点不变。
- 沉浸时 `<C-a>h/j/k/l` 只在可见 pane 之间移动；`]p` / `[p` 以及界面中把焦点移入隐藏 pane 的其他操作
  让该 pane 取代当前 pane。
- 模式属于界面实例；各界面的 pane、切换操作与生命周期见 [Git Files](git-files.md#布局) 与
  [Diffview 布局](diffview/layout.md#沉浸模式)。

## 状态归属

`dot.state.maximized` 持有三类状态：

- 浮窗：原 window handle 与可恢复的 presentation state，就地更新 resize snapshot。
- 普通窗口：source tab/window、maximize tab/window、lifecycle augroup 与 closing guard。
- 原地放大：window、tab、放大前各普通 window 的宽高，以及恢复用的 augroup。

`era.m.maximize` 负责创建和关闭流程；`dot.state.maximized` 负责 projection sync，
并在最终清理前校验 identity。Tab 类型与命令匹配见 [Tab](../dot/tab.md)。
