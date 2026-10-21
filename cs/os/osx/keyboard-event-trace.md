---
title: macOS 键盘事件逐层追踪
tags: [macos, keyboard, troubleshoot]
updated: 2026-10-21
---

# macOS 键盘事件逐层追踪

> `CGGetEventTapList` 只列出 event tap，看不到全局热键。Control Center 响应正常、主线程采样没有明显阻塞，或列表中没有它的 event tap，都不能排除它占用按键。

按键失效且未发现重映射配置时，逐层定位事件在哪里丢失：

1. **硬件 → Karabiner**：Karabiner-EventViewer 能看到按键，说明 Karabiner 已发出。
2. **`kCGHIDEventTap` → `kCGAnnotatedSessionEventTap`**：全局热键匹配和 session 级 active event tap 都发生在这两层之间。用下面的脚本对比两层。

| HID 层 | AnnotatedSession 层 | 结论                                          |
| ------ | ------------------- | --------------------------------------------- |
| 无按键 | 无按键              | 优先检查硬件、Karabiner、驱动及更早的 HID tap |
| 有按键 | `NX_SYSDEFINED`     | 全局热键占用；`target` 为占用进程             |
| 有按键 | 无相关事件          | 被 active event tap 丢弃                      |
| 有按键 | 有按键              | 系统层正常，检查 app 内部                     |

脚本在 HID 层使用 `tailAppendEventTap`；排在它之前的 HID 级 active event tap 也可能已经丢弃按键，因此两层都没有事件时不能直接判定为硬件故障。

```swift
// key-trace.swift：swiftc -O key-trace.swift -o key-trace && ./key-trace
// 终端需有 Input Monitoring 权限；tap 为 listen-only，不拦截按键。
import AppKit

let keyCode: Int64 = 53  // Esc
setvbuf(stdout, nil, _IOLBF, 0)
let formatter = DateFormatter()
formatter.dateFormat = "HH:mm:ss.SSS"

func processPath(_ pid: Int64) -> String {
  var buffer = [CChar](repeating: 0, count: 4096)
  return pid > 0 && proc_pidpath(pid_t(pid), &buffer, 4096) > 0 ? String(cString: buffer) : "-"
}

let callback: CGEventTapCallBack = { _, type, event, info in
  let layer = info == nil ? "HID      " : "Annotated"
  let time = formatter.string(from: Date())
  if (type == .keyDown || type == .keyUp) && event.getIntegerValueField(.keyboardEventKeycode) == keyCode {
    print("\(time) \(layer) key=\(keyCode) \(type == .keyDown ? "down" : "up")")
  } else if type.rawValue == 14, info != nil, let ns = NSEvent(cgEvent: event),
            ns.subtype.rawValue != 7 {  // 7 = NX_SUBTYPE_AUX_MOUSE_BUTTONS，鼠标按键噪音
    let pid = event.getIntegerValueField(.eventTargetUnixProcessID)
    print("\(time) \(layer) NX_SYSDEFINED subtype=\(ns.subtype.rawValue) data1=0x\(String(ns.data1, radix: 16)) target=\(processPath(pid))")
  }
  return Unmanaged.passUnretained(event)
}

let mask = CGEventMask(1 << 10 | 1 << 11 | 1 << 14)  // keyDown | keyUp | NX_SYSDEFINED
let layers: [(CGEventTapLocation, UnsafeMutableRawPointer?)] = [
  (.cghidEventTap, nil),
  (.cgAnnotatedSessionEventTap, UnsafeMutableRawPointer(bitPattern: 1)),
]
for (location, info) in layers {
  guard let tap = CGEvent.tapCreate(tap: location, place: .tailAppendEventTap, options: .listenOnly,
                                    eventsOfInterest: mask, callback: callback, userInfo: info) else {
    fatalError("Cannot create event tap; grant Input Monitoring to the terminal.")
  }
  CFRunLoopAddSource(CFRunLoopGetCurrent(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
}
print("Press the key in another app; Ctrl-C to stop.")
CFRunLoopRun()
```

运行后切到其他 app 按键，避免终端内的程序先处理该键。

## 已验证案例：Control Center 占用 Esc

2026-10-21，物理 Esc 在应用中失效。连续按三次 Esc，均在 HID 层收到 `key=53`，AnnotatedSession 层则收到发给 Control Center 的 `NX_SYSDEFINED`，没有对应的普通按键事件。一次按下、松开的记录如下（省略时间戳）：

```text
HID       key=53 down
Annotated NX_SYSDEFINED subtype=6 data1=0x5 target=/System/Library/CoreServices/ControlCenter.app/Contents/MacOS/ControlCenter
Annotated NX_SYSDEFINED subtype=9 data1=0x5 target=/System/Library/CoreServices/ControlCenter.app/Contents/MacOS/ControlCenter
HID       key=53 up
```

确认 `target` 指向 Control Center 后，重启该进程：

```bash
killall ControlCenter
```

系统自动重新启动 Control Center，随后在原应用手动测试，确认 Esc 恢复。此案例验证了全局热键占用及重启后的恢复，尚未确定占用的触发条件。`data1=0x5` 仅是本次观测值，不作为识别 Control Center 的固定判据。

## 注意

- 以非 exclusive 方式调用 `RegisterEventHotKey` 探测，即使组合键已被其他进程占用也返回 `noErr`，不能据此判定未被占用。
- `NX_SYSDEFINED` 的 `subtype=6` / `9` 对应热键按下 / 松开，不在公开的 `IOLLEvent.h` 中，属观测值。
