# Whiteboard Architecture

## 1. 文档目的

本文件定义 Whiteboard 的实现架构，重点回答：

- 用什么技术栈实现。
- 模块如何分层、如何协作。
- 输入事件如何流转到渲染与存储。
- 首阶段开发应该先做什么。

与其他 spec 的关系：

- `canvas.md`：产品能力与核心模型定义。
- `action.md`：Action/Command/History 规则。
- `storage.md`：持久化与 autosave 细则。
- `arch.md`：把上述三者装配成可实现架构。

## 2. 架构目标

- 可维护：模块职责单一，依赖方向清晰。
- 可扩展：节点类型、工具类型可注册扩展。
- 可测试：核心逻辑可脱离 React 独立测试。
- 可迭代：先最小闭环，再扩展功能。
- 可迁移：`feature/whiteboard` 可独立迁移到其他应用，`view` 仅做装配。

## 3. 代码分层与边界

### 3.1 目录分层

```text
src/feature/whiteboard/        # 核心实现层
  model/                       # 类型与领域模型
  store/                       # SceneStore / CommandBus / HistoryStore
  runtime/                     # ToolController / InteractionEngine / Hotkey
  renderer/                    # Canvas 层渲染与调度
  extensions/                  # Node/Tool/Inspector registry + builtins
  services/                    # Autosave / StorageRecovery / Export / Clipboard
  ui/                          # 纯组件（不依赖页面全局状态）
  index.ts                     # 对外 API

src/view/whiteboard/           # 页面胶水层
  View.tsx
  Composer.tsx
  container/
```

### 3.2 依赖规则

- `view -> feature` 允许。
- `feature -> view` 禁止。
- `feature/ui` 不直接读取 route/workspace 等页面级 context。
- `store` 不依赖 React。
- `extensions/nodes/*` 仅通过 registry 接入，不直接改写 store 内部状态。

单向调用拓扑（强约束）：

```text
src/view/whiteboard/*
  -> src/feature/whiteboard/app/*
  -> src/feature/whiteboard/runtime/*
  -> src/feature/whiteboard/store/*
  -> src/feature/whiteboard/model/*

src/feature/whiteboard/runtime/*
  -> src/feature/whiteboard/renderer/*
  -> src/feature/whiteboard/services/*
```

说明：

- 任一层不得反向依赖调用方。
- `model/store` 不得导入 `ui/view`。
- `view` 只做 props 绑定、生命周期装配与页面样式拼装。

## 4. 技术选型

### 4.1 状态管理

方案对比：

1. `Class Store + CommandBus`（推荐）
- 优点：天然适配 undo/redo、事务、可测试。
- 缺点：需要手动维护订阅机制。

2. 纯 React State/Context
- 优点：心智模型简单。
- 缺点：复杂交互下更新链路难控，历史机制容易侵入 UI。

3. 第三方状态库（如 Zustand）
- 优点：开发快。
- 缺点：命令事务与跨模块约束仍需自建，收益有限。

推荐：`Class Store + CommandBus`。

### 4.2 渲染引擎

方案对比：

1. `WebGL + DOM Overlay`（推荐）
- 优点：高负载场景性能更稳，便于后续做 batching 与 shader 扩展。
- 缺点：实现复杂度高于 Canvas2D。

2. `Canvas2D + DOM Overlay`
- 优点：工程成本低。
- 缺点：首阶段上线后再迁移 WebGL 成本高。

3. 全 DOM/SVG
- 优点：调试直观。
- 缺点：图元规模上来后性能不稳定。

推荐：`WebGL + DOM Overlay`。

Renderer contract（v1）：

```ts
export interface IWhiteboardRenderer {
  prepare(scene: ICanvasGraph): void
  render(frame: IRenderFrame): void
  pick(point: ICanvasPoint): IPickResult | null
  dispose(): void
}
```

说明：

- 图元绘制由 WebGL 承担。
- Markdown editor、HUD、Inspector 走 DOM overlay。
- pick 允许先走 CPU 索引，再按需补 WebGL 精细 picking。

### 4.3 持久化

方案对比：

1. 双层持久化（Draft + File，推荐）
- 优点：兼顾编辑安全性与文件权威性。
- 缺点：状态管理略复杂。

2. 仅文件保存
- 优点：实现简单。
- 缺点：异常关闭丢数据风险高。

3. 仅本地草稿
- 优点：写入快。
- 缺点：无法稳定共享和版本化。

