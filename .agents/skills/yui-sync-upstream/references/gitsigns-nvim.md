# gitsigns.nvim

## 镜像取材

- 分支：[nvim@gitsigns.nvim](https://github.com/guanghechen/mirror/tree/nvim%40gitsigns.nvim)。
- 完整 ref：`refs/heads/nvim@gitsigns.nvim`；2026-10-14 已确认远端存在，使用前重新解析固定 SHA。
- 本文的上游代码、文档和测试均从该镜像分支取材，文件路径相对分支根目录。

## 来源与本地范围

- 原始项目（仅归属说明）：`lewis6991/gitsigns.nvim`。
- 本地：[lua/era/m/git/](../../../../lua/era/m/git/)，涵盖 buffer/repo、hunk、diff、sign、blame、index、staging、watcher 等。
- 来源锚点：`bf77caa5da671f5bab16e4792711d5aa288e8db0`，见本地 `init.lua`。该总入口的历史注释不代表每个当前子模块都逐文件等同于该版本。
- 本地契约：[Git](../../../../spec/design/feat/git.md)。本地已形成独立的状态、jobs 与原生能力边界。

## 如何更新

1. 按问题定位上游 hunk/diff、buffer 更新、sign、blame 或 index 操作的改动，再映射到本地相应 owner。
2. 从最小 Git 场景验证是否适用：无 HEAD、untracked、删除行、部分暂存、外部 index 修改、编码或窗口关闭。
3. 保留本地 buffer/repository identity、异步任务取消、snapshot 新鲜度和 staging/reset 语义；后台读取与用户写操作的边界以本地契约为准。
4. 若差异涉及 native backend，沿调用链检查对应 Rust 实现；不把上游 Lua 后端整层覆盖到本地架构。
5. 记录已采纳的具体修复和本地等价实现，保留复制代码所需的许可与来源。

## 验证

```sh
nvim -l __test__/run.lua era/m/git/
```

按改动选择 hunk/sign/blame/status/index/staging 等 suite。使用测试拥有的隔离数据验证 Git 写入，不把用户当前工作区当操作 fixture。
涉及 Rust 时执行仓库 Rust checks；单项环境失败须注明触发步骤和未覆盖行为。

## 最近核对（2026-10-14）

- 审查目标：`fd780920613e541cbdfac41bf711583ed49f9249`（`nvim@gitsigns.nvim`）。
- 基线与范围：已核实来源锚点到目标的祖先关系并核对相关差异；范围按本地 Git 模块与现有 native backend 划分。
- 结果：已移植 watcher 失败 fallback：事件 watcher 创建/启动/回调失败后关闭旧 handles，异步轮询 HEAD/index/packed-refs/reftable/当前 ref，最多一轮 stat 在途；完整契约见现有 Git 设计。保留本地 native status/ignore/blame/staging、零计数 hunk 语义与 Diffview，不引入上游 CLI、diff panel 或 config runtime。完整许可见 [Git 入口顶部注释](../../../../lua/era/m/git/init.lua)。
- 验证：`era/m/git/`：25 suites、204 cases 通过；包含 fs_event 启动及回调失败、ref 创建/切换、index 替换与 dispose 清理。
