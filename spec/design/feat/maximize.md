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

## 状态归属

`dot.state.maximized` 持有两类状态：

- 浮窗：原 window handle 与可恢复的 presentation state，就地更新 resize snapshot。
- 普通窗口：source tab/window、maximize tab/window、lifecycle augroup 与 closing guard。

`era.m.maximize` 负责创建和关闭流程；`dot.state.maximized` 负责 projection sync，
并在最终清理前校验 identity。Tab 类型与命令匹配见 [Tab](../tab.md)。
