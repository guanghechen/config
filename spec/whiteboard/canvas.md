# Whiteboard Canvas 设计方案（重写版）

## 1. 决策确认

本方案以以下已确认决策为硬约束：

- 彻底重写 whiteboard，不考虑旧格式兼容与迁移包袱。
- 连接模型采用强类型约束，必须提供友好的连接反馈、warning、validation。
- Markdown 节点交互为点击打开 floating window 编辑，保存后回到 node 预览态。
- Markdown floating editor 采用单实例策略（同一时刻仅允许一个编辑窗口）。
- 目标是全功能设计先行，先把架构和组件组织定清楚，再进入实现。
- 文件扩展名优先使用 `.whiteboard`。
- 全局 ID 生成策略统一采用 `nanoid`。
- `zoom` 范围固定为 `0.1 ~ 30`。
- 图片节点采用外链资源策略，同时支持 URL 与相对路径。
- `warn` 级问题允许保存，但 UI 需持续显示 warning 图标直至问题修复。
- `autosave` 详细方案独立维护在 `spec/whiteboard/storage.md`。

## 2. 目标与范围

### 2.1 目标

- 体验对齐 Excalidraw：流畅绘制、选择、拖拽、缩放、快捷键、历史记录。
- 模型升级为图编辑器一等公民：`CanvasNode` / `CanvasPort` / `CanvasEdge` / `CanvasGraph`。
- 代码结构可读、模块职责单一、可测试、可扩展。

### 2.2 范围

- 新建独立 whiteboard runtime、store、renderer、serialization 协议。
- 重新定义文档协议与节点扩展机制。
- 设计全量功能模块与组件目录。

### 2.3 非目标

- 不提供 `.drawboard` / `.excalidraw` 兼容导入导出。
- 不复用 `@excalidraw/excalidraw` runtime。
- 首版不做多人实时协同（预留接口，但不实现）。

### 2.4 Spec 分层

- `spec/whiteboard/canvas.md`：画布架构、模型、组件边界。
- `spec/whiteboard/action.md`：Command、Action、History、交互事务规则。
- `spec/whiteboard/storage.md`：序列化、autosave、恢复与错误处理策略。

## 3. 架构原则

- Single source of truth：场景状态只在 `SceneStore`。
- Command-first：所有写操作必须走 command，天然支持 undo/redo。
- Action/Command 详细定义见 `spec/whiteboard/action.md`。
- Rendering split：高频绘制走 canvas，富内容走 DOM overlay。
- Type-safe graph：edge 创建必须通过 port 规则校验。
- Extension-first：节点、工具、inspector 都走 registry，避免硬编码分支。

## 4. 路线对比与结论

### Option A：嵌入 `@excalidraw/excalidraw`

- 优点：短期快。
- 缺点：核心状态机不可控，Node/Port/Edge 只能二次映射。

### Option B：完全自建 runtime（推荐）

- 优点：模型、交互、代码风格、扩展点完全可控。
- 缺点：前期设计和实现成本更高。

### Option C：fork Excalidraw 深改

- 优点：复用成熟能力。
- 缺点：长期维护成本高，升级冲突重。

推荐：Option B。

## 5. 文件扩展名方案

### 方案 1：`.whiteboard`

- 含义直观，面向用户可读性最好。
- 与业务语义直接对应，便于后续生态工具识别。

### 方案 2：`.yoz`

- 品牌统一性高。
- 语义过于宽泛，不利于区分文档类型。

### 方案 3：`.yozora`

- 品牌识别强。
- 扩展名偏长，命令行与文件管理体验一般。

推荐：`.whiteboard`。

协议标识建议：

- `kind: "yoz.whiteboard"`
- `schemaVersion: 1`

## 6. 总体架构

```text
WhiteboardApp
  -> WhiteboardShell
     -> SceneStore
     -> CommandBus
     -> HistoryManager
     -> ViewportController
     -> ToolController
     -> InteractionEngine
     -> RenderScheduler
     -> ExtensionRegistry
     -> Serializer

Render Layers (bottom -> top)
  1. PaperLayerCanvas
  2. GridLayerCanvas
  3. EdgeLayerCanvas
  4. NodeLayerCanvas
  5. OverlayDomLayer
  6. InteractionLayerCanvas
  7. HUDDomLayer
```

## 7. 核心数据模型 API

### 7.1 Document

