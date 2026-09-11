# Explorer 设计

## 概述

`era.m.explorer` 由 `Tree + View + Widget + Action + FileManager` 组成，内部使用 filepath-only 模型。
路径只在系统边界转换，由 `stl.os.path` / `stl.os.fs` 统一处理；`#` 等文件名字符不具有额外路径语义。

## 路径不变式

1. 内部只使用 `filepath`，不使用 URI。
2. 内部路径分隔符固定为 `/`（Windows 内部同样如此）。
3. 目录路径在内部以 `/` 结尾，文件路径不以 `/` 结尾。
4. 仅在系统边界做一次路径转换（`/` -> OS separator），统一使用 `yoz.canonical_path.to_os_path(...)`。
5. `#` 是普通文件名字符，不参与路径解析语义。
6. `/` 与 `C:/` 视为 root，不再向上回退。

系统边界包括：

- `stl.os.fs.*` 文件系统 facade（推荐）
- `vim.fn.*` / `vim.uv.fs_*` / `vim.system(...)`（若直接调用，调用前必须先 `yoz.canonical_path.to_os_path(...)`）
- `vim.ui.open(...)`
- `vim.cmd("split/tabnew/vsplit ...")`
- `dot.win.open_filepath(...)`

## 模块职责

- `resource/file.lua`：文件系统读写与监听，维护内部路径与 OS 路径的边界转换。
- `tree.lua`：维护树结构、selection、展开状态，并按 `filepath` 定位节点。
- `node.lua`：定义节点结构与路径拼装。
- `view.lua`：计算 line、highlight、diagnostic、Git status 等渲染数据。
- `widget.lua`：管理窗口生命周期与 keymap。
- `action.lua`：执行 open、create、delete、copy、move、rename、paste 等用户动作。
- `nvimbar/component/explorer.lua`：只读消费 canonical root；启动时缓存稳定的 CWD/workspace display context，不写 Explorer state。

## 数据模型

### Node

关键字段：

- `filepath: string`
- `nodename: string`
- `nodetype: "D" | "F"`
- `parent: Node|nil`
- `children: Node[]`
- `selected/expanded/loaded/has_selected`

说明：

- `superroot.filepath = ""`，用于全局树骨架。
- 真实文件系统 root 由普通节点表示，例如 `/` 或 `C:/`。

### Tree

关键状态：

- `_superroot` 与 `_root`
- `o_root_filepath`
- `o_cursor_filepath`

节点的 `selected/has_selected` 只表示显式 selection，不承载文件动作 mode。显式 selection roots
保持 antichain：任意两个 root 之间不存在祖先关系。

### View

`View` 维护 `lnum_to_filepath` 与 `filepath_to_lnum`，并根据显式 selection 与 pending transfer 计算 sign。

### Pending transfer 的归属

`Action` 是 pending transfer 的唯一 owner，状态结构为：

- `mode = "copy" | "move"`
- `sources`：当前 pending source entries
- `source_filepaths`：用于渲染与查询的 filepath set

显式 selection 与 pending sources 是不同集合，pending source 可以独立存在。普通模式 mark 根据请求
类型重建或清空 pending；Visual range selection 在存在 pending transfer 时同步更新 `sources` 并继承
其 mode。所有显式 selection 使用相同的 selected/copy/move sign。`Widget` 只向 `View` 传递状态，集合更新、文件系统写入和状态清理由 `Action` 执行。
Rename 与单项/Visual Delete 成功后，只移除被旧路径覆盖的 pending sources。显式 selection 的批量
Delete 只要删除了至少一项，就清空 selection 与 pending；失败项不保留，需重新选择。

## 关键流程

### 打开文件

1. 从 render 状态获取内部 filepath。
2. 调用 `yoz.canonical_path.to_os_path(...)` 转为 OS 路径。
3. 执行 `open/split/tabnew/vsplit/system-open`。

### 读写文件系统

1. `Action/Tree` 层传入内部 filepath（slash-only）。
2. `FileManager` 在边界通过 `yoz.canonical_path.to_os_path(...)` 做路径转换。
3. 文件系统调用优先走 `stl.os.fs`。
4. 文件系统返回的 OS path 通过 `yoz.canonical_path.from_os_path(..., keep_trailing_slash)` normalize 为内部 filepath。
5. 返回值与节点状态仍保持内部 slash-only。

### 创建路径

1. 用户输入先归一化为内部 slash-only 路径。
2. 内部组合目标路径并更新 tree。
3. 真正 IO 时在 `FileManager` 转 OS 路径。

### Reveal 与 symlink

1. 目标位于当前 root 时，直接按内部 logical filepath 展开并定位。
2. buffer filepath 已被系统 canonicalize 到 root 外时，`FileManager` 尝试通过当前 root 本身或其直接可见
   symlink child 重建 logical filepath；多个 alias 匹配时优先选择 canonical target 最具体的一个。
3. alias 映射成功时保持当前 root；无法映射时才切换到 canonical target 的父目录。

### 移动/复制

记显式 selected roots 为 `S`，当前 focused item 为 `F`，pending transfer 为 `P`。

#### 多选与 mark

`S` 非空即处于 multi selection 模式（只有一个 selected item 也算）；独立的 `P` 不表示进入
multi selection。类型为 `cut | copy | select`：`cut/copy` 分别对应 `P.mode = move/copy`，
`select` 表示有显式 selection 且无 `P`。所有 selected items 共用一个类型。

`m` 是 mark 前缀，单独不绑定动作：`mx/mc/ms` 分别请求 `cut/copy/select`。
记请求类型为 `T`，统一转换规则如下：

