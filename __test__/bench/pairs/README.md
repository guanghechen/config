# Pairs 测量记录

本文记录 [Pairs](../../../spec/design/feat/pairs.md)（引擎见 [Yoz Pairs](../../../spec/design/yoz/pairs.md)）的测量方法与最新基线，
不定义契约。Benchmark 通用约定见 [Benchmarks](../README.md)；旧数字留在 git 历史。

## 入口

```sh
# variants: none、blink、era 的逗号列表；corpora: all 或语料、压力场景名的列表
# phases: 默认 parse,edit,redraw,matchparen,keys；stress 只在列出时运行
nvim -l __test__/bench/pairs/run.lua [variants=none,era] [corpora=all] [iterations=30] [blink-root] [phases]

# 压力场景
nvim -l __test__/bench/pairs/run.lua none,blink,era all 3 "" stress

# 引擎本身，不经 FFI
cargo test --manifest-path rust/Cargo.toml -p yoz --release --lib pairs::perf_tests -- --ignored --nocapture --test-threads=1
```

每个语料与变体使用一个新的子 Neovim：附着 120×50 UI，加载 ark bootstrap（选项、键位与 autocmd，不加载插件），
`filetype plugin indent on`，runtimepath 加入已安装的 treesitter parser，不启动 syntax 与 treesitter 高亮。
`none` 不启用 pairs；`blink` 以本配置原有的选项加载 blink.pairs（需要已构建的插件目录，默认
`stdpath("data")/lazy/blink.pairs`）；`era` 启用 `era.dressing.pairs` 与 `era.keystroke.pairs`。结果写入
`results/pairs/`。

## 语料

本仓库的真实源码，按路径拼接：

| 语料           | 内容                                                                                  |
| -------------- | ------------------------------------------------------------------------------------- |
| lua-2k         | `lua/era/m/searcher/composer/filetree.lua`                                            |
| lua-20k        | `lua/**/*.lua`（不含 `lua/stl/dict`）前 20,000 行                                     |
| lua-max        | 同上，至 3,000,000 字节                                                               |
| rust-2k        | `rust/yoz/src/ux/filetree/jobs.rs`                                                    |
| rust-20k、max  | `rust/**/*.rs`（不含词典）前 20,000 行；重复至 3,000,000 字节                         |
| javascript-20k | `*.mjs`、`*.js` 重复至 20,000 行                                                      |
| json-20k       | friendly-snippets 的 `snippets/**/*.json` 前 20,000 行                                |
| markdown-20k   | `*.md` 重复至 20,000 行                                                               |

3,000,000 字节是上限：本配置把超过 `vim.g.bigfile_size`（3 MiB）的文件设为 `bigfile`，不启用 pairs。

## 测量项

- `parse`：读出全部行，全量切分并配对。
- `edit_*` / `revert_*`：中部一行的 `nvim_buf_set_text` / `nvim_buf_set_lines`，含同步的变更跟踪：插入字母（`char`）、
  `()`（`pair`）、`(`（`open`），删除一个以左括号结尾的行（`line`），各自再还原。
- `redraw_*` / `provider_*`：强制整窗重绘（`nvim__redraw` 带 flush）的总时间与其中 pairs provider 的时间：视口不变
  （`static`）、每次编辑一个字母后（`edit`）、每次翻一页（`scroll`）。
- `matchparen_*`：光标移动回调，位置为同一行内的一对、跨度最大的一对的左括号、最深嵌套处的标识符、顶层的标识符。
- `key_*`：Insert 模式中由 `nvim_input` 输入 `(` 与 `<BS>` 到下一次 UI flush 的端到端时间，位置为括号内一行（`body`）的
  行尾。

## 压力场景

`stress` phase 的输入偏离常规代码，每个场景与变体同样使用一个新的子 Neovim：

- `long-line`：1,000,000 字节的单行 JS（`f(a[1],{b:(c)},"s(");` 重复）。打开，wrap 与 nowrap 下的静态重绘，行首插入
  `x`（`char`）与 `(`（`open`）。
- `deep-nesting`：20,000 行 `(` 接 20,000 行 `)`，缩进为行号模 40。第 10,000 行行首插入 `(`，其下的嵌套逐层做缩进修正。
- `stray-opening`：lua-max 之上加一行 `local broken = (`，中部插入 `()`（`pair`）。
- `commands-lua-20k`、`commands-lua-max`：对第 1–5,000 行执行 `:norm! A()`（`norm_bang`，不经映射）、`:norm A()`
  （`norm`，经过 Insert 模式的映射，与宏回放相同）与 `:s/(/[/ge`（`substitute`），之后 undo。
