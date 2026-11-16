# Pairs 设计

Rainbow 高亮、matchparen 与成对键入，替代 blink.pairs。切分与配对由 [Yoz Pairs](../yoz/pairs.md) 完成；键入规则与动作
移植自 blink.pairs v0.5.0 的默认配置（`lua/era/keystroke/pairs/LICENSE.blink`），只适配本配置，不提供配置项；除下文列出的差异，
键入结果与 blink.pairs 一致（对照数据见 [blink.json](../../../__test__/fixtures/era/keystroke/pairs/blink.json)）。Neovim 与 Neovide
启用；VSCode、Yozvim、Yuivim 不启用。性能见 [Pairs 测评](../../../__test__/bench/pairs/README.md)。

## 分层

| 模块                  | 职责                                                                    |
| --------------------- | ----------------------------------------------------------------------- |
| `era.m.pairs`         | 每个 buffer 一个 `yoz.pairs` 文档：首次使用时解析，随 `on_lines` 同步   |
| `era.dressing.pairs`  | Rainbow 与未配对高亮的 decoration provider，matchparen                  |
| `era.keystroke.pairs` | Insert 与命令行的配对键、`<BS>`、`<CR>`、`<Space>`                      |

## Buffer 文档

- 语言由 filetype 决定：`yoz.pairs.language`，否则取 filetype 的 treesitter 语言，再看该语言及其注册的 filetype。
  空 filetype、`bigfile` 与 `stl.filetype.is_not_sourcefile` 中的 filetype 没有文档。
- `document(bufnr)` 在首次调用时读取全部行并解析，之后 `on_lines` 只送改动行；`on_reload` 重新解析。FileType 变化与
  BufUnload 丢弃文档，旧的 `on_lines` 在下一次回调时脱离。`shiftwidth`、`tabstop` 变化时更新 tab 宽度。
- 文档记录它反映的 changedtick。`document(bufnr)` 发现两者不一致（改动没有经过 `on_lines`）时重新读取全部行；
  命令行预览（`inccommand`）改动文本却不报告 `on_lines`，预览期间返回 nil，不显示配对颜色，预览结束后重新同步。
- 清空 buffer 时 `on_lines` 报告不剩任何行，Neovim 仍保留一行空行；改动后文档行数与 buffer 不一致时重新读取。
- 同步出错时脱离该 buffer 并报告一次，不在每次编辑时重复报错。

## 高亮

- Decoration provider 使用 ephemeral extmark：`on_win` 取得文档（必要时此时解析）；Neovim 每绘制一个 buffer 行调用一次
  `on_range`，长行只含绘制的列，据此查询 `highlights` 后设置 extmark。
- Delimiter 的颜色为 `f_matched_pairs_{height % 5 + 1}`，未配对为 `f_unmatched_pairs`，priority 200。
  字符串、注释与 span 记号不着色。

## Matchparen

- `CursorMoved`、`CursorMovedI`、`TextChanged` 与 `WinEnter` 时查询 `surrounding_pair`：光标在记号上时高亮其配对，
  否则高亮包围光标的最内层一对（引号与块注释也算）。
- 颜色 `f_matched_pairs_0`，priority 250；配对位置与文档版本都不变时不改动 extmark，切换 buffer 时清除上一处。
  命令行中不高亮。

## 键入

规则按键登记：opening 的首个按键，以及 closing 首字符与之不同时的那个按键（`)`、`]`、`}`、`>`、`-`，以及 LaTeX 的 `` `' ``
登记在 `'` 上）。同一按键的规则按优先级（同级保持定义顺序）取第一条生效的规则：

