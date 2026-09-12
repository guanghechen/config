# Agent interface

白板通过文件和结构化数据与外部 agent 配合，不内置 AI provider，也不提供多人协作服务。Node 24+ 可直接执行 CLI，无需安装额外 package。

## 契约

- 文档：[`document.schema.json`](document.schema.json)，`kind: "yoz.whiteboard"`、`schemaVersion: 1`。
- 批量命令：[`commands.schema.json`](commands.schema.json)，`kind: "yoz.whiteboard.commands"`、`schemaVersion: 1`、目标 `documentId` 和最多 1000 条 `commands`。
- 权威运行时校验：`shared/whiteboard/document.ts`；除 schema 结构外，还验证唯一元素 ID、连接引用、坐标与大小限制。文档序列化上限 30 MB，文字/内嵌图片 URL 上限 2 MB。
- 元素 ID 在移动、内容更新和重排后保持不变；agent 创建元素时指定非空且唯一的 ID。普通文档的未知字段保留，命令对象拒绝未知字段，避免拼写错误被静默忽略。
- `update.patch` 不能改 `id` 或 `type`；`style` 按属性合并，其余顶层字段替换。删除字段应通过编辑完整文档表达，不把 `null` 当作删除指令。
- `remove` 精确删除指定 ID，并删除依赖被删节点的连线。`move`、`group`、`ungroup`、`arrange`、`reorder` 沿用界面的整组语义。分组 ID 不能占用未选中元素已有的组。
- 批次完全成功才产生结果；最终校验允许连线引用同一批次中稍后添加的节点。无变化的批次不写文件、不创建历史。
- 枚举必须使用字符串，例如 `shape: "rectangle"`、`mode: "start"`、`order: "front"`；单元素数组也会被拒绝。`move.delta` 的每个坐标必须在 ±10000000 内，即使移动后的坐标合法也不能超出该范围。

## CLI

从 repository 根目录运行：

```sh
node scripts/whiteboard.mjs create /absolute/path/board.whiteboard --title "System design"
node scripts/whiteboard.mjs inspect /absolute/path/board.whiteboard
node scripts/whiteboard.mjs validate /absolute/path/board.whiteboard
node scripts/whiteboard.mjs apply /absolute/path/board.whiteboard --commands /absolute/path/batch.json --dry-run
node scripts/whiteboard.mjs apply /absolute/path/board.whiteboard --commands /absolute/path/batch.json --revision "REVISION_FROM_INSPECT"
```

`inspect` 返回完整文档与当前 revision；`validate` 返回 document ID、元素数量和 revision。`apply --dry-run` 返回预计文档及 revision，完全不写文件。实际 `apply` 必须携带读取时的 revision；冲突后重新读取并重新规划，不能盲目覆盖。

创建文件要求父目录已存在；已存在的文件或 symlink 不会被覆盖。读取/修改已存在文件时使用 canonical path。CLI 遵循当前进程的文件系统权限；Web UI 的文件访问仍单独受服务端鉴权和 allowed roots 限制，CLI 成功不代表该路径可以被 Web UI 读取。

成功在 stdout 返回 JSON，含 `ok: true`、路径和 revision。失败在 stderr 返回 `{"ok":false,"error":"..."}` 并使用非零 exit code。不得把 stderr 或失败 exit code 忽略后继续后续编辑。

## 批次示例

将 `documentId` 替换为 `inspect` 返回的文档 ID；已有 `service-api` 时使用 `update`，不要重复 `add`：

```json
{
  "kind": "yoz.whiteboard.commands",
  "schemaVersion": 1,
  "documentId": "DOCUMENT_ID_FROM_INSPECT",
  "commands": [
    {
      "op": "add",
      "elements": [
        {
          "id": "service-api",
          "type": "shape",
          "shape": "rectangle",
          "label": "API service",
          "x": 320,
          "y": 200,
          "width": 220,
          "height": 120,
          "style": {
            "stroke": "theme:ink",
            "fill": "theme:paper",
            "strokeWidth": 2,
            "roughness": 2
          }
        }
      ]
    },
    {
      "op": "update",
      "id": "service-api",
      "patch": { "style": { "fill": "theme:blue" } }
    }
  ]
}
```

| op | 参数 | 行为 |
| --- | --- | --- |
| `set-title` | `title` | 修改文档标题 |
| `add` | `elements` | 追加完整元素；最终验证 ID 和引用 |
| `update` | `id`, `patch` | 修改指定元素，局部合并 style |
| `remove` | `ids` | 删除指定元素及依赖它们的连线 |
| `move` | `ids`, `delta: {x, y}` | 平移选中元素及其组 |
| `group` | `ids`, `groupId` | 合并为一个扁平组 |
| `ungroup` | `ids` | 取消所涉及组的分组 |
| `arrange` | `ids`, `axis`, `mode` | x/y 轴 start/center/end/distribute 布局 |
| `rotate` | `ids`, `degrees` | 绕选区轴旋转，单端绑定线以绑定端点为轴 |
| `flip` | `ids`, `axis` | 沿世界 x/y 轴镜像选区 |
| `set-flags` | `ids`, `locked?`, `hidden?`（至少一个） | 显式锁定/隐藏或恢复整组 |
| `set-regions` | `regions` | 原子替换命名区域列表 |
| `set-presentation` | `steps` | 替换演示步骤的区域 ID 列表，允许重复 |
| `reorder` | `ids`, `order` | back/backward/forward/front 顺序调整 |

## 文件驱动展示