- `buffers`：把全部已跟踪的 `lua/**/*.lua` 加载为 buffer 并 attach，记录时间与 RSS 增长。

编辑记录编辑本身（含同步的变更跟踪）与其后的强制重绘，先预热一次；命令记录命令与其后的重绘。各项重复 `iterations` 次。
blink.pairs 在长行行首插入 `(` 的一次编辑约 80 s，含 blink 时取较小的 `iterations`。

## 解读

- 子进程环境自身有随文件增长的按键开销（Lua 与 markdown 的 filetype 插件），`none` 在 lua-max、markdown-20k 的按键约
  3.5–5 ms。比较按键时看与 `none` 的差。
- `provider_static`：blink.pairs 使用持久 extmark，视口不变时 provider 直接返回；era 使用 ephemeral extmark，每次重绘都
  设置可见范围内的 extmark。

## 基线

2026-11-15 于 Apple M5 Pro、Neovim 0.12.6、release library、附着 UI、自然 GC 测得，blink.pairs 为 `4e43012`。
median（ms）。

### 语料

`run.lua none,blink,era all 30 <blink-root>`：单个进程，按键各 30 次、重绘与 matchparen 各 90 次（另有预热）。
lua-2k 最先运行，三个变体都受冷启动影响，不列出。

| 语料           | `(` 按键 none / blink / era | 静态重绘 none / blink / era | matchparen 最慢处 blink / era |
| -------------- | --------------------------: | --------------------------: | ----------------------------: |
| lua-20k        |       0.195 / 0.943 / 0.169 |       0.088 / 0.097 / 0.132 |                 0.040 / 0.000 |
| lua-max        |       3.543 / 7.907 / 6.198 |       0.089 / 0.094 / 0.122 |                 0.027 / 0.000 |
| rust-2k        |       0.195 / 0.360 / 0.184 |       0.088 / 0.096 / 0.133 |                 0.025 / 0.000 |
| rust-20k       |       0.192 / 1.043 / 0.174 |       0.105 / 0.137 / 0.168 |                 0.307 / 0.000 |
| rust-max       |       0.181 / 3.143 / 0.842 |       0.094 / 0.105 / 0.178 |                 0.306 / 0.000 |
| javascript-20k |       0.180 / 1.650 / 0.358 |       0.147 / 0.164 / 0.211 |                 0.058 / 0.000 |
| json-20k       |       0.179 / 0.805 / 0.182 |       0.102 / 0.109 / 0.147 |                 0.018 / 0.000 |
| markdown-20k   |       5.152 / 5.704 / 5.294 |       0.123 / 0.130 / 0.138 |                 0.019 / 0.000 |

| 语料           | 全量解析 blink / era | 编辑跟踪（`()`）none / blink / era |
| -------------- | -------------------: | ---------------------------------: |
| lua-20k        |        4.258 / 2.635 |              0.002 / 0.188 / 0.008 |
| lua-max        |      18.270 / 11.772 |              0.004 / 0.842 / 0.017 |
| rust-2k        |        0.495 / 0.354 |              0.001 / 0.021 / 0.001 |
| rust-20k       |        5.595 / 3.334 |              0.000 / 0.286 / 0.006 |
| rust-max       |      24.325 / 15.144 |              0.001 / 1.317 / 0.022 |
| javascript-20k |        5.800 / 3.183 |              0.001 / 0.411 / 0.009 |
| json-20k       |        4.258 / 2.881 |              0.000 / 0.228 / 0.001 |
| markdown-20k   |        4.834 / 2.756 |              0.001 / 0.245 / 0.002 |

- 括号按键含一次全量重新配对：era 比 `none` 多约 0.66 ms（rust-max）与 0.18 ms（javascript-20k），20k 行的 Lua、Rust、
  JSON 测不出差别。lua-max 的按键连 `none` 也在约 3.5 与 5.8 ms 之间跳，差值不可靠。
- 静态重绘：era 比 `none` 多 0.02–0.08 ms，blink.pairs 多 0.01–0.03 ms（见解读中的 `provider_static`）。
- 编辑跟踪只含切分，比 blink.pairs 快 20–200 倍；配对推迟到下一次查询，计入按键与重绘。

