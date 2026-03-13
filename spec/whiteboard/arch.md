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

1. `Canvas2D + DOM Overlay`（推荐）
- 优点：适配图形高频渲染与 Markdown 浮窗编辑。
- 缺点：需要处理坐标同步与命中测试。

2. 全 DOM/SVG
- 优点：开发直观。
- 缺点：大规模节点性能压力明显。

3. WebGL
- 优点：极限性能高。
- 缺点：工程复杂度高，不适合首期。

推荐：`Canvas2D + DOM Overlay`。

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
- 打通：创建节点、移动节点、撤销重做。
- 打通：`CanvasPort` + `CanvasEdge` 强类型连接。
- 打通：markdown 节点 + 单实例 floating editor（最简 Monaco 集成）。
- 接入 draft autosave 与 `beforeunload flush`。

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
