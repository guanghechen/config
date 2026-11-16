# Yoz Pairs 设计

`yoz.pairs` 在原生侧切分并配对 buffer 中的括号、字符串、注释与 span 记号，供 rainbow 高亮、matchparen 与键入时的
平衡判断使用（见 [Pairs](../feat/pairs.md)）。除 raw string 与缩进修正的上限外，切分与配对的结果与 blink.pairs v0.5.0
（`4e43012`，MIT，© Liam Dyer）一致（对照数据见 [blink.json](../../../__test__/fixtures/yoz/pairs/blink.json)），
不使用它的 nightly SIMD 切分器。实现位于 `rust/yoz/src/pairs/`，不依赖 Neovim、不引入外部依赖；Lua 类型见
[pairs.lua](../../../lua/__types__/yoz/pairs.lua)。行、列从 0 开始，列为字节。性能见
[Pairs 测评](../../../__test__/bench/pairs/README.md)。

## 语言

- 37 种语言的定义是静态数据，与 blink.pairs 的 `define_matcher!` 逐项对应：delimiter、行注释、块注释、字符串、
  字符字面量、块字符串、行内与块级 span。`yoz.pairs.language(filetype)` 沿用 blink.pairs 的 filetype 表
  （`typescript`、`javascriptreact` 等用 javascript，`tex`、`bib` 用 latex），不认识的 filetype 返回 nil。
- blink.pairs 的 span 以名字为 key，同名的后者覆盖前者：markdown 的 `bold` 只有 `**`。
- raw string 是没有转义的块字符串：Rust 的 `r"`、`r#"`、`r##"`、`r###"`，Go 的反引号字符串，C++ 的 `R"(`，C# 的 `@"` 与
  `"""`，Lua 的 `[[`。blink.pairs 把它们当作普通块字符串，`r"C:\"`、`[[C:\]]` 的结尾被反斜杠转义，字符串延续到后文；
  它也没有不带 `#` 的 Rust `r"` 与 C# 的 `"""`，后者被读作空字符串加一个延续到行尾的字符串。
- 照搬的行为（不是缺陷修复的对象）：
  - latex 的块字符串先列 `$` 再列 `$$`，`$$` 读作两个 `$`；
  - Zig 的 `\\` 行注释从不生效，反斜杠先作为转义处理；
  - shell 只认 filetype `shell`，`sh`、`bash` 不支持；C# 只认 `csharp`，`cs` 不支持。

## 切分

逐行执行 blink.pairs 的状态机：

- 只有候选字节参与：所有模式的字节与 `\`。反斜杠在行内两两配对；紧跟未配对反斜杠的记号算作转义，块字符串
  （raw string 除外）、字符串的结尾和行注释不在转义位置生效。
- 每个候选字节按 arm 顺序尝试：块注释、块字符串（raw string 排在其他块字符串之后）、块级 span、行注释、字符串、
  字符字面量、行内 span、delimiter。
  多字节模式要求字节相邻，匹配后跳过整个模式；delimiter 只在 Normal 状态生效。
- 字符字面量：引号之后第 1 或第 2 个字节是同一引号时记为一对，并跳过到结尾引号为止（blink.pairs 以候选字节的距离
  描述同一规则）。`'{'` 因此隐藏其中的括号，lifetime `'a` 不是字面量。
- 字符串、行注释与行内 span 在行尾结束；块注释、块字符串与块级 span 跨行延续。每行记录传给下一行的状态。

## 配对

对整个 buffer 的记号按位置执行：

1. 栈扫描。opening 入栈；closing 与 non-pair 自栈顶向下找同一记号：找到则其上的 opening 记为未配对并出栈，这一对的
   height 为出栈后的栈深；找不到则 height 为空。结束时栈中剩余的 opening 未配对。字符串、注释与 span 记号同样参与。
2. 存在未配对 opening 时，按位置倒序做缩进修正：未配对 opening 接管其后、嵌套更深区域中第一对同类记号，条件是这对的
   closing 与该 opening 所在行的缩进相同、与这对自己的 opening 不同（缩进按 tab 宽度向下取整，tab 宽度取
   `shiftwidth`，为 0 时取 `tabstop`，至少 2）。被替换的 opening 变为未配对，其后直到同 height 的 closing 为止的记号
   height 减一，被替换的 opening 再依次修正。修正会逐层级联：未配对 opening 之下是缩进循环的深层嵌套时，修正次数随
   嵌套规模增长，与 blink.pairs 相同。每个未配对 opening 都向后扫描，总代价随其数量超线性增长，因此未配对 opening 超过
   256 个时不做修正，保留栈扫描的结果。真实代码中通常只有几十个；超过时括号结构已经乱了，如批量替换之后（上千个时
   修正一次需要上百毫秒）。blink.pairs 没有这个上限。
3. 配对关系即 blink.pairs 的 `match_pair`：opening 的配对是其后第一个同一记号、同一 height 的记号，closing 反之；
   未配对的 delimiter 与 non-pair 记号没有配对。栈扫描中直接记录出栈的两端；字符串、注释与 span 的 closing 紧跟在其
   opening 之后，总能配对，未配对的这类 opening 与同一记号的下一个未配对 opening 相连。
   缩进修正在第一次改动 height 之前沿用这些配对，之后按 `match_pair` 扫描；改动过 height 时整体重算配对关系。

## 增量更新

`Document:edit(first, old_end, lines)` 对应 `on_lines` 的一次改动：

- 重新切分改动行；最后一行传出的状态与原来进入下一行的状态不同时，继续切分后续行，直到某一行进入时的状态一致。
  文档保存全文副本，不需要向 Lua 取行。blink.pairs 只切分改动行，后续行保持旧结果；这里与全量解析一致。
- 改动范围内记号的种类序列不变，并且存在未配对 opening 时各行的记号数与取整缩进也不变，height 与配对关系沿用旧值，
  只更新列与行号。输入字母、空格、在括号内换行都走这条路径，耗时与文件大小无关。
- 否则在下一次查询前重算整个 buffer 的配对。Insert 模式把输入的 `()` 报告为两次编辑，中间那个不平衡的状态不会被配对。
- 每次编辑与 tab 宽度变化都得到新的 revision。所有文档共用一个递增序列，重建的文档不会沿用旧文档的 revision，
  以 revision 为 key 的缓存因此不会把新文档误认为旧文档。

## 查询

- `highlights(first_row, first_col, last_row, last_col)`：起点在两个位置之间（不含末位置）的 delimiter，依次为行、列、
  结束列与 height（未配对为 -1）。按重绘区间调用，长行只取可见的部分。
- `match_pair(row, col)`：覆盖该位置的记号的配对，两端各为行、列与按其自身文本计的长度（缩进修正后，一端可能是另一个
  opening）。
- `surrounding_pair(row, col)`：位置上有记号时同 `match_pair`；否则为位置之前、配对在其后的最后一个 opening。每 64 个记号
  记录其中 opening 配对位置的最大值，向前查找时整块跳过不可能包围该位置的块。
- `unmatched_closing_after(open, close, row, col)` / `unmatched_opening_before(...)`：blink.pairs 的同名查询，返回同一层级上
  在该位置输入 `open`（`close`）会与之配对的未配对 delimiter。没有发生缩进修正时，配对内部的记号都嵌套更深，扫描整对跳过。
- `inside(row, col)`：位置所在的字符串、注释或 span 的类别，代码中为 nil：取该行位置之前最后一个记号之后的状态，
  行内没有时取进入该行的状态；位于 opening 或 closing 的文本之内时为 nil。只读切分结果，不等待配对。
- `tokens(row)`：一行的全部记号，供检查与测试。