### 引擎

`pairs::perf_tests`，不经 FFI，语料为本仓库的 Lua 与 Rust 源码，各截至 3,000,000 字节。

| 操作                    |      Lua 3 MB |     Rust 3 MB |
| ----------------------- | ------------: | ------------: |
| 全量解析（切分 + 配对） |         5.862 |         9.334 |
| 改 tab 宽度后重新配对   |         0.644 |         1.190 |
| 输入字母                |        0.0001 |        0.0002 |
| 输入 `()` / `(`         | 0.339 / 0.428 | 0.673 / 0.679 |
| 删除以左括号结尾的行    |         0.353 |         0.692 |
| `surrounding_pair`      |        0.0006 |        0.0009 |
| `unmatched_*`           |   0.018–0.020 |   0.005–0.006 |
| 50 行 `highlights`      |        0.0001 |        0.0002 |

- 输入字母、空格或在括号内换行时记号序列不变，沿用原有的 height，耗时与文件大小无关；增删括号与引号后全量重新配对，
  每个记号约 2.5–3.5 ns。
- 全量解析中配对约占一成（见"改 tab 宽度后重新配对"一行，含重算缩进），其余是复制全文与切分。

### 压力场景

`run.lua none,era all 3 "" stress`，commands 两组在加入缩进修正的上限后重测；blink 列为同日同构建的另一次运行。
内存增长取 `vim.uv.resident_set_memory()`。

| 场景             | 指标                      |          none |          blink |           era |
| ---------------- | ------------------------- | ------------: | -------------: | ------------: |
| long-line        | 打开                      |          5.08 |          334.1 |          9.60 |
|                  | 静态重绘（wrap / nowrap） | 0.025 / 0.025 |    24.5 / 27.9 | 0.046 / 0.046 |
|                  | 插入 `x`：编辑 / 重绘     |   0.17 / 0.03 |   8.06 / 404.6 |   3.28 / 0.08 |
|                  | 插入 `(`：编辑 / 重绘     |   0.16 / 0.03 | 86,428 / 401.2 |   2.73 / 1.33 |
| deep-nesting     | 插入 `(`：编辑 / 重绘     |   0.28 / 0.11 |   3,130 / 0.30 |  0.45 / 128.9 |
| stray-opening    | 插入 `()`：编辑 / 重绘    |   0.10 / 0.13 |    3.38 / 0.26 |   0.12 / 1.31 |
| commands-lua-20k | `:norm! A()`              |           412 |          2,028 |           466 |
|                  | `:norm A()`               |           411 |          2,494 |           637 |
|                  | `:s`：命令 / 重绘         |    4.8 / 0.20 |   187.6 / 0.51 |    6.1 / 1.59 |
| commands-lua-max | `:norm! A()`              |           415 |          8,628 |           559 |
|                  | `:norm A()`               |           414 |         11,712 |         1,375 |
|                  | `:s`：命令 / 重绘         |    5.3 / 0.18 |   849.7 / 0.36 |    6.6 / 7.47 |
| buffers          | 加载 / 内存增长（MiB）    | 1,924 / 163.7 |  1,942 / 218.2 | 1,928 / 180.7 |

- 长行：era 只查询重绘区间内的记号，重绘不随行长增长；编辑的约 3 ms 是重新切分这一整行。blink.pairs 每次重绘约
  0.4 s，插入 `(` 的一次编辑约 86 s。
- 深嵌套：插入的 `(` 使其下的嵌套逐层做缩进修正，era 在编辑后的第一次查询中完成，计入重绘；blink.pairs 在编辑时完成。
  两者的配对结果相同。
- `:s/(/[/ge` 留下约 2,100 个未配对的 delimiter，其中约 1,060 个 opening，超过缩进修正的上限（256），重绘时只做栈扫描。
  余下的约 7 ms（lua-max）主要是每个找不到 opening 的 `)` 自栈顶向下的查找；没有上限时缩进修正需要 110 ms。
- `:norm A()` 经过映射，每个 `(` 的平衡判断之前都完成一次全量配对，lua-max 上每行约 0.2 ms；`:norm!` 不经映射，
  只有切分的开销。
- 557 个 buffer（约 6 MB 源码）：era 比 `none` 多约 17 MiB，约为源码的 3 倍；按数据结构估算，全文副本、按行分配的
  开销、记号与配对表大致各占三分之一。blink.pairs 多约 56 MiB。