在 `/whiteboard?filepath=...` 打开 `.whiteboard` 后，页面接收文件变更事件，并以 2.5 秒轮询和重新聚焦刷新补偿缺失事件。外部 agent 可直接编辑有效 JSON，或使用 CLI 应用命令批次。

- 当前文档未被本地修改，且没有活跃鼠标/键盘手势或编辑器时，自动载入新版本；镜头保留，历史以新文件版本为基线重置。
- 有本地改动或活跃编辑时保留当前内容，显示源文件更新提示。可先导出本地版本，再显式重新加载；保存仍检查原 revision，不能覆盖外部新版本。
- 外部文件暂时不完整、JSON 无效、引用不合法或读取失败时，保留最后有效场景并显示错误；文件修复后继续刷新。
- 通过 `BoardStore.applyCommands` 接入批次时，一批对应一条本地 undo。CLI 的外部文件更新采用上面的新文件基线语义，不混入本地编辑器的文本 undo。

服务端写入队列只协调本应用进程；其他编辑器不共享锁。CLI 的 revision 检查与临时文件替换仍不能被描述为跨进程的绝对 compare-and-swap。

## Connector data

连线可设置 `routing: straight | polyline | curve`、`arrowStart` / `arrowEnd: none | arrow` 和 `lineStyle: solid | dashed | dotted`。缺省为直线、仅终点箭头和实线。

绑定端点的 `nodeId` 必须为现有节点的非空 ID；自由端点省略 `nodeId`，不要使用空字符串。

`controls` 是世界坐标数组：折线 0–64 个，曲线恰好两个；缺省表示自动路线。移动/复制/布局/拉伸显式选中的连线时同步变换控制点，未选中连线的手工控制点保留原位。绑定端点继续跟随其节点。`update` 修改 routing 时自动清除旧控制点，除非 patch 同时给出新的 controls。

## Typography data

`style.fontSize` 支持 8–200，`fontFamily` 为 hand/sans/mono，`fontWeight` 为 normal/bold，`textAlign` 为 left/center/right。这些字段用于普通文字和图形/连线标签；Markdown 使用正文中的排版语义。

text/shape 可设置 `autoSize: true`。浏览器按实际字体测量并更新尺寸，修改内容/样式、载入外部文件与恢复草稿遵循相同规则。宽高在此模式下是布局提示；CLI 不加载浏览器字体，arrange 等命令使用序列化尺寸。需要精确固定几何时，设 autoSize:false 并提供宽高。update 显式改变宽高会关闭 autoSize，除非 patch 同时包含 autoSize:true。

## Node pose

节点支持 rotation（度数）、flipX/flipY。x/y 是未旋转的局部盒位置；先围绕盒中心应用局部镜像，再旋转。rotate/flip 命令扩展整组，变换节点中心、自由端点和控制点，保留外部绑定。原始 flipX/flipY 属性是局部镜像；flip 命令是世界轴镜像，会相应调整 rotation。

自动尺寸变化保持变换后的局部原点；旋转/翻转不关闭 autoSize。显式拉伸仍关闭自动尺寸。连线通过变换坐标表达姿态，不使用节点的 rotation/flip 字段。

## Protection and visibility

元素可设置 locked/hidden（boolean，缺省 false）。组内任一成员 locked 即保护整组；锁定禁止修改内容、几何、样式、分组与自身顺序，允许复制、导出、显式隐藏或解锁。隐藏节点会同时隐藏 incident edges；连线自身 hidden 仍独立保留。

set-flags 扩展整组；update.patch 的 flags 只作用于指定元素。保护状态下 update 只允许 flags，不可在同一 patch 中解锁并编辑；使用同一 batch 的 set-flags 解锁，再执行后续编辑。add/update 不允许加入已锁定组。remove 删除依赖连线前也检查保护，避免通过删节点间接删除锁定连线。绑定连线自身坐标没有变化时仍可跟随未锁定节点移动。

外部完整文件是新的文档基线，可显式重写 flags；这些保护是编辑操作契约，不是文件系统访问权限。打开的右键菜单也算活跃交互，外部更新会延后载入。


## Stacking order

新文档使用 `stacking: "document"`，`elements` 从后向前排列，所有元素类型共享同一顺序。`reorder` 跨类型移动，仍扩展整组并保持成员相对顺序。

缺少 stacking 的旧 v1 文件沿用三层含义：连线、绘图、富内容卡片；UI 载入和 CLI apply 先稳定排序以保留旧视觉，再写入 stacking 标记。`inspect`/`validate` 不改文件。外部 agent 若希望直接控制数组顺序，应显式设置 stacking:document。

## Named areas and presentation

`regions` 为可选数组（最多 1000 项），每项包含非空 `id`（最多 128 字符）、`name`（最多 256 字符）和世界坐标 `x/y/width/height`；尺寸为正，数值限制与节点一致。区域 ID 使用独立命名空间，不改变元素分组或顺序。

`presentation` 为可选的区域 ID 数组（最多 5000 步），允许同一区域重复出现；省略时按 regions 顺序演示，显式空数组表示没有步骤。所有步骤必须引用现有区域。删除或替换区域时，agent 应在同一批次中同步设置 presentation；最终引用不合法则整批失败。

UI 新建区域会追加一个步骤；区域可重命名、聚焦、删除，步骤可增删和排序。阅读模式、当前步骤、镜头和激光轨迹均不写入文件，也不占用 undo 历史。演示期间空闲时收到合法外部文件更新，会显示新的区域内容与边界；退出演示恢复进入前的镜头和工具。
