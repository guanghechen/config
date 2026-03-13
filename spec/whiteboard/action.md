# Whiteboard Action 设计

## 1. 目标

- 定义 Whiteboard 的 Action/Command 统一执行模型。
- 保证所有可见变更可回放、可撤销、可重做。
- 让交互层（tool）与状态层（store）解耦。

## 2. 核心原则

- 所有写操作必须进入 `CommandBus`。
- `Tool` 只产生 Action，不直接改写 `SceneStore`。
- Command 必须是 deterministic（同输入同输出）。
- 历史记录按 transaction 聚合，避免拖拽噪音。

## 3. 模型

```ts
export interface IAction<TPayload = unknown> {
  readonly type: string
  readonly payload: TPayload
  readonly meta?: {
    readonly source: 'tool' | 'shortcut' | 'inspector' | 'system'
    readonly timestamp: number
    readonly transactionId?: string
  }
}

export interface ICommand {
  readonly type: string
  do(ctx: ICommandContext): void
  undo(ctx: ICommandContext): void
  redo(ctx: ICommandContext): void
  canMerge?(next: ICommand): boolean
  merge?(next: ICommand): ICommand
}
```

## 4. 流程

```text
Pointer/Keyboard
  -> Tool
  -> Action
  -> ActionReducer (Action -> Command)
  -> CommandBus.execute()
  -> SceneStore mutate
  -> HistoryStore push(transaction)
  -> Renderer invalidate layers
```

### 4.1 Compute Event Queue

```ts
export type IComputeEventType =
  | 'EDGE_DRAG_VALIDATE'
  | 'NODE_GEOMETRY_CHANGED'
  | 'PORT_CONFIG_CHANGED'
  | 'NODE_STATUS_CHANGED'
  | 'EDGE_CREATED_OR_REMOVED'
  | 'REVALIDATE_SCOPE'
  | 'REVALIDATE_ALL'
  | 'REBUILD_GRAPH_INDEX'
  | 'SYNC_RUNTIME_FLAGS'

export type IComputePriority = 'realtime' | 'high' | 'normal' | 'idle'

export interface IComputeEventFrom {
  readonly source:
    | 'tool'
    | 'inspector'
    | 'shortcut'
    | 'command_bus'
    | 'storage_recovery'
    | 'importer'
    | 'system'
  readonly activeId?: string
  readonly commandId?: string
  readonly traceId: string
}

export interface IComputeEvent<TPayload = unknown> {
  readonly id: string
  readonly type: IComputeEventType
  readonly priority: IComputePriority
  readonly key: string
  readonly payload: TPayload
  readonly from: IComputeEventFrom
  readonly createdAt: number
}

export type IComputeCoalesceStrategy =
  | 'replace-latest'
  | 'merge-set'
  | 'drop-others-and-run-once'

export interface IComputeEventSpec<TPayload = unknown> {
  readonly key: (payload: TPayload, from: IComputeEventFrom) => string
  readonly coalesce: IComputeCoalesceStrategy
}

export interface IComputeEventCatalog {
  readonly EDGE_DRAG_VALIDATE: IComputeEventSpec<{
    readonly fromNodeId: string
    readonly fromPortId: string
    readonly pointerCanvasX: number
    readonly pointerCanvasY: number
    readonly candidateToNodeId?: string
    readonly candidateToPortId?: string
  }>
  readonly NODE_GEOMETRY_CHANGED: IComputeEventSpec<{
    readonly nodeId: string
    readonly dimension: ICanvasNodeDimension
    readonly transform: ICanvasNodeTransform
  }>
  readonly PORT_CONFIG_CHANGED: IComputeEventSpec<{
    readonly nodeId: string
    readonly portId: string
    readonly placement: ICanvasPortPlacement
    readonly offsetRatio?: number
    readonly anchor?: ICanvasPortAnchor
    readonly accepts: ReadonlyArray<string>
    readonly emits: ReadonlyArray<string>
  }>
  readonly NODE_STATUS_CHANGED: IComputeEventSpec<{
    readonly nodeId: string
    readonly status: ICanvasNodeStatus
  }>
  readonly EDGE_CREATED_OR_REMOVED: IComputeEventSpec<{
    readonly edgeId: string
    readonly operation: 'create' | 'remove'
    readonly fromNodeId: string
    readonly toNodeId: string
  }>
  readonly REVALIDATE_SCOPE: IComputeEventSpec<{
    readonly nodeIds?: ReadonlyArray<string>
    readonly edgeIds?: ReadonlyArray<string>
    readonly portIds?: ReadonlyArray<string>
    readonly reason: 'command' | 'queue-merge' | 'import'
  }>
  readonly REVALIDATE_ALL: IComputeEventSpec<{
    readonly reason: 'load' | 'import' | 'recovery' | 'manual'
  }>
  readonly REBUILD_GRAPH_INDEX: IComputeEventSpec<{
    readonly reason: 'load' | 'import' | 'integrity-check'
  }>
  readonly SYNC_RUNTIME_FLAGS: IComputeEventSpec<{
    readonly nodeIds?: ReadonlyArray<string>
    readonly edgeIds?: ReadonlyArray<string>
    readonly reason: 'selection' | 'hover' | 'tool-switch'
  }>
}
```