推荐：双层持久化（详见 `storage.md`）。

## 5. 核心模块设计

`model`

- 定义持久化模型：`IWhiteboardDocumentData`、`ICanvasGraphData`、`ICanvasNodeData`、`ICanvasPortData`、`ICanvasEdgeData`。
- 定义运行时模型：`IWhiteboardDocument`、`ICanvasGraph`、`ICanvasNode`、`ICanvasPort`、`ICanvasEdge`。

`store`

- `SceneStore`：文档状态单一真相。
- `CommandBus`：执行命令并驱动状态更新。
- `HistoryStore`：transaction 级 undo/redo。

`runtime`

- `ToolController`：工具状态与输入分发。
- `InteractionEngine`：DOM 事件转运行时事件。
- `RenderScheduler`：按 layer 触发增量重绘。
- `ComputeEventQueue`：队列化非实时计算，和渲染预算协同。

`renderer`

- 管理 grid/node/edge/interaction 多层画布。
- 提供 hit-testing 与路由绘制能力。

`extensions`

- `NodeRegistry`：节点定义注册。
- 内置节点：`markdown/shape/text/image/group/frame`。

`services`

- `AutosaveService`：draft 800ms + file idle 3s。
- `StorageRecoveryService`：启动恢复草稿决策。
- `ClipboardService`、`ExportService`：跨功能支持。

`ui`

- 纯组件：canvas shell、toolbar、inspector、floating host。

## 6. 关键时序

### 6.1 启动

```text
View Mount
  -> createWhiteboardRuntime()
  -> load document / recover draft
  -> hydrate graph index/runtime state
  -> full revalidate edges
  -> register built-in nodes/tools
  -> activate default tool
  -> start render scheduler
```

### 6.2 编辑主链路

```text
Pointer/Keyboard
  -> ToolController
  -> runtime draft mutate (for live preview)
  -> Action
  -> CommandBus
  -> SceneStore
  -> ComputeEventQueue (realtime + priority lanes)
  -> HistoryStore
  -> RenderScheduler
  -> AutosaveService
```

### 6.3 Markdown 编辑链路

```text
Click markdown node
  -> open floating editor
  -> save
  -> UpdateNodeCommand
  -> SceneStore update
  -> close floating
  -> rerender preview
```

## 7. 核心约束

- ID 统一使用 `prefix + nanoid`（如 `node-{nanoid}` / `port-{nanoid}`）。
- zoom 统一范围：`0.1 ~ 30`。
- warning 允许保存，但必须持续可视化。
- validation 不落盘，文档加载后必须重算。
- autosave 细则以 `storage.md` 为准。

## 8. 第一阶段落地（骨架）

### Phase A：核心闭环（已确认范围）

- 建立 feature/view 两层目录与对外 API。
- 打通常规绘图工具：`select / hand / rectangle / ellipse / diamond / line / arrow / text / image`。
- 打通节点交互：`create / move / resize / rotate / delete / duplicate / multi-select / lasso`。
- 打通图连接：`CanvasPort + CanvasEdge` 强类型连接、实时 validation、warn/error 可视化。
- 打通文档能力：`undo / redo / copy / paste / z-index 调整 / zoom & pan`。
- 打通 markdown 节点：单实例 floating editor（最简 Monaco 集成）。
- 接入持久化：draft autosave、file autosave、`beforeunload flush`、reload revalidate。

验收口径：

- 用户在 Phase A 应可完成与 Excalidraw 常规白板一致的单人编辑流程。
- 运行时 warning 不落盘；重载文档后可根据当前规则恢复 warning 可视状态。

### Phase B：交互增强

- 完善 edge routing（straight / bezier / orthogonal）与 reroute handles。
- 完善 validation 反馈样式与 warning 可视化细节。
- 完善 inspector 配置能力与批量编辑。

### Phase C：稳定性与性能

- 建立 Baseline-S / Baseline-L 自动回归。
- 优化 hit-testing 与增量渲染策略。
- 补齐恢复、异常保存、导出链路的容错测试。

## 9. 风险与缓解

- 风险：渲染与命中测试复杂度高。
- 缓解：先实现 axis-aligned hit-test，再逐步支持旋转与复杂路径。

- 风险：命令事务边界不清导致历史噪音。
- 缓解：严格按 pointer down/up 包裹 transaction。

- 风险：草稿/文件双写状态不一致。
- 缓解：统一 `StorageStatus` 与可观测日志字段。
