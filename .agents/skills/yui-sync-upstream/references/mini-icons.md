# mini.icons

## 镜像取材

- 分支：[nvim@mini.icons](https://github.com/guanghechen/mirror/tree/nvim%40mini.icons)。
- 完整 ref：`refs/heads/nvim@mini.icons`；2026-10-14 已确认远端存在，使用前重新解析固定 SHA。
- 本文的上游代码、文档和测试均从该镜像分支取材，文件路径相对分支根目录。

## 来源与本地范围

- 原始项目（仅归属说明）：`nvim-mini/mini.icons`，主要入口 `lua/mini/icons.lua`。
- 本地数据与 lookup：[lua/stl/fileicon.lua](../../../../lua/stl/fileicon.lua)。
- 兼容入口：[lua/era/fn/mock-miniicons.lua](../../../../lua/era/fn/mock-miniicons.lua)，将 `MiniIcons.get` 转给本地实现。
- 本次同步前的来源锚点：`ff2e4f1d29f659cc2bad0f9256f2f6195c6b2428`，旧仓库地址为 `echasnovski/mini.icons`；当前真实上游位于 `nvim-mini/mini.icons`。

## 如何更新

1. 对比上游 icon 分类、文件名/扩展名/filetype 数据及 lookup/fallback 语义，按类别更新本地表。
2. 保留本地目录图标和 `.spec.*`/`.test.*` 优先级；复核新增 upstream key 是否覆盖这些定制。
3. 维持 `get(category, name, filetype)` 的 glyph、highlight、is_default 返回值及显式空 filetype 的处理。
4. 上游 API 变化同时检查 MiniIcons adapter 和消费者；移植的是数据及必要逻辑，现有本地 lookup 继续承担运行时接口。
5. 更新对应来源记录，并保留所采纳数据/代码的许可要求。

## 验证

```sh
nvim -l __test__/run.lua __test__/specs/stl/fileicon_spec.lua
nvim -l __test__/run.lua __test__/specs/dot/theme_spec.lua
```

检查未知扩展名、大小写、绝对路径、空 filetype、测试文件后缀，以及 `MiniIcons*` highlight 在主题中的可用性。

## 最近核对（2026-10-14）

- 审查目标：`f916635dc5ae2f479fbb9ab8184bb9444b62e86c`（`nvim@mini.icons`）。
- 源码参考：`fileicon.lua` 首行已指向上述固定 revision 的真实上游 URL；旧来源锚点保留在前文。
- 基线与范围：已核实来源锚点与目标的祖先关系，并按 directory/extension/file/filetype/lsp/os 六类核对数据增量。
- 结果：已移植 57 项 filetype 差异：新增 53 项、修改 2 项、删除 2 个旧名称（`bicepparam`、`jj`，分别由 `bicep-params`、`jjdescription` 取代）。补齐 MIT notice。其余类别、lookup、本地目录与测试文件定制保持不变；上游 web-devicons mock 的全局 default 不属于本地 MiniIcons adapter 接口。
- 验证：57 项数据逐项核对通过；fileicon 4 cases、theme 2 cases 通过。