队列策略：

- `EDGE_DRAG_VALIDATE` 走 realtime 通道，拖拽期间每帧重算。
- 其余事件进入优先级队列，按 `high -> normal -> idle` 出队。
- 同 `key` 事件只保留最后一条（coalesce）。
- 单帧使用固定预算处理队列（建议 `2~4ms`），避免阻塞渲染。
- 批量变更结束时允许压入 `REBUILD_GRAPH_INDEX` + `REVALIDATE_ALL` 作为收敛事件。

### 4.2 Key 与 Coalesce 约定（已确认）

- `EDGE_DRAG_VALIDATE`：`key = EDGE_DRAG_VALIDATE:{from.activeId}`，`coalesce = replace-latest`。
- `NODE_GEOMETRY_CHANGED`：`key = NODE_GEOMETRY_CHANGED:{nodeId}`，`coalesce = replace-latest`。
- `PORT_CONFIG_CHANGED`：`key = PORT_CONFIG_CHANGED:{portId}`，`coalesce = replace-latest`。
- `NODE_STATUS_CHANGED`：`key = NODE_STATUS_CHANGED:{nodeId}`，`coalesce = replace-latest`。
- `EDGE_CREATED_OR_REMOVED`：`key = EDGE_CREATED_OR_REMOVED:{edgeId}`，`coalesce = replace-latest`。
- `REVALIDATE_SCOPE`：`key = REVALIDATE_SCOPE`，`coalesce = merge-set`（并集 nodeIds/edgeIds/portIds）。
- `REVALIDATE_ALL`：`key = REVALIDATE_ALL`，`coalesce = drop-others-and-run-once`。
- `REBUILD_GRAPH_INDEX`：`key = REBUILD_GRAPH_INDEX`，`coalesce = drop-others-and-run-once`。
- `SYNC_RUNTIME_FLAGS`：`key = SYNC_RUNTIME_FLAGS`，`coalesce = replace-latest`。

## 5. Command 分类

- Node：`CreateNode` / `UpdateNode` / `DeleteNode` / `MoveNode` / `ResizeNode` / `RotateNode`。
- Edge：`CreateEdge` / `UpdateEdge` / `DeleteEdge` / `RerouteEdge`。
- Selection：`SetSelection` / `ClearSelection` / `SelectByLasso`。
- Viewport：`PanViewport` / `ZoomViewport` / `FitViewport`。
- Structure：`GroupNodes` / `UngroupNodes` / `SetNodeZIndex` / `BringForward` / `SendBackward` / `BringToFront` / `SendToBack`。
- Clipboard：`PasteNodes` / `DuplicateSelection`。

## 6. Transaction 规则

- pointer down 时 `beginTransaction`。
- pointer move 产生的连续 Move/Resize/Rotate 命令可 merge。
- pointer up 时 `commitTransaction`。
- `Esc` 或操作取消时 `rollbackTransaction`。

## 7. 历史策略

- `undo` 回滚最近一个 transaction。
- `redo` 仅在无新写操作时可继续前进。
- 历史栈默认上限：`100` transactions。
- 超限后丢弃最旧 transaction。

## 8. Validation 与 Warning

- edge 创建时先做 validation，再产生命令。
- `error`：阻断命令执行。
- `warn`：命令可执行，但在 edge 上保留 warning 标记。
- warning 不写入历史动作，也不写入持久化文档；仅存在于 runtime edge state。
- 文档加载后必须执行全量 revalidate，恢复 warning 可视状态。

### 8.1 Validation Code（v1，直观命名）

```ts
export type IValidationCode =
  | 'CONNECT_DIRECTION_NOT_ALLOWED'
  | 'CONNECT_TYPE_NOT_COMPATIBLE'
  | 'CONNECT_TARGET_PORT_FULL'
  | 'CONNECT_SELF_LOOP_NOT_ALLOWED'
  | 'PORT_OFFSET_RATIO_OUT_OF_RANGE'
  | 'PORT_OFFSET_RATIO_REQUIRED_FOR_EDGE_PLACEMENT'
  | 'PORT_OFFSET_RATIO_NOT_ALLOWED_FOR_CUSTOM_PLACEMENT'
  | 'PORT_ANCHOR_RATIO_OUT_OF_RANGE'
  | 'PORT_ANCHOR_REQUIRED_FOR_CUSTOM_PLACEMENT'
  | 'PORT_ANCHOR_NOT_ALLOWED_FOR_EDGE_PLACEMENT'
  | 'NODE_STATUS_VISIBILITY_INVALID'
  | 'NODE_REQUIRED_PORT_UNCONNECTED'
  | 'IMAGE_SOURCE_UNREACHABLE'
```