```ts
export interface IWhiteboardDocument {
  readonly id: string
  readonly kind: 'yoz.whiteboard'
  readonly schemaVersion: number
  readonly version: number
  readonly graph: ICanvasGraph
  readonly meta: IWhiteboardDocumentMeta
}

export interface IWhiteboardDocumentMeta {
  readonly title: string
  readonly description?: string
  readonly createdAt: number
  readonly updatedAt: number
}

export interface ICanvasViewport {
  readonly zoom: number
  readonly offsetX: number
  readonly offsetY: number
  readonly gridSize: number
  readonly showGrid: boolean
}

export const WHITEBOARD_ZOOM = {
  MIN: 0.1,
  MAX: 30,
  STEP: 0.1,
} as const

export type IWhiteboardId = string

export interface IIdFactory {
  readonly createDocId: () => IWhiteboardId
  readonly createNodeId: () => IWhiteboardId
  readonly createPortId: () => IWhiteboardId
  readonly createEdgeId: () => IWhiteboardId
}

// 统一使用 prefix + nanoid；v1 推荐 nanoid 长度 12。
export const IdFactory: IIdFactory = {
  createDocId: () => `doc-${nanoid(12)}`,
  createNodeId: () => `node-${nanoid(12)}`,
  createPortId: () => `port-${nanoid(12)}`,
  createEdgeId: () => `edge-${nanoid(12)}`,
}

// 约定格式：`doc-{nanoid}` / `node-{nanoid}` / `port-{nanoid}` / `edge-{nanoid}`。
```

### 7.2 ICanvasGraph

```ts
export interface ICanvasGraph {
  readonly schemaVersion: number
  readonly viewport: ICanvasViewport
  readonly edgeOrder: ReadonlyArray<string>
  readonly nodesById: Readonly<Record<string, ICanvasNode>>
  readonly portsById: Readonly<Record<string, ICanvasPort>>
  readonly edgesById: Readonly<Record<string, ICanvasEdge>>
  readonly edgeIdsByPortId: Readonly<Record<string, ReadonlyArray<string>>>
}
```

### 7.3 ICanvasNode

```ts
export interface ICanvasNode {
  readonly id: string
  readonly type: string
  readonly dimension: ICanvasNodeDimension
  readonly transform: ICanvasNodeTransform
  readonly zIndex: number
  readonly locked: boolean
  readonly hidden: boolean
  readonly style: ICanvasNodeStyle
  readonly data: Record<string, unknown>
  readonly portIds: ReadonlyArray<string>
  readonly createdAt: number
  readonly updatedAt: number
}

export interface ICanvasNodeDimension {
  readonly x: number
  readonly y: number
  readonly width: number
  readonly height: number
}

export interface ICanvasNodeTransform {
  readonly rotation: number
  readonly scaleX: number
  readonly scaleY: number
}

export interface ICanvasNodeStyle {
  readonly strokeColor: string
  readonly fillColor: string
  readonly strokeWidth: number
  readonly strokeStyle: 'solid' | 'dashed' | 'dotted'
  readonly roughness: number
  readonly opacity: number
  readonly cornerRadius: number
}
```

### 7.4 ICanvasPort

```ts
export type ICanvasPortDirection = 'input' | 'output' | 'bidirectional'
export type ICanvasPortPlacement = 'top' | 'right' | 'bottom' | 'left' | 'custom'

export interface ICanvasPort {
  readonly id: string
  readonly nodeId: string
  readonly name: string
  readonly direction: ICanvasPortDirection
  readonly placement: ICanvasPortPlacement
  readonly offset: number
  readonly maxConnections: number | null
  readonly accepts: ReadonlyArray<string>
  readonly emits: ReadonlyArray<string>
  readonly required?: boolean
  readonly data?: Record<string, unknown>
}

// 兼容旧术语，避免文档迁移期歧义。
export type ICanvasNodePort = ICanvasPort
```

### 7.5 ICanvasEdge

