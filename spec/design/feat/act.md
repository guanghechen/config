# Act Board 组件

`era.view.Act` 将单行输入框与只读预览窗口组合为一个面板，适用于需要输入并实时预览的操作。
组件只负责输入、预览与生命周期；业务校验、路径生成、目标冲突处理和确认语义均属于调用方。

## 预览回调

- 调用方提供 `render_preview(bufnr, input)`、`on_confirm(input)`，可选 `on_input_change`、`on_cancel`、`initial_input` 与 `keymaps`。
- 输入保持单行，多行内容（如粘贴）以空格合并。每次变化在下一轮 event loop 调用 `on_input_change`，
  并经 64 ms 的 `stl.timer.debounce` 调用 `render_preview`；打开窗口时也渲染一次。
- `render_preview` 执行期间 preview buffer 可写，结束后恢复 readonly；每次调用重写全部预览内容，
  高亮使用调用方自己的 namespace，重绘前先清理。回调失败由组件通过 `stl.reporter.error` 报告。

## 生命周期

- `open()` 创建窗口并进入 Insert mode，已可见时只聚焦输入框；实例关闭后即 disposed，不能重新打开，`dispose()` 幂等。
- `<CR>`（Insert / Normal）确认，Normal mode 的 `q` 取消。`confirm()` / `cancel()` 先释放窗口与 buffer，
  再调用 `on_confirm(input)` / `on_cancel()`；`close()` 只释放资源，不调用回调。

## 布局与样式

- 宽度优先取 `get_width()`，其次 `width`（`0 < width <= 1` 为 editor columns 比例，`> 1` 为 screen columns，
  默认 `0.6`），再限制在 `min(floor(vim.o.columns * 0.4), 60)` 到 `min(120, vim.o.columns - 4)` 之间。
- 预览默认 5 行，最多 10 行；屏幕高度不足时缩减。窗口使用 editor-relative 坐标，按当前光标的屏幕位置布局，
  并调整位置避免越界；背景复用 picker finder / result 的高亮，输入框边框为 `FloatActiveBorder`。