命名规则：

- 前缀体现领域：`CONNECT` / `PORT` / `NODE` / `IMAGE`。
- 谓语体现结果：`NOT_ALLOWED` / `NOT_COMPATIBLE` / `FULL` / `UNREACHABLE`。
- 不使用内部实现术语，确保产品、前端、测试都能直读。

### 8.2 `error` 与 `warn` 映射

- `CONNECT_DIRECTION_NOT_ALLOWED`：`error`
- `CONNECT_TYPE_NOT_COMPATIBLE`：`error`
- `CONNECT_TARGET_PORT_FULL`：`error`
- `CONNECT_SELF_LOOP_NOT_ALLOWED`：`error`
- `PORT_OFFSET_RATIO_OUT_OF_RANGE`：`error`
- `PORT_OFFSET_RATIO_REQUIRED_FOR_EDGE_PLACEMENT`：`error`
- `PORT_OFFSET_RATIO_NOT_ALLOWED_FOR_CUSTOM_PLACEMENT`：`error`
- `PORT_ANCHOR_RATIO_OUT_OF_RANGE`：`error`
- `PORT_ANCHOR_REQUIRED_FOR_CUSTOM_PLACEMENT`：`error`
- `PORT_ANCHOR_NOT_ALLOWED_FOR_EDGE_PLACEMENT`：`error`
- `NODE_STATUS_VISIBILITY_INVALID`：`error`
- `NODE_REQUIRED_PORT_UNCONNECTED`：`warn`
- `IMAGE_SOURCE_UNREACHABLE`：`warn`

### 8.3 文案映射示例

- `CONNECT_DIRECTION_NOT_ALLOWED` -> "连接方向不合法：请从 output 连接到 input"。
- `CONNECT_TYPE_NOT_COMPATIBLE` -> "连接类型不匹配：源端口输出类型与目标端口输入类型不兼容"。
- `CONNECT_TARGET_PORT_FULL` -> "目标端口连接数已达上限"。
- `PORT_OFFSET_RATIO_OUT_OF_RANGE` -> "端口 offsetRatio 超出范围：应在 0~1 之间"。
- `PORT_OFFSET_RATIO_REQUIRED_FOR_EDGE_PLACEMENT` -> "边缘端口缺少 offsetRatio：top/right/bottom/left 必须提供"。
- `PORT_OFFSET_RATIO_NOT_ALLOWED_FOR_CUSTOM_PLACEMENT` -> "custom 端口不应提供 offsetRatio：请改用 anchor"。
- `PORT_ANCHOR_RATIO_OUT_OF_RANGE` -> "端口 anchor 超出范围：xRatio/yRatio 应在 0~1 之间"。
- `PORT_ANCHOR_REQUIRED_FOR_CUSTOM_PLACEMENT` -> "custom 端口缺少 anchor：请提供 xRatio/yRatio"。
- `PORT_ANCHOR_NOT_ALLOWED_FOR_EDGE_PLACEMENT` -> "边缘端口不应提供 anchor：请改用 offsetRatio"。
- `NODE_STATUS_VISIBILITY_INVALID` -> "节点 visibility 非法：仅允许 visible 或 hidden"。
- `IMAGE_SOURCE_UNREACHABLE` -> "图片资源暂时不可访问，已保留引用"。

## 9. Tool 责任边界

- `SelectTool`：只负责命中、框选、拖拽意图生成。
- `EdgeTool`：负责连接拖拽与实时 validation 反馈。
- `MarkdownTool`：负责创建节点与唤起 floating editor。
- `HandTool`：只负责视口平移 action。

## 10. 快捷键映射

- `Cmd/Ctrl + Z`：`undo`。
- `Cmd/Ctrl + Shift + Z`：`redo`。
- `Delete/Backspace`：删除选中节点/边。
- `Cmd/Ctrl + D`：duplicate selection。
- `Space`：临时切换 hand tool。

## 11. 测试重点

- 同一拖拽过程只入栈一个 transaction。
- `undo -> redo` 后文档快照与执行前一致。
- validation 为 `error` 时不得产生新 edge。
- validation 为 `warn` 时允许保存且 warning 持续可见。
- 文档 reload 后会重跑 validation，warning 状态与当前规则一致。
- `offsetRatio` / `anchor` 越界或互斥冲突时必须返回 `error`。
- `status.visibility` 非法值必须返回 `error`。
