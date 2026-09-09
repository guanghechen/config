# Textobject：文本对象、跳转与参数交换

`era.m.textobject` 负责文本对象选择、对象边界跳转、语法结构跳转和参数交换，替代
`mini.ai` 与 `nvim-treesitter-textobjects` 的运行时实现。现有 `nvim-treesitter`
继续管理 parser、高亮、缩进以及 `locals` / `folds` query group。

## 选择对象速查

下表中的 ID 写在 `i` / `a` 后面：`i` 表示 inner，`a` 表示 around。例如，
`f` 对应 `vif` / `vaf`，`di{` 表示删除花括号内部。这里描述的是选择范围，
不代表同名 Normal 模式按键的含义；部分对象的 inner 与 around 范围相同。

| 符号 ID             | 对应范围                                            |
| ------------------- | --------------------------------------------------- |
| `(` / `)`           | 圆括号 `(...)`                                      |
| `[` / `]`           | 方括号 `[...]`                                      |
| `{` / `}`           | 花括号 `{...}`，包括 Lua table                      |
| `<` / `>`           | 尖括号 `<...>`                                      |
| `b`                 | 任意一种 `()`、`[]`、`{}`                           |
| `B`                 | 原生 `{}` 对象                                      |
| `"` / `'` / `` ` `` | 对应引号包围的内容                                  |
| `q`                 | 任意一种单引号、双引号、反引号                      |
| `a`                 | 逗号分隔的参数、数组元素、table 字段                |
| `f`                 | 函数                                                |
| `c`                 | class                                               |
| `o`                 | block、conditional、loop；当前 Lua 不包含 table     |
| `m`                 | 注释                                                |
| `u` / `U`           | 函数调用；`u` 包含 dotted receiver，`U` 不包含      |
| `t`                 | 成对标签，如 `<div>...</div>`                       |
| `s`                 | splitline 分隔线之间的区域                          |
| `S`                 | Treesitter syntax scope：`@local.scope`             |
| `i`                 | 缩进 scope：`ii` 选内部，`ai` 包含边界行            |
| `n`                 | 原生 AST 选区：`an` 向父节点扩大，`in` 向子节点缩小 |
| `g`                 | 整个 buffer                                         |
| `h`                 | unstaged Git hunk                                   |
| `d`                 | 连续数字，如 `123`                                  |
| `N`                 | 可含负号、小数点的数字，如 `-12.5`                  |
| `e`                 | CamelCase / snake_case 中的 subword                 |
| `w` / `W`           | 原生 word / 按空白分隔的 WORD                       |
| `p`                 | 原生 paragraph                                      |
| `?`                 | 提示输入左右分隔符，再选择对应范围                  |
| `<Space>`           | 空格之间的内容                                      |
| 其他非字母 ID       | 同字符分隔符之间的内容，如 `\|value\|`              |

关键区别：

- 开括号 ID 的 inner 去掉首尾空白，闭括号 ID 保留：`vi(` 与 `vi)` 不完全相同；around 都包含括号。
- `f/c/o/m/S` 的具体范围由语言 queries 决定，并非每种语言都支持全部对象。
- `s`、`S`、`i` 分别选择分隔线区域、语法作用域、缩进区域。
- 对于 `local __fn__mods = { ... }`，`vi{` 选内容，`va{` 连花括号，`va{V` 选完整声明行。

## 范围与来源补充

- 括号、引号、参数 `a`、调用 `u/U`、标签、数字、subword 和自定义分隔符由本地文本匹配提供，不依赖 parser。它们是文本启发式规则，不完整理解注释及所有字符串语法。
- `b` 的 inner 保留首尾空白；引号和标签的 inner 去掉边界，around 包含两端边界。普通单 / 双引号在未转义换行处重置配对；保留转义换行。反引号优先选择参考行内的完整配对，也支持跨行配对。`u/U` 的 inner 都是调用圆括号内的全部文本。
- 参数 `a` 的 inner 去掉首尾空白与逗号；around 对首项取后面的逗号，对后续项取前面的逗号，唯一项则保留括号内部空白。引号状态只作用于已进入的括号容器，容器外文本不影响参数扫描。它独立于跳转、交换使用的 `@parameter.inner`。
- `d/N/e` 的 inner 与 around 相同。`<Space>` 和其他非字母分隔符的 around 只多包含右侧连续分隔符；如 `vi|` 选 `value`，`va|` 选 `value|`。
- `f/c/o/m` 来自 `textobjects` queries，分别使用 `@function`、`@class`、`@block/@conditional/@loop`、`@comment` 的 `.inner/.outer` captures。`io` 可能包含条件表达式。`S` 来自 `locals` 的 `@local.scope`，inner 与 around 相同。
- `g` 的 inner 去掉 buffer 首尾空行，around 包含全部行；`s` 的 inner 去掉区域首尾空行，around 保留空行，两者都不包含 splitline 分隔线。`is/as` 替代原生 sentence 对象。
- `h` 来自本地 Git provider，inner / around 都是 unstaged hunk 的行范围；纯删除保留可选择的锚点行。
- `i` 来自本地 indentscope。`n/B/w/W/p` 保留原生行为；`an/in` 有 parser 时选择 AST 节点，无 parser 时在 LSP 支持的情况下使用 selection ranges，不需要 textobject query。原生 `B` 使用自身的空白与搜索规则，`aw/aW/ap` 包含相邻空白或空行。

## 跳转与参数交换

### 对象边界跳转

`g[ID` / `g]ID` 跳到所选 around 对象的左 / 右边界。它们只接受本地 textobject provider
支持的 ID，不覆盖表中全部原生或 indentscope 对象。

数字边界跳转另接受 `g[n` / `g]n`，这里的小写 `n` 表示数字，而非 AST 选区。
Git hunk 边界的重复跳转仍有下文记录的回归。

### 语法结构跳转表

结构跳转的 ID 含义独立于选择对象：

| ID  | 上一个 / 下一个起点 | 上一个 / 下一个终点 | 范围 / capture             | Query group   |
| --- | ------------------- | ------------------- | -------------------------- | ------------- |
| `a` | `[a` / `]a`         | `[A` / `]A`         | 参数：`@parameter.inner`   | `textobjects` |
| `b` | `[b` / `]b`         | 无                  | block：`@block.outer`      | `textobjects` |
| `c` | `[c` / `]c`         | `[C` / `]C`         | class：`@class.outer`      | `textobjects` |
| `f` | `[f` / `]f`         | `[F` / `]F`         | 函数：`@function.outer`    | `textobjects` |
| `s` | `[s` / `]s`         | 无                  | 语法作用域：`@local.scope` | `locals`      |
| `z` | `[z` / `]z`         | 无                  | 折叠范围：`@fold`          | `folds`       |

这些跳转支持 Normal、Visual 和 operator-pending 模式，接受 count，打开 fold 并更新 jumplist。
class 跳转在 diff 模式保留原生 fallback。本地不提供 `iz/az` 对象。

`[s/]s` 跳转语法作用域，`is/as` 选择分隔线区域；`[b/]b` 跳转语法 block，
`ib/ab` 选择括号对。

### 相关操作表

| 按键         | 操作                                                                | 来源                         |
| ------------ | ------------------------------------------------------------------- | ---------------------------- |
| `[i` / `]i`  | 缩进 scope 顶部 / 底部；Normal 使用边界，Visual / operator 使用内部 | 本地 indentscope             |
| `[n` / `]n`  | Visual 模式选择上一个 / 下一个 AST 节点                             | 原生 Neovim                  |
| `[N` / `]N`  | 将 Visual 选区扩展到上一个 / 下一个兄弟节点                         | 原生 Neovim                  |
| `<leader>cx` | 将光标下参数与下一个兄弟参数交换                                    | 本地 textobject + Treesitter |
| `<leader>cX` | 将光标下参数与上一个兄弟参数交换                                    | 本地 textobject + Treesitter |

当前 `<leader>` 是 `<Space>`。参数交换使用 `@parameter.inner`，限定在同一语法容器内，支持 count。
Lua 的 parameter captures 也包含 table 字段，因此字段可以跳转和交换，即使 table 本身不是 `o` 对象。

## Lua 示例：选择 table 声明

以 [lua/era/init.lua](../../../lua/era/init.lua) 中的 `__fn__mods` 声明为例，结构如下：

```lua
local __fn__mods = {
  -- 模块字段……
}
```

将光标放在 table 内：

| 按键   | 选择范围                                               |
| ------ | ------------------------------------------------------ |
| `vi{`  | 字段内容，不含花括号和首尾空白                         |
| `va{`  | `{ ... }`，包含花括号，不含 `local __fn__mods =`       |
| `va{V` | 从左花括号所在行到右花括号所在行的完整行，包含声明前缀 |
| `vio`  | 匹配到的语法 block；当前 table 不属于此范围            |

`va{V` 能包含声明前缀，是因为声明与左花括号在同一行；这是按行选择，并非 declaration query。

需要按语法逐级扩大时，将光标放在 `__fn__mods` 上：`van` 先选择名称，再按 `an`
选择 `__fn__mods = { ... }`，再次 `an` 包含 `local`；`in` 向子节点缩小。

采用 `cover_or_next` 搜索时，table 内的 `vio` 可能选择后面的函数体。
此前插件配置也使用相同的 `o` captures，没有定义 table 对象。

## 行为约束

- 本地分发器接管 Visual / operator-pending 的 `i/a`；未支持的 ID 回退到已有映射或原生对象，保留 `an/in` 和 `ai/ii`。
- 搜索采用 `cover_or_next`：先匹配参考行内候选，再向前后各扩展 500 行；函数、class、syntax scope 搜索整个 buffer。支持 count 与连续 Visual 扩选。
- 函数 around 默认按行，class around 默认按块；显式 Visual / operator 模式优先于这两个默认值。Git hunk 按行。其他本地对象默认按字符，provider 可指定模式。
- 选择与跳转允许 readonly 源码 buffer，参数交换要求可写；每次操作重新检查 buffer 准入。排除 UI buffer，保留 notepad 与源码 scratch buffer。
- 编辑支持 dot-repeat，并在新光标位置重新计算范围；空对象编辑保留 registers。原生操作异常导致清理中断时，旧 register 快照不得用于后续选择。参数交换限定同一语法容器，目标不足则整体取消；一次交换对应一个 undo step。
- 缺失 parser、query 或对象时取消编辑并报告诊断；结构跳转无匹配时保持光标不动。每次操作刷新 parser，不跨编辑缓存节点或范围。选择先查询参考行，未命中再扩大范围；结构跳转先查前后 500 行，目标不足或落在窗口外时搜索整个 buffer。

本地模块位于 `lua/era/m/textobject/`，按输入映射、动作、范围查找、Treesitter、pattern、纯搜索与交换规划分工。
Neovim / Neovide 在 which-key、indentscope 之后幂等初始化；VSCode / Yozvim / Yui 不安装映射。
本地 28 个 query 文件来自 [nvim-treesitter-textobjects](https://github.com/nvim-treesitter/nvim-treesitter-textobjects/tree/898ee307df58f854d11cd7edd06472574d48014e/queries)，revision 为 `898ee307df58f854d11cd7edd06472574d48014e`，使用 Apache 2.0 license；具体语言见 `queries/*/textobjects.scm`。

## 验证

运行 `nvim -l __test__/run.lua era/m/textobject/`，验证范围、搜索、编辑、映射、buffer 准入、
parser 集成及交换的 undo / repeat。回归覆盖跨行引号状态、显式函数 / class 模式、
hunk 连续跳转与选择、函数结束行的行选区、同一函数的多个 inner captures、空对象的 register 保留、
UTF-8 / EOF 边界，以及深嵌套括号、超出查询窗口的目标和全量查询次数。
