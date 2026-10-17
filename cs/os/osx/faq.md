---
title: macOS FAQ
tags: [macos, faq]
updated: 2026-10-17
---

# macOS FAQ

## Esc 键在所有 app 中失效

可能是 `ControlCenter` 占用了 Esc 全局热键。重启它即可，launchd 会自动拉起：

```bash
killall ControlCenter
```

仍未恢复时，按 [键盘事件逐层追踪](keyboard-event-trace.md) 定位。