| 按键          | 规则                                                                                                                                         |
| ------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| `(`、`[`、`{` | 字符串外成对；`[` 在 markdown 待办项（`- [`、`1. [`）中不做空格展开                                                                          |
| `'`           | Python、TOML 中第三个 `'` 成为 `'''`；否则在 plaintext、scheme 之外、不紧跟单词字符时成对，Rust lifetime 与泛型、LaTeX 与 typst 数学中不成对 |
| `"`           | Rust 的 `r#"` → `r#"\|"#`；Python、Elixir、Julia、Kotlin、Scala、TOML 中第三个 `"` 成为 `"""`；否则成对                                      |
| `` ` ``       | markdown 类文档中第三个 `` ` `` 成为代码围栏；LaTeX 中为 `` `' ``；否则成对                                                                  |
| `<`           | Rust 中位于泛型参数、类型名后或 `::` 后时成对                                                                                                |
| `!`           | HTML 与 markdown 中 `<` 后成为 `<!--\|-->`                                                                                                   |
| `$`           | markdown、typst、LaTeX 中成对                                                                                                                |
| `_`、`*`      | typst 中、数学之外成对（`_` 不紧跟单词字符）                                                                                                 |

- 语言条件看光标处的 treesitter 语言（含注入，如 markdown 代码块），没有 parser 时看 filetype。Rust、LaTeX、typst 的节点条件
  使用 `queries/<lang>/pairs_*.scm`。
- 成对：转义后不成对；光标后已有同一层级、等待这个 opening 的未配对 closing 时只输入 opening。
- 字符串内（按 [Yoz Pairs](../yoz/pairs.md) 的切分，含字符字面量与块字符串）`(`、`[`、`{` 的规则不生效：括号原样输入，
  `)`、`]`、`}` 不跳过，`<BS>`、`<CR>`、`<Space>` 不对括号做配对动作。注释中照常成对。
- Closing：光标前已有等待它的未配对 opening 时输入 closing；否则下一个字符就是它时跳过，`| )` 也跳过空格与它。
- `<BS>`：`(|)` 删除整对，`( | )` 删除两侧空格；`<CR>`：`(|)` 展开为三行；`<Space>`：`(|)` 变为 `( | )`。单引号、双引号与
  反引号不做 `<CR>`、`<Space>` 展开。
- Replace 模式、`/` 与 `?` 搜索以及非源码 filetype 中不做配对。

### Undo 与补全

- `<CR>` 之前插入 `<C-g>u`，单词后的第一个 `<Space>` 之前插入 `<C-g>u`，与 `ark/keymap.lua` 中未启用本模块时的映射一致；
  移动光标使用 `<C-g>U`，不打断 undo 与 `.` 重复。
- Completion 的 buffer-local `<CR>` 不接受候选时回退到这里的全局映射（见 [Completion](cmp.md)）。

### 命令行

命令行的内容按 Vim script 处理：语言条件只看 `vim`，不查 treesitter，也不做平衡判断，总是成对。映射配对键、`<BS>` 与
`<Space>`，不映射 `<CR>`。

## 与 blink.pairs 的差异

- 增量解析向后续行传递状态变化，与全量解析一致。
- 字符串内的括号不成对：blink.pairs 补出 closing，在 `"a|"` 中依次键入 `(`、`"` 得到 `"a("|")"`。
- raw string 的结尾不受反斜杠影响，并识别 Rust 的 `r"` 与 C# 的 `"""`（见 [Yoz Pairs](../yoz/pairs.md)）。
- 未配对 opening 超过 256 个时不做缩进修正（见 [Yoz Pairs](../yoz/pairs.md)）。
- 命令行不套用当前 buffer 的语言规则（blink.pairs 在 LaTeX buffer 的命令行输入 `` ` `` 得到 `` `' ``），也不查询 buffer
  第一行的平衡。
- 命令行不映射 `<CR>`：blink.pairs 在光标位于一对括号之间时返回 `<CR><C-o>O`，执行命令后又跳转并新开一行。
- 不提供 wrap 动作、规则配置、`vim.g.pairs` / `vim.b.pairs` 开关与命令行高亮。
- 同优先级规则按定义顺序，blink.pairs 的排序不稳定。