```ts
export type ICanvasEdgeRouting = 'straight' | 'bezier' | 'orthogonal'

export interface ICanvasEdge {
  readonly id: string
  readonly from: ICanvasEdgeEndpoint
  readonly to: ICanvasEdgeEndpoint
  readonly routing: ICanvasEdgeRouting
  readonly style: ICanvasEdgeStyle
  readonly label?: string
  readonly data?: Record<string, unknown>
  readonly validation?: IEdgeValidationResult
  readonly createdAt: number
  readonly updatedAt: number
}

export interface ICanvasEdgeEndpoint {
  readonly nodeId: string
  readonly portId: string
}

export interface ICanvasEdgeStyle {
  readonly strokeColor: string
  readonly strokeWidth: number
  readonly strokeStyle: 'solid' | 'dashed' | 'dotted'
  readonly startMarker: 'none' | 'arrow' | 'dot'
  readonly endMarker: 'none' | 'arrow' | 'dot'
}
```

层级规则：

- 节点层级权威字段为 `node.zIndex`，不再维护 `graph.nodeOrder`。
- 渲染时按 `zIndex` 升序绘制；同 `zIndex` 时按 `createdAt` 升序、再按 `id` 字典序稳定排序。

## 8. 强类型连接与友好反馈

### 8.1 校验规则

- 方向校验：`output -> input` 或 `bidirectional -> any`。
- 类型校验：`from.emits` 与 `to.accepts` 必须有交集。
- 容量校验：`maxConnections` 达上限则拒绝新连接。
- 自环规则：默认禁止 `nodeId` 相同连接，节点可显式放开。

### 8.2 交互反馈状态

- `valid`：port 高亮绿色，cursor 显示 connect。
- `warn`：允许连接但有风险，显示黄色提示条。
- `invalid`：port 高亮红色，显示拒绝 icon 与原因。

补充：

- `warn` 状态创建的 edge 在常态下也显示 warning 图标，不仅在 hover 时展示。
- warning 图标应可点击，打开问题说明（`code + message`）。

### 8.3 warning / validation 输出模型

```ts
export type IEdgeValidationLevel = 'ok' | 'warn' | 'error'

export interface IEdgeValidationResult {
  readonly level: IEdgeValidationLevel
  readonly code: string
  readonly message: string
}
```

说明：

- `error` 阻断连接创建。
- `warn` 允许创建，但在 edge 上挂载 warning badge。
- `warn` 不阻断保存；保存后仍保留 warning badge，直到校验结果变为 `ok`。

## 9. Markdown 节点与 Floating Editor

### 9.1 Markdown 节点数据

```ts
export interface ICanvasMarkdownNodeData {
  readonly markdown: string
  readonly title?: string
  readonly collapsed: boolean
  readonly maxPreviewLines: number
  readonly theme: 'light' | 'dark' | 'auto'
}
```

### 9.2 交互流程

```text
click markdown node
  -> open FloatingMarkdownEditor (anchored to node)
  -> edit content
  -> save
  -> dispatch UpdateNodeCommand
  -> close floating window
  -> node re-render preview
```

### 9.3 行为细节

- 单击即打开 floating window。
- floating editor 单实例：打开新编辑窗口前先关闭当前窗口，必要时提示未保存内容。
- 编辑窗口支持拖动、缩放、最小化。
- `Cmd/Ctrl + Enter` 保存，`Esc` 关闭并提示未保存变更。
- 保存后 node 回到只读预览态，内容裁切遵循 node 尺寸。

## 10. 全功能清单（设计范围）

### 10.1 画布与视口

- 无限画布
- pan / zoom / fit to content / mini-map
- grid / snap / ruler / alignment guides

### 10.2 节点与边

- shape / markdown / text / image / group / frame
- 自定义节点注册机制
- edge routing: straight / bezier / orthogonal
- edge label / marker / reroute handles

### 10.3 编辑能力

- select / lasso / multi-select
- move / resize / rotate / duplicate / align / distribute
- z-order / lock / hide / group / ungroup
- copy / paste / clipboard with offsets

### 10.4 绘制工具

- rectangle / ellipse / diamond / arrow / line
- freehand（pressure-aware）
- text tool

### 10.5 文档能力

- undo / redo（transaction 合并）
- autosave（详见 `spec/whiteboard/storage.md`）
- import/export（仅 whiteboard 协议）
- png/svg/pdf export

### 10.6 未来预留

- plugin SDK
- collaboration API hooks
- node template marketplace

## 11. 组件与文件结构（实现前定稿）

