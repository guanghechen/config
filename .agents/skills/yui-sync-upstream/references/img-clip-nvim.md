# img-clip.nvim

## 镜像取材

- 分支：[nvim@img-clip.nvim](https://github.com/guanghechen/mirror/tree/nvim%40img-clip.nvim)。
- 完整 ref：`refs/heads/nvim@img-clip.nvim`；2026-10-14 已确认远端存在，使用前重新解析固定 SHA。
- 本文的上游代码、文档和测试均从该镜像分支取材，文件路径相对分支根目录。

## 来源与本地范围

- 原始项目（仅归属说明）：`hakonharnes/img-clip.nvim`。
- 本地：[lua/era/fn/paste-image.lua](../../../../lua/era/fn/paste-image.lua)。剪贴板后端由 [lua/era/m/clipboard/](../../../../lua/era/m/clipboard/) 管理。
- 本次同步前的来源锚点：`08a02e14c8c0d42fa7a92c30a98fd04d6993b35d` 的 `lua/img-clip/init.lua`，保留为尚未确认的历史基线。
- 关系：保存图片与插入引用的派生工作流，上游当前文件布局可能已拆分。

## 如何更新

1. 查看上游图片检测、目标路径、保存失败、文件名处理和 markup 插入的相关修复，追踪到目标版本的实际模块。
2. 将保存工作流适配到 `paste-image.lua`；平台剪贴板改动才修改本地 clipboard backend。
3. 保留本地目标路径输入、`paste_image_filepath` 状态、source file 准入、相对路径，以及 Markdown/notepad 图片引用格式。
4. 用成功、无图片、保存失败、空格/Unicode 路径、取消输入验证回调和 buffer 写入；保留所移植源码的许可要求。

## 验证

```sh
nvim -l __test__/run.lua __test__/specs/era/m/clipboard_spec.lua
nvim -l __test__/run.lua __test__/specs/era/fn/paste-image_spec.lua
```

clipboard suite 覆盖 backend；paste-image suite 使用 scratch buffer、临时路径与 mock clipboard，
验证路径编码、发起 buffer 归属以及失败/取消不插入引用。真实剪贴板与文件写入测试沿用用户授权。

## 最近核对（2026-10-14）

- 审查目标：`5ff183655ad98b5fc50c55c66540375bbd62438c`（`nvim@img-clip.nvim`）。
- 源码参考：`paste-image.lua` 首行已指向上述固定 revision 的真实上游 URL；旧来源锚点及其基线缺口保留在本文。
- 基线与范围：旧来源锚点在镜像 compare API 中返回 404，历史基线仍未确认；本次按固定目标的 clipboard/paste/markup 实现建立对应关系。
- 结果：已移植 Markdown 路径空格编码，保留 Unicode、notepad 模板及原始文件系统路径；适配本地异步输入，引用绑定发起 buffer，目标失效时不写入其他 buffer。保留本地 clipboard backend、保存路径状态与 overwrite 确认，并补齐 MIT notice。
- 验证：clipboard backend 12 cases、paste-image workflow 4 cases 通过；覆盖空格/Unicode、focus 切换、取消、保存失败和 source buffer 被删除。workflow 使用 mock clipboard，真实系统剪贴板未验证。
