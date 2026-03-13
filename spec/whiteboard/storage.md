# Whiteboard Storage 设计

## 1. 目标

- 明确 `.whiteboard` 文档持久化策略。
- 保障编辑过程低丢失风险。
- 将 autosave 与手动保存职责分离。

## 2. 存储分层

- `Draft Storage`：浏览器本地草稿（快速、频繁、可恢复）。
- `File Storage`：用户文件系统中的 `.whiteboard` 文件（权威版本）。

说明：

- Draft 解决“异常关闭丢失编辑中状态”。
- File 解决“跨会话、可共享、可版本管理”。

持久化边界：

- 仅持久化 `IWhiteboardDocumentData`。
- `ICanvasGraph.index`、`ICanvasNode/Port/Edge.runtime` 不写入存储。
- edge validation 仅运行时计算，加载后重算。

### 2.1 Draft Key 策略（已确认）

- 主键：`draft:{workspaceId}:{docId}`。
- 路径索引：`draft-index:path:{normalizedFilepath}` -> `draft:{workspaceId}:{docId}`。
- metadata 索引：`draft-index:updatedAt:{docId}` 用于最近草稿恢复排序。
- `docId` 格式：`doc-{nanoid}`（例如 `doc-Q7mX2pL9aK3r`）。

说明：

- 使用 `workspaceId + docId` 作为主键，避免文件改名导致草稿丢失。
- 路径索引用于“按当前文件路径快速定位草稿”。
- 文档首次未保存时，先分配 `docId`，随后路径变化只更新索引，不迁移草稿主体。

## 3. Autosave 策略（已确认）

### 3.1 Draft Autosave

- 触发：文档有可见变更。
- 节流：`debounce 800ms`。
- 目标：本地草稿存储。
- 内容：完整 `IWhiteboardDocumentData` 快照 + `updatedAt`。

### 3.2 File Autosave

- 前提：当前文档已绑定文件句柄（可写）。
- 触发：最近一次变更后进入空闲期。
- 节流：`idle 3s`。
- 目标：写回 `.whiteboard` 文件。

### 3.3 生命周期 Flush

- `beforeunload`：强制 flush draft + file save queue。
- `blur`：强制 flush draft。
- `visibilitychange(hidden)`：强制 flush draft。

## 4. 恢复策略

- 应用启动时，优先检测 Draft 是否比 File 更新。
- 若 Draft 更新，提示用户选择：
  - 恢复草稿
  - 丢弃草稿并加载文件
- 恢复后立即进入新会话，草稿继续覆盖写入。

## 5. 失败处理

- Draft 写入失败：显示非阻断 warning，继续编辑。
- File 写入失败：显示持续告警，保留“重试保存”入口。
- 保存失败不回滚内存状态，只影响持久化状态。

## 6. 图片资源策略

- 图片节点 `payload.src` 只保存外链引用。
- 支持 `http(s)` URL 和相对路径。
- 相对路径解析基准：
  - 已保存文档：`.whiteboard` 文件所在目录。
  - 未保存文档：工作区根目录。

## 7. 数据结构建议

```ts
export interface IWhiteboardDraftRecord {
  readonly docId: string
  readonly workspaceId: string
  readonly filepath?: string
  readonly updatedAt: number
  readonly snapshot: IWhiteboardDocumentData
}

export interface IStorageStatus {
  readonly draftState: 'idle' | 'saving' | 'saved' | 'error'
  readonly fileState: 'idle' | 'saving' | 'saved' | 'error'
  readonly lastDraftSavedAt?: number
  readonly lastFileSavedAt?: number
  readonly lastErrorMessage?: string
}
```

## 8. 与 Action 层的关系

- `CommandBus` 提交 transaction 后发出 `DocumentChanged` 事件。
- `AutosaveService` 订阅该事件并执行 draft/file 保存调度。
- `StorageStatus` 反馈到 HUD 状态栏。

## 9. 测试重点

- 连续高频操作下，Draft 保存频率符合 `800ms debounce`。
- 文件句柄可用时，File autosave 在空闲 `3s` 内触发。
- `beforeunload` 能触发 flush。
- Draft 新于 File 时恢复提示出现且行为正确。
