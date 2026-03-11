# Whiteboard Spec 导航

## 文档分层

- `canvas.md`：架构总览、核心模型、组件边界、节点扩展。
- `arch.md`：实现骨架、模块依赖、启动时序、接口蓝图。
- `action.md`：Action/Command/History/Transaction 与交互执行流。
- `storage.md`：序列化、autosave、恢复、错误处理。

## 阅读顺序（推荐）

1. `canvas.md`：先建立系统边界与核心概念。
2. `arch.md`：再看工程骨架与实现切入点。
3. `action.md`：明确运行时行为和可撤销机制。
4. `storage.md`：确定持久化与可靠性策略。

## 架构主线

```text
Input
  -> Tool
  -> Action
  -> Command
  -> SceneStore
  -> Renderer
  -> Storage
```
