# Winline LSP 面包屑

## 范围

本文定义普通 source window 的 winline 如何获得光标处的 LSP symbol path，即
`textDocument/documentSymbol` 的请求时机、合并方式、结果交付与失败处理。
Picker（`era.fn.find_lsp_symbols`）有自己的请求，不在本文范围内。

## 状态归属与数据流

```text
dot.state.status.dirty_winline_nr   (CursorHold、WinEnter、BufWinEnter、保存、搜索等)
  └─ era.dressing.winline.render
       ├─ era.m.lsp.symbols.path(winnr)      已确认树的即时路径
       └─ era.m.lsp.symbols.request(winnr)   加入该 buffer 的下一批请求
            └─ buf_request(textDocument/documentSymbol)
                 └─ deliver(winnr, symbols) → winline.lsp_symbols → nvimbar:refresh()
```

- `era.m.lsp.symbols` 是请求和符号树的唯一 owner。树按 buffer 保存，window 只持有自己的 `lsp_symbols`。
- 交付结果直接回调 window，不经过 `dirty_winline_nr`，以免形成"请求、响应、dirty、再请求"的循环。

## 新鲜度契约

服务端状态可能在文本、URI、client 都不变的情况下改变，例如 clangd 的编译参数决定 `#ifdef` 的活动分支。
客户端拿不到可靠的失效信号，因此：

- 每次触发，都只能由在它之后发出的请求来满足。
- 触发登记在 buffer 的下一批 waiters 中；发出请求时，这批 waiters 整体移入该请求，所以触发永远不会挂到
  一个已经发出的请求上。
- 同一次 flush 内的多个 window（当前窗口与上一个窗口、fork、保存后的各个窗口）共享一次请求。
- 已确认的树只用于在请求返回前即时显示，不能替代请求。

## 节奏

- 不在途时立即发出请求。在途期间的触发合并为一次 trailing 请求，两次发出至少间隔 128ms。
- 快照变化不会取消在途请求。
- 每个请求带 10s 超时。在每个 client 都至少应答过一次之前，超时不报告，以免把仍在索引的 server
  当作故障。
- 当前窗口显示补全菜单时，该窗口跳过本次请求。`support_documentSymbol < 1` 或
  `b:dot_winline_disabled` 时，整个 buffer 跳过请求。

## 快照与已确认的树

- 快照键由三部分组成：`changedtick`、URI、支持 `documentSymbol` 的 client id（排序）。
- 响应只有在其请求发出时的快照键等于当前快照键时，才成为已确认的树。
- 文本被编辑后才到达的响应，仍然交付给发起请求的 window，但不确认。
- 任何失败都会清除已确认的树，直到下一次成功。
- `path(winnr)` 只从当前快照的已确认树推导路径，否则返回 nil，window 保持当前显示。
- 树压缩为 `{name, kind, sl, sc, el, ec, children}`，`vim.NIL` 和非表值视为缺失。
- 路径语义：
  - 区间两端都是闭区间，取第一个包含光标的兄弟节点。
  - `SymbolInformation` 只有一层。
  - 行列取 `range.start`，`col` 为 byte col 加 1。

## 结果与失败

- 交付值的含义：
  - 光标所在的路径；
  - `{}`：光标不在任何符号内，清空面包屑；
  - 请求失败或被跳过时不回调，window 保持当前显示。
- 多个 client 时，最先应答者胜出（包括返回错误的情况），并使用它的 `offset_encoding`。
- 应答过的 client 都会被标记进 `dot.state.status.lsp_symbol_ready`。
- 错误处理：
  - `Content modified.`：静默。
  - `trying to get AST for non-added document`：设置 `b:dot_winline_disabled`。
  - 其余错误：在 `suppress_warning` 未开启、且仍有显示该 buffer 的 window 时报告。
- `LspDetach` 时取消该 client 的请求；没有剩余的在途 client 时，静默结束本次请求。

## 超大文档

上一次成功响应的符号数 ≥ 10000，且快照未变时：

- 两次发出的最小间隔放宽到 5s，排队的 waiters 保证最后一定会发出 trailing 请求。
- 等待期间，window 通过 `path()` 即时显示已确认树的路径。

因此超大文档在服务端状态变化时最多过期约 5s 加一次往返。文本、URI 或 client 变化时恢复 128ms 间隔。

依据：2MB、40263 个符号的 LuaLS 响应约 9.3MB，解码约 30ms、分配约 37MB，每次请求都会让主循环卡顿。
1611 行、1138 个符号的普通文件解码约 0.9ms，不需要特殊处理。

## 生命周期

- autocmd 在首次请求时注册。
- `BufHidden` 只丢弃树。
- `BufUnload` / `BufWipeout` 取消在途请求并清除该 buffer 的全部状态。
- `VimLeavePre` 清除全部状态。
