# Surrounds 设计

`era.m.surrounds` 是参考 `mini.surround` 行为独立实现的本地 surround 模块，
替代外部插件，保留本配置使用的行为，采用固定配置。

## 模块边界

| 模块             | 职责                                               |
| ---------------- | -------------------------------------------------- |
| `init.lua`       | 公共 facade 与模块组装                             |
| `action.lua`     | Surround 动作、dot-repeat cache、operator callback |
| `keymap.lua`     | 固定映射与 buffer attachment 生命周期              |
| `definition.lua` | Surround identifier 输入及固定 input/output 定义   |
| `search.lua`     | Composed-pattern 与 span 搜索                      |
| `buffer.lua`     | Neovim marks、region、光标、编辑与高亮             |
| `types.lua`      | 共享 LuaLS types                                   |

所有模块位于 `era` 层，可依赖 `dot`、`stl`、`yoz` 与 Neovim API；下层不得依赖 surrounds。

## 行为契约

| 按键          | 动作                                         |
| ------------- | -------------------------------------------- |
| `gsa`         | 添加 surrounding，支持 Normal 与 Visual mode |
| `gsd`         | 删除 surrounding                             |
| `gsr`         | 替换 surrounding                             |
| `gsf` / `gsF` | 查找右 / 左边界                              |
| `gsh`         | 临时高亮两侧边界                             |

全部映射为 buffer-local。Normal mode 编辑通过 `operatorfunc` 执行，添加、删除、替换均支持
count 与 dot-repeat。Linewise、blockwise selection 保留 `respect_selection_type = true` 的行为。

内置 identifier 包括括号、`b`、`q`、`f`、`t`、`?` 和默认的对称字符。
搜索在相邻 50 行内使用 `cover_or_next`；高亮持续 500 ms。

## Buffer 准入与映射归属

Buffer 必须有效、可修改、非 readonly，且 filetype 通过 `stl.filetype.is_surround_enabled()`。
排除 `stl.filetype.DIFFVIEW_CHANGES`，覆盖 staged/unstaged Changes buffers；其他 Diffview buffer
及 diff window 中的真实文件仍可使用 surrounds。

`setup()` 在 `BufEnter`、`FileType` 及 `modifiable`、`readonly` 变化时刷新 buffer-local mappings。
由于 `OptionSet` 无法标识非当前目标 buffer，公开动作在编辑前再次检查准入。

Attachment 记录已安装 mapping 的 callback 或 normalized RHS identity。Detach 仅在 identity
仍匹配时移除映射，因此后续 buffer-local override 即使复用同一 description 也会保留。
`BufWipeout` 后延迟检查 buffer validity，确认销毁才释放 attachment；buffer 重命名也会触发该事件。

## 非目标与限制

- 不提供 runtime/buffer-local 配置、自定义 surrounding 或 Tree-sitter generator。
- 不提供 search-method 选择、previous/next suffix mapping 或运行期 `n_lines` 更新。
- 不兼容旧版 Neovim。
- Blockwise 操作保留上游对混合 multibyte/single-byte 文本的限制。
