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
- warning 不写入历史动作本身，而写入 edge 当前校验状态。

### 8.1 Validation Code（v1，直观命名）

```ts
export type IValidationCode =
  | 'CONNECT_DIRECTION_NOT_ALLOWED'
  | 'CONNECT_TYPE_NOT_COMPATIBLE'
  | 'CONNECT_TARGET_PORT_FULL'
  | 'CONNECT_SELF_LOOP_NOT_ALLOWED'
  | 'NODE_REQUIRED_PORT_UNCONNECTED'
  | 'IMAGE_SOURCE_UNREACHABLE'
```

命名规则：

- 前缀体现领域：`CONNECT` / `NODE` / `IMAGE`。
- 谓语体现结果：`NOT_ALLOWED` / `NOT_COMPATIBLE` / `FULL` / `UNREACHABLE`。
- 不使用内部实现术语，确保产品、前端、测试都能直读。

### 8.2 `error` 与 `warn` 映射

- `CONNECT_DIRECTION_NOT_ALLOWED`：`error`
- `CONNECT_TYPE_NOT_COMPATIBLE`：`error`
- `CONNECT_TARGET_PORT_FULL`：`error`
- `CONNECT_SELF_LOOP_NOT_ALLOWED`：`error`
- `NODE_REQUIRED_PORT_UNCONNECTED`：`warn`
- `IMAGE_SOURCE_UNREACHABLE`：`warn`

### 8.3 文案映射示例

- `CONNECT_DIRECTION_NOT_ALLOWED` -> "连接方向不合法：请从 output 连接到 input"。
- `CONNECT_TYPE_NOT_COMPATIBLE` -> "连接类型不匹配：源端口输出类型与目标端口输入类型不兼容"。
- `CONNECT_TARGET_PORT_FULL` -> "目标端口连接数已达上限"。
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