```text
src/feature/whiteboard/
  app/
    WhiteboardCompositionRoot.ts
  model/
    IWhiteboardDocument.ts
    ICanvasGraph.ts
    ICanvasNode.ts
    ICanvasPort.ts
    ICanvasEdge.ts
    IValidation.ts
  store/
    SceneStore.ts
    SelectionStore.ts
    ViewportStore.ts
    HistoryStore.ts
    CommandBus.ts
    commands/
      CreateNodeCommand.ts
      UpdateNodeCommand.ts
      DeleteNodeCommand.ts
      CreateEdgeCommand.ts
      DeleteEdgeCommand.ts
      MoveSelectionCommand.ts
      ResizeNodeCommand.ts
      RotateNodeCommand.ts
      SetViewportCommand.ts
  runtime/
    ToolController.ts
    InteractionEngine.ts
    ViewportController.ts
    RenderScheduler.ts
    HotkeyManager.ts
  renderer/
    CanvasRenderer.ts
    LayerManager.ts
    layers/
      PaperLayerCanvas.ts
      GridLayerCanvas.ts
      EdgeLayerCanvas.ts
      NodeLayerCanvas.ts
      InteractionLayerCanvas.ts
    routing/
      OrthogonalRouter.ts
      BezierRouter.ts
    hit-testing/
      NodeHitTester.ts
      PortHitTester.ts
      EdgeHitTester.ts
  extensions/
    registry/
      NodeRegistry.ts
      ToolRegistry.ts
      InspectorRegistry.ts
    nodes/
      markdown/
        MarkdownNodeDefinition.ts
        MarkdownNodePreview.tsx
        FloatingMarkdownEditor.tsx
      shape/
        ShapeNodeDefinition.ts
      text/
        TextNodeDefinition.ts
      image/
        ImageNodeDefinition.ts
      group/
        GroupNodeDefinition.ts
      frame/
        FrameNodeDefinition.ts
  tools/
    select/
      SelectTool.ts
    hand/
      HandTool.ts
    edge/
      EdgeTool.ts
      EdgeValidationPresenter.ts
    freehand/
      FreehandTool.ts
    text/
      TextTool.ts
    shape/
      ShapeTool.ts
  ui/
    shell/
      CanvasShell.tsx
      CanvasStage.tsx
    hud/
      TopToolbar.tsx
      LeftToolRail.tsx
      RightInspectorPanel.tsx
      BottomStatusBar.tsx
      MiniMapPanel.tsx
    overlays/
      SelectionOverlay.tsx
      AlignmentGuideOverlay.tsx
      EdgeWarningOverlay.tsx
      FloatingWindowHost.tsx
    inspector/
      NodeInspector.tsx
      EdgeInspector.tsx
      DocumentInspector.tsx
  serialization/
    WhiteboardCodec.ts
    WhiteboardSchema.ts
    WhiteboardMigrate.ts
  services/
    AutosaveService.ts
    ExportService.ts
    ClipboardService.ts
  constants/
    ToolIds.ts
    ZIndex.ts
    DefaultTheme.ts
  tests/
    model/
    store/
    runtime/
    renderer/
    e2e/

src/view/whiteboard/
  View.tsx
  Composer.tsx
  container/
    WhiteboardPage.tsx
    WhiteboardPageShell.tsx
```

## 12. 节点扩展 API

```ts
export interface ICanvasNodeDefinition<TData extends Record<string, unknown>> {
  readonly type: string
  readonly displayName: string
  readonly createDefaultNode: () => ICanvasNode
  readonly validateData: (data: unknown) => TData
  readonly getPorts: (node: ICanvasNode) => ReadonlyArray<ICanvasPort>
  readonly renderCanvas: (ctx: CanvasRenderingContext2D, node: ICanvasNode) => void
  readonly renderOverlay?: (node: ICanvasNode) => React.ReactNode
  readonly getInspectorSchema?: () => ReadonlyArray<IInspectorField>
}

export interface IInspectorField {
  readonly key: string
  readonly label: string
  readonly control: 'text' | 'number' | 'color' | 'switch' | 'select'
}
```

## 13. 序列化协议

存储与自动保存策略不在本文件展开，统一见 `spec/whiteboard/storage.md`。

### 13.1 文件形态

- 文件扩展名：`.whiteboard`
- 文件内容：UTF-8 JSON

### 13.2 图片资源引用约定

- 图片节点 `data.src` 仅使用外链，不内嵌二进制数据。
- 支持两类地址：
  - 绝对 URL：`https://...` / `http://...`
  - 相对路径：`./assets/diagram.png`、`../images/a.png`
