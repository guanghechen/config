# Maximize

## 目标

Maximize 是当前 window 的临时全屏投影。任意时刻最多存在一个 normal-window maximize context。

## Normal window

- 从 source window 执行 `tab split`，创建仅含一个 normal window 的 transient tab。
- transient tab 使用 `TabTypeEnum.MAXIMIZE`；专属 nvimbar 只显示 `MAXIMIZED`，不显示其他 tabs。
- application-level tab focus/new 与 window split 在该 tabtype 下不可用。
- source 与 maximize window 初始显示同一个 buffer；buffer 内容天然共享。
- `dot.win.fork()` 复制 window metadata；window-owned Winline 通过 feature-owned fork factory 为 maximize
  window 创建独立 Nvimbar。Source render 同时驱动 live forks，target search state 只重绘 target owner。
  Target 拥有并释放自己的 Nvimbar/scheduler；source 只保留 borrowed render link，任一端关闭时解除连接。
- 退出时将 maximize window 的最终 buffer 和 view 同步回 source window。
- 通过 toggle/close 退出时，关闭 transient tab 并返回原 source tab/window。
- native command/API 绕过限制切换 tab 时，自动关闭 transient tab，同时保留用户新选择的 tab focus。
- session save/autosave 写入 native session 前，显式同步并关闭 transient tab，不依赖 lifecycle autocmd。
- source tab 已关闭且 transient tab 成为最后一个 tab 时，session save 将其原地 normalize 为 NORMAL，再清理 context。
- source tab/window 已失效时只做安全清理，不覆盖其他 window。

Neovim 无法锁定 tabpage。`:tabs` 等原生命令仍能观察到该 tab；原生命令或 API 也能触发切换，`TabLeave` 是对应的 safety net。

## Floating window

- 保留原地 maximize，不创建 tab，也不复制 widget buffer。
- 保存原始 window config、`winblend` 与 `winhighlight`；再次 toggle 时完整恢复。
- widget resize 通过 `dot.state.maximized.resolve_resize_config()` 更新原始 config，同时保持 maximized geometry。

## State ownership

`dot.state.maximized` 持有当前 maximize state：

- floating window：原 window handle 与可恢复的 presentation state；
- normal window：source tab/window、maximize tab/window、lifecycle augroup 与 closing guard。

normal context 最多一个；`era.m.maximize` 负责 create 与 close orchestration，`dot.state.maximized` 负责
projection sync 与 identity-checked terminal disposal，供 interactive lifecycle 与 session preparation 共用。
floating context 的 resize snapshot 由 `dot.state.maximized` 就地更新。
