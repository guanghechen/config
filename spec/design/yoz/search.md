# Yoz Search 设计

## 职责边界

`yoz.search` 负责文件遍历、匹配、取消检查与 native job state，不依赖 Neovim，worker thread 不调用 Lua。
`era.m.searcher` 负责 debounce、request generation、polling、结果发布与 UI 生命周期，见 [Searcher 请求控制](../feat/searcher.md)：

```text
composer -> Lua file-search controller -> Rust job -> controller -> composer
```

同步 `search_in_files` 保留为兼容入口与语义基准。未取消的请求必须在后台 API 中得到相同、顺序一致的结果。

## 匹配与替换语义

- 文件搜索与替换在整段文本上匹配：`.` 匹配换行；正则模式按行解析 `^`/`$`，`\r\n` 算一个行尾，
  `$` 在 `\r` 之前匹配，`^` 也在单独的 `\r` 之后匹配；跨行模式可以写 `\n` 或 `\r\n`。
  结果中的匹配范围同样取自整段文本上的匹配，与替换一致：`foo\s*$` 不包含其后的换行。
- buffer 搜索按行匹配，`.` 与 `\s` 不跨行；模式文本含有真实换行字符时，才在以 `\n` 连接的整段 buffer 上匹配。
  行号与列按 buffer 的行计：行内的 `\r` 是字符，不断行；行尾单个 `\r`（以 unix 格式读入的 CRLF 文件）不计入该行的匹配内容。
  buffer 替换按同样的规则展开列出的每个 match，捕获组取自 match 在原行中的那次匹配；只改写 match 所在的范围，
  其他位置的 mark 与 extmark 不动。搜索后 buffer 有过改动时，替换先重新搜索并提示，不按旧位置写入；
  替换预览也先重新搜索再显示。
- 文件开头的 UTF-8 BOM 不属于正文：文件搜索的行列与 offset 从 BOM 之后算起，与 Neovim 读入后的 buffer 一致；
  替换与替换预览按同样的正文匹配，写回时保留 BOM。
- 搜索不列出空匹配，替换也不改动空匹配。
- 替换只处理 UTF-8 文本。能匹配 UTF-8 以外字节的模式（如 `(?-u:\xFF)`）只用于搜索：替换模式下首次发布其结果时提示一次原因，
  修改替换串不再提示；结果行与预览不显示替换，替换操作拒绝执行。非 UTF-8 文件（包括 UTF-16）仍可搜索，结果行与预览
  按只搜索的样式显示，替换时报告 `not UTF-8 text` 并保持文件不变。文件搜索按读到的原始字节为每个文件给出 `utf8`，
  与替换读文件的规则一致；搜索停在有匹配的文件中间时（如到达 match limit），读完该文件再判断。
- 替换串只识别 `$n`、`$nn` 与 `$$`，规则同 JavaScript：`$nn` 在第 nn 组存在时取该组，否则按 `$n` 后接一个数字；
  未参与匹配的组展开为空，不存在的组与其他 `$` 写法保留字面量，捕获内容不再二次展开。

## 结果类型

结果结构与完整 Lua API 类型见 [search.lua](../../../lua/__types__/yoz/search.lua)。

`locate_in_lines` 与 `search_in_lines` 搜索相同，只返回每个 match 的位置，省去预览与逐行匹配转成 Lua table 的开销，
供 buffer 搜索使用（picker 的 regex 过滤由 [Yoz Fuzzy](fuzzy.md) corpus 完成）。

`ITextRange` 的 `lx/ly`、`cx/cy`、`ox/oy` 分别是匹配首尾的行、列与 source offset；`ITextMatch` 另带预览文本 `s`。
`ITextMatch` 的行号从 1 开始，列与 source offset 按 byte 从 0 开始；`cy/oy` 包含最后一个匹配 byte。
`sx/sy` 指向预览中匹配首尾字符的起始 byte，不是 end-exclusive 范围。
CR、LF、CRLF 在预览中显示为 `↲`，该字符占 3 个 UTF-8 bytes，因此预览坐标不能直接用于原文替换。
替换模式的结果行把匹配片段里的 `↲` 按匹配的原始字节数还原为 LF 或 CRLF 再算替换；片段字节数等于原始字节数时
不含换行，其中的 `↲` 是字符本身。跨行且含字面 `↲` 的匹配无法区分两者，结果行的替换预览可能不准，实际替换不受影响。

File search 的预览在匹配前后最多各扩展 64 bytes，并限制在匹配首尾行内。
单行匹配不包含行尾时不附加该行的换行；其他范围的 raw preview 可能保留尾部 `↲`。

## 后台 Search job

### Lua API

```lua
local job = yoz.search.start_search_in_files(options)

local status, result, err = job:poll()
-- status: "running" | "completed" | "cancelled" | "failed"

job:cancel()
job:dispose()
```

`start_search_in_files` 将 Lua options 转为 Rust owned data；在启动 worker 前，将缺失、空或相对 `cwd`
按调用时的当前目录解析。Options 转换和 thread spawn 失败以 Lua error 返回，由 controller 捕获，
仅对仍有效的当前请求报告一次。

Worker 不持有 `Lua`、`LuaTable`、callback 或 `vim.*` value，通过 one-shot channel 返回一个 terminal outcome：

```text
Completed(ISearchFileResult) | Cancelled | Failed(ISearchFailedResult)
```

Job 缓存 terminal outcome。`poll()` 可重复读取，不消费 payload，因此 Lua allocation/conversion
错误不会丢失 terminal state。Controller 在首次成功读取 terminal outcome 后 dispose job。

### 生命周期

- `cancel()` 幂等，只请求 cooperative cancellation。Job 保持 `running`，直到 worker 返回 terminal
  acknowledgement；terminal 后调用无副作用。
- `dispose()` 幂等、非阻塞：标记 disposed、请求取消、丢弃 receiver，不 join worker。
  Disposed job 的其他方法调用视为误用并报错。
- `Drop` 请求取消只用于泄漏兜底，正常生命周期必须显式清理。
- Channel 断开或 worker panic 转为缓存的 `failed` outcome，不得永久停留在 `running`。

## 取消契约

取消使用 `Arc<AtomicBool>`，在 setup、目录 entry、file boundary、读取 chunk 之间、match sink
及 terminal publication 前检查。

支持取消的 reader 返回有类型且不可重试的 sentinel error，不使用会被标准 reader 重试的
`io::ErrorKind::Interrupted`，避免取消后空转。请求已取消时，取消优先于该请求观察到的普通 I/O
错误；同步路径使用永不取消的 token，保留原失败语义。

Cooperative cancellation 不保证物理停止延迟：目录排序、正在执行的 filesystem syscall，以及已加载
multiline file 上的 regex evaluation 都无法强制中断。Lua 在 terminal 边界同步检查请求新鲜度；
即使输入 observer 尚未请求物理取消，已被替代的请求也不能发布结果或报告错误，见
[请求新鲜度](../feat/searcher.md#worker-数量与请求新鲜度)。

## Match limit

`max_matches` 为 `nil` 时不限制遍历；native API 仅接受 `nil` 或正 32-bit integer。
`ISearchFileResult.limit_reached` 只在遍历达到 `max_matches`、尚未确认穷尽时为 true。
它表示“无法确认结果完整”，不保证还存在更多匹配。相同请求的同步与后台 API 返回相同 flag。