- 相对路径解析基准：当前 `.whiteboard` 文件所在目录。
- 未保存的新文档使用工作区根目录作为相对路径解析基准。
- 加载失败时节点进入 `warn` 状态并显示占位图。

### 13.3 示例

```json
{
  "kind": "yoz.whiteboard",
  "id": "doc-Q7mX2pL9aK3r",
  "schemaVersion": 1,
  "version": 12,
  "meta": {
    "title": "Product Roadmap",
    "description": "Q3 planning",
    "createdAt": 1760000000000,
    "updatedAt": 1760001000000
  },
  "graph": {
    "schemaVersion": 1,
    "viewport": {
      "zoom": 1,
      "offsetX": 0,
      "offsetY": 0,
      "gridSize": 20,
      "showGrid": true
    },
    "edgeOrder": [],
    "nodesById": {},
    "portsById": {},
    "edgesById": {},
    "edgeIdsByPortId": {}
  }
}
```

图片节点示例（外链）：

```json
{
  "id": "node-mP8vN2qR4xT1",
  "type": "image",
  "dimension": {
    "x": 240,
    "y": 120,
    "width": 320,
    "height": 180
  },
  "transform": {
    "rotation": 0,
    "scaleX": 1,
    "scaleY": 1
  },
  "zIndex": 0,
  "locked": false,
  "hidden": false,
  "style": {
    "strokeColor": "#d1d5db",
    "fillColor": "#ffffff",
    "strokeWidth": 1,
    "strokeStyle": "solid",
    "roughness": 0,
    "opacity": 1,
    "cornerRadius": 8
  },
  "data": {
    "src": "./assets/architecture.png",
    "fit": "cover"
  },
  "portIds": [],
  "createdAt": 1760000000000,
  "updatedAt": 1760000000000
}
```

## 14. 三个具体例子（含对比）

### 例子 1：知识图谱（Markdown + Shape）

- 形态：Markdown 节点承载正文，Shape 节点做主题分类。
- 对比：无类型连接时会出现任意乱连；强类型后只允许语义合法连接。

### 例子 2：流程图（Decision 节点）

- 形态：Decision 节点输出 `yes/no` 两个 output port。
- 对比：无方向约束时回路易错；有方向约束后流程始终可读。

### 例子 3：数据血缘图（Table 节点）

- 形态：字段级 port 连线。
- 对比：弱校验只能事后发现问题；强校验可在拖拽时即时阻断错误。

推荐：三个场景统一采用 `CanvasNode/Port/Edge`，不再出现任何特例连线系统。

## 15. 性能基准场景（固定样本）

### 15.1 Baseline-S（常规画布）

- 数据规模：`200 nodes + 400 edges`。
- 操作序列：pan 10s、zoom in/out 10 次、框选拖拽 20 次、创建连线 50 次。
- 验收阈值：
  - 平均帧率 >= `55 FPS`（1080p）。
  - 单次交互延迟 P95 <= `16ms`。

### 15.2 Baseline-L（重负载画布）

- 数据规模：`1000 nodes + 2000 edges`。
- 操作序列：pan 10s、缩放 10 次、节点拖拽 20 次、视口 fit-to-content 5 次。
- 验收阈值：
  - 平均帧率 >= `30 FPS`（1080p）。
  - 单次交互延迟 P95 <= `33ms`。

### 15.3 基准资产与执行

- 基准数据文件建议落在：`tests/e2e/benchmarks/fixtures/`。
- 基准脚本建议落在：`tests/e2e/benchmarks/`。
- 每次渲染层或命中测试改动后必须回归两档 baseline。

## 16. 设计阶段里程碑（先设计后实现）

### D1：域模型与协议定稿

- 定稿 model interfaces、validation contract、`.whiteboard` schema。
- 定稿 `spec/whiteboard/storage.md` 中的 autosave 与恢复策略。

### D2：交互规范定稿

- 定稿 tool 行为、快捷键、floating editor 生命周期、warning 呈现方式。

### D3：组件结构定稿

- 定稿目录、模块边界、渲染层职责、service 边界。

### D4：测试策略定稿

- 定稿单测边界、集成测试关键路径、e2e 最小场景。
- 定稿 `Baseline-S / Baseline-L` 自动回归流程。

说明：完成 D1-D4 之前不进入大规模实现。