- `F` 未选中：将 `F` 加入 `S`，将整个 multi selection 类型切换为 `T`。
- `F` 已选中，当前类型不同于 `T`：保留所有 selected items，只切换类型。
- `F` 已选中，当前类型等于 `T`：取消 `F` 的选择；若它是唯一的 selected item，则退出
  multi selection 并清空 `P`；否则保留其他 selected items 及其类型。
- 每次 mark 后，`cut/copy` 以更新后的 `S` 精确替换 `P.sources`；`select` 清空 `P`。
  不自动提升之前独立存在的 pending sources。
- 延续 Tree 的 antichain 规则：selected directory 覆盖其后代；在后代上取消 selection 时移除
  覆盖它的 selected root；选中祖先会替换已选中的后代 roots。

例如，A/B 均为 `cut`：在 A 上按 `mc` 保留 A/B，并一起切为 `copy`；再次按 `mc` 只取消 A。
只有 A 被选中时，同类型按键退出 multi selection，异类型按键保留 A 并切换类型。

普通模式快捷键：

- `x`：multi selection 下等同 `mx`；否则立即对 `F` 打开 `Move to` prompt。
- `c`：multi selection 下等同 `mc`；否则立即对 `F` 打开 `Copy to` prompt。
- `<Tab>`：始终等同 `ms`，普通模式从 `select` 类型进入 multi selection；multi selection 中
  从 `cut/copy` 切回 `select` 时保留选择，再按才取消当前项。
- `y`：保留直接 stage copy 入口；若 `S` 非空，先加入 `F`，以更新后的 `S` 设置 pending sources；
  否则只以 `{F}` 设置 pending sources，不进入 multi selection。
- `p`：直接粘贴到 focused directory；`F` 为文件时使用其父目录。
- `<Esc>`：清空 `P`，保留显式 selection 并恢复为 `select`。
- `r`：同目录 Rename，只接受单一名称。
- `om`：移动光标项，prompt 默认显示 cwd-relative 的完整路径，相对输入以 cwd 解析。
  文件路径不得以 `/` 结尾，目录路径必须以 `/` 结尾；移动不改变类型。目标是新的完整路径，
  缺失的父目录自动创建，已存在的目标拒绝操作，目录不得移入自身后代。成功后清理旧路径覆盖的
  pending sources 并刷新 tree。
- `d`：有显式 selection 时删除选中项目，否则删除光标项，均需确认。
- `o<CR>`：有显式 selection 时打开选中的文件（跳过目录），否则打开文件或切换光标目录展开状态。
  `o` 单独不绑定动作。旧 `mm/md/mo` 移除，`m` 下仅保留 mark 动作。

Visual mode 的 `y/x` 将“现有显式 selection 与 visual range 的并集”设为新的 pending sources，不修改
显式 selection。Visual `<Tab>` 保留 range selection toggle；首次从 pending 进入 selection 时，先提升
已有 pending sources，再加入 visual range。后续普通模式按上述 mark 契约处理。

Paste 不弹出目标路径或逐项 mapping 预览，focused item 是目标目录的唯一来源。

目标生成规则：

1. 每个 source 独立映射为 `target_dir + basename(source)`，不保留多个 source 的 common ancestor 层级。
2. 不 overwrite；任一目标已存在时，preflight 整批拒绝。
3. source 缺失、多个 source 映射到同一目标或目标目录不存在时，preflight 整批拒绝。
4. 目录不得 copy/move 到自身或后代目录。
5. preflight 通过后逐项执行；Copy 明确返回 `success`、`retryable_failure` 或
   `partial_failure`。`retryable_failure` 表示 final target 不存在，可以保留 source 继续重试；
   `partial_failure` 表示 final target 已存在或状态无法确认，需要用户先处理 target，不作为普通 pending
   重试项。成功项不回滚。
6. 任一项成功或出现 `partial_failure` 后，清空显式 selection，只保留 `retryable_failure` source 为
   pending，并刷新 tree；全部成功时同时清空 pending。

### Copy to 与 Rename

- Copy to 默认显示 cwd-relative 的完整建议目标路径；相对输入以 cwd 解析，绝对路径直接使用。
- Rename 只接受单一名称：不得为空、等于 `.`/`..`，或包含 `/`、`\\`；目标始终位于 source 的当前
  父目录。
- 两者的目标冲突均由 `FileManager` 使用 exclusive filesystem primitive 按 no-overwrite 策略拒绝。
  Copy to 出现 `partial_failure` 时刷新 tree，使 unresolved target 可见。
- Copy failure 不按 pathname 自动删除 target；一旦 exclusive create 成功，后续 transfer/close failure 保留
  target 并返回 `partial_failure`，避免删除 ownership 不明的 concurrent replacement。

## 验证与维护约束

1. 新增路径字段时，命名统一使用 `filepath`。
2. 新增系统调用时，必须先执行 `yoz.canonical_path.to_os_path(...)`，或直接使用 `stl.os.fs`。
3. 测试优先覆盖：
   - `#head`、`a#1.txt`、`a#2.txt`
   - 含空格与中文路径
   - root 边界（`/`、`C:/`）
   - transfer basename 映射、目标冲突、重复目标与目录 self-descendant
   - pending sources 与显式 selection 的独立身份及同步规则
   - Delete/Rename 后 pending sources 的路径级清理
   - `mx/mc/ms` 的类型切换、最后一项取消及 `x/c/Tab` 的模式分派

## 调试建议

1. 路径异常优先检查边界转换是否遗漏。
2. 定位异常优先检查 `filepath_to_lnum/lnum_to_filepath` 一致性。
3. 删除/移动异常优先检查 `FileManager` OS path 输入与返回路径是否混用。
