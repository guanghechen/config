# img-clip.nvim

## 镜像取材

- 分支：[nvim@img-clip.nvim](https://github.com/guanghechen/mirror/tree/nvim%40img-clip.nvim)。
- 完整 ref：`refs/heads/nvim@img-clip.nvim`；2026-10-14 已确认远端存在，使用前重新解析固定 SHA。
- 本文的上游代码、文档和测试均从该镜像分支取材，文件路径相对分支根目录。

## 来源与本地范围

- 原始项目（仅归属说明）：`hakonharnes/img-clip.nvim`。
- 本地：[lua/era/fn/paste-image.lua](../../../../lua/era/fn/paste-image.lua)。剪贴板后端由 [lua/era/m/clipboard/](../../../../lua/era/m/clipboard/) 管理。
- 来源锚点：`08a02e14c8c0d42fa7a92c30a98fd04d6993b35d` 的 `lua/img-clip/init.lua`，见本地首行。
- 关系：保存图片与插入引用的派生工作流，上游当前文件布局可能已拆分。

## 如何更新

1. 查看上游图片检测、目标路径、保存失败、文件名处理和 markup 插入的相关修复，追踪到目标版本的实际模块。
2. 将保存工作流适配到 `paste-image.lua`；平台剪贴板改动才修改本地 clipboard backend。
3. 保留本地目标路径输入、`paste_image_filepath` 状态、source file 准入、相对路径，以及 Markdown/notepad 图片引用格式。
4. 用成功、无图片、保存失败、空格/Unicode 路径、取消输入验证回调和 buffer 写入；保留所移植源码的许可要求。

## 验证

```sh
nvim -l __test__/run.lua __test__/specs/era/m/clipboard_spec.lua
```

该 suite 主要覆盖 clipboard backend，不等于 paste-image 全流程验证。改变保存/插入流程时增加 scratch buffer、临时图片和 mock clipboard 的定向用例，
确认失败/取消不会插入引用；真实剪贴板与文件写入测试沿用用户授权。
