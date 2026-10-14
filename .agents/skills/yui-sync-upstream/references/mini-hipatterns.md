# mini.hipatterns

## 镜像取材

- 分支：[nvim@mini.hipatterns](https://github.com/guanghechen/mirror/tree/nvim%40mini.hipatterns)。
- 完整 ref：`refs/heads/nvim@mini.hipatterns`；2026-10-14 已确认远端存在，使用前重新解析固定 SHA。
- 本文的上游代码、文档和测试均从该镜像分支取材，文件路径相对分支根目录。

## 来源与本地范围

- 原始项目（仅归属说明）：`nvim-mini/mini.hipatterns`，主要入口 `lua/mini/hipatterns.lua`。
- 本地：[lua/era/dressing/hipattern/](../../../../lua/era/dressing/hipattern/)。
- 来源锚点：`7c840c71d6a91f53d734cab2b6fe2290d285ec3b`，见本地 `init.lua`；保留 MIT notice。
- 本地已经拆分 buffer、dirty、matcher、highlight、render 和 `rule/`，包含 keyword、Markdown、color、Tailwind 等规则。

## 如何更新

1. 对比上游匹配范围、增量刷新、extmark 和颜色解析的相关修复，先确认本地是否已通过不同实现解决。
2. 将状态生命周期改动映射到 buffer/dirty，将匹配问题映射到 matcher/rule，将呈现问题映射到 highlight/render。
3. 保留本地 filetype/buftype 准入、私有内容限制、规则集合及脏区管理；上游单文件实现不替代本地模块分工。
4. 用具体字符串与编辑序列验证变更，保留 MIT attribution；调整 palette/highlight 生成时检查主题重载。

## 验证

```sh
nvim -l __test__/run.lua era/dressing/hipattern/
```

检查局部插入/删除后的旧 extmark 清理、跨行匹配、buffer detach 和重配置。规则改变时补对应实际文本用例。

## 最近核对（2026-10-14）

- 审查目标：`8e18b4970f21be0db157104786d2be43058cdd44`（`nvim@mini.hipatterns`）。
- 基线与范围：来源锚点到目标只有 README logo 更新，`lua/mini/hipatterns.lua` 未变化。
- 结果：无需代码移植；本地增量刷新、规则集合和私有内容限制保持现有契约。
- 验证：`era/dressing/hipattern/`：4 suites、23 cases 通过。
