# Image 模块边界

`era.m.image` 的顶层 facade 保持稳定，内部依赖无环。

## 依赖方向

```text
init → doc → inline → placement → image → convert
doc / inline / placement / convert → state
placement / image / convert / state → terminal
state / terminal → env
```

`init` 负责生命周期组装。在 tmux 中先将所在 pane 的 `allow-passthrough` 设为 `all`（`on` 会在 redraw
或 pane 隐藏时丢弃上传）；没有 `TMUX_PANE`（如 popup）或设置失败时不启用 image。退出（关闭 placements 之后）与挂起时
还原 pane 自己原来的值（原本未设置则取消设置），恢复运行时再设为 `all`：Neovim 不再绘制时，留在 pane 里的 shell
不应把程序输出的任意转义序列直通到 terminal。

图片只通过 kitty graphics protocol 的 Unicode placeholder 绘制，因此只支持 kitty 与 Ghostty；没有 WezTerm 式的
绝对定位 fallback，也没有浮窗预览。

## 状态归属

- `placement` 是 placement identity 的唯一 writer，并向 `image` 注册已分配的 ID。
- `image` 持有 image identity、转换/发送状态及已注册 placements。
- `state` 持有配置、source 路径与文件版本、图像尺寸与尺寸计算，通过 `terminal` 读取 terminal 尺寸。
- `env` 持有 terminal environment metadata 与 output transform。
- `terminal` 负责 terminal measurement 与 graphics-protocol output，只读取 `env`，不反向依赖 `state`。
- `doc` 持有 document queries，并向 `inline` 注入 query contract；`inline` 不反向解析 `doc`。
- `hidden` 只表示 conceal 状态。没有窗口显示 buffer 时 placement 不渲染，也不改变 `hidden`。
- inline placement 在转换完成前和失败后都保留一个位置 extmark，`inline` 依此找回并复用它。
- `inline` 只在 `doc.find_visible` 查找的行上增删 placement：窗口显示的行，加上其上一行与 `botline`（最后一个完整显示的
  行）之后可能只显示一部分的一行；范围之外的 placement 保留。显示源码（`hidden`）只针对光标或 Visual 选区所在的行，
  且只在当前模式不属于 `concealcursor` 时；`concealcursor` 改变时（render-markdown 在模式切换之后才设置它）重新判断。
- Insert 与 Replace 模式下，若当前模式不属于 `concealcursor`，光标所在行上会被 conceal 的新 placement 暂不创建，
  等离开该模式或光标离开该行后再建：逐字输入的公式只转换最终内容，而不是每个中间状态。
- 前后有文字的公式总在本行，占一行高、宽度按图片宽高比计算，不论多高都缩放进这一行；其他图片超过两行高时放在下一行，
  对齐其在文本中的位置（原位置显示图标），并以窗口宽度为限。行内公式（`$…$`、`\(…\)`）按行内样式排版，与网页一致；
  行间公式（`$$…$$`、`\[…\]`）按行间样式。

## Buffer 生命周期

- 图片 buffer 每次被读取（`:edit`，或 `checktime` 在文件改动后的重新加载）都先关闭已有 placements，再建新的。
- `doc` 为每个 buffer 只保留一个 `inline`。buffer 卸载（`:edit`、`:bdelete`）时 `inline` 随之 dispose，
  下次 FileType 时重新创建；`checktime` 的重新加载保留它，读入新文本后重建全部 placements。
- `doc` 不论 `dressing_image` 开关如何都会 attach；`inline` 跟随开关：关闭时移除全部图片与公式，打开时重新绘制。
  公式只在 markdown 中渲染，并另随 render-markdown 的开关。
- 退出时（`VimLeavePre`，而不是会被未保存修改取消的 `ExitPre`）关闭全部 placements。
- 在 tmux 中，pane 换到另一个 client（从别的终端 attach）后，terminal 中没有此前发送的图片：`image` 把它们标记为
  未发送，`placement` 全部重画，当前 tab 立即重画，其余在窗口显示时重画。client 以进程与创建时间区分，tty 会被新终端
  复用，不能作为标识。

## 标识与解析

- image id 是 24 位随机数（由 placeholder 的前景色承载），本实例内不重复；同一 terminal 中的多个 Neovim
  实例不再按计数器成片撞号，只剩偶然碰撞的可能。image 释放后其 id 可再用。
- placement id 在 placement 关闭后再次分配：每个 placement 以 id 命名一个 highlight group，而 Neovim 不释放
  highlight group，总数上限约 2 万（超出后任何新 group 都报 E849）。
- 相对路径先在文档所在目录查找，再找工作目录，以及两者下的 `img_dirs`；link destination 的转义（如 `%20`）先解码，
  `#page=N` 保留。找不到时按文档所在目录命名，文件出现后由版本检查发现。URL 与 data URI 不当作文件，原样传递。

## 版本与缓存

- source 由 path 与 page 标识，版本取文件状态（inode、size、mtime、ctime）；data URI 按内容寻址，没有版本。
- `image` 为每个 source 只登记当前版本。版本变化时创建新 image，旧版本退役；最后一个 placement 离开后删除其转换产物。
- 任一 image 的最后一个 placement 离开时，释放它在 terminal 中的图像数据（`d=I`），再有 placement 显示时重新发送。
  退出时关闭全部 placements，terminal 因此不再保留本实例发送的图像。
- `placement` 每次 update 先跟随 source 到当前版本，因此改写或后来才创建的文件会重新转换并显示；
  失败结果只在同一版本内复用。
- 公式源文件以内容的 64 位哈希命名：同名的两个公式会显示同一张图。
- 转换产物按 source 版本命名，写入完成标记后才被复用，中断的转换会重新执行；同一次转换中由前序步骤写出的产物
  （如 `convert` 顺带写出的 `.info`）直接沿用。清理只删除缓存目录中由该转换命名的直接子文件，不删除 source。
- 缓存目录存有打开过的文档的渲染结果与公式源文件，只对本账户开放（0700）。每个会话第一次转换前（早于任何复用），
  删除缓存中以哈希命名、30 天未被使用的文件：复用转换结果时刷新其产物与完成标记的时间；公式源文件与 data URI 文件的
  时间是其版本的一部分，不刷新，过期后在需要时重建，并因此重新转换一次。

## 转换

- 每个转换步骤最多运行 `convert_timeout`（默认 30s），超时即被终止并按失败处理，转换槽位随之释放。
- 公式以黑色排版，最后一步才着色：默认的黑色墨迹换成 `m_img_math` 的颜色，公式自己指定的颜色保留。源文件与排版结果
  因此与主题无关；着色结果按颜色命名，写完后改名，存在即完整，不受完成标记约束。主题改变时只重做着色。
- mermaid 图按背景（亮或暗）分别转换：主题、产物名与缓存都取创建转换时的背景，两种背景各有完成标记。主题改变背景时
  按新背景转换（已缓存则直接取用）。
- 主题改变颜色后，公式与图表以新 id 发送：以原 id 重新发送的图像会从其 placement 上消失。发送前 placement 以旧 id
  显示旧颜色，发送后改用新 id（placement 的状态包含 image id），旧 id 随即释放。image 订阅主题早于主题自己应用
  颜色的订阅，因此重新着色推迟到其后。
- ImageMagick 以 `-limit` 运行：宽高超过 16K 像素的图片直接失败，内存与磁盘 pixel cache 有上限。
- ImageMagick 只用文件扩展名对应的解码器读取它（常见位图、SVG 与视频），不按内容判断格式：否则内容是 PostScript 的
  `.png` 会在装有 Ghostscript 时交给它解析。其他格式（如 eps、ps、ai、mvg 与无扩展名的文件）在运行前即失败。
- data URI 按浏览器的宽松规则解码（忽略换行、接受 URL-safe 字符与缺省 padding）；无法解码时只让这一张图失败。
  解码后的文件扩展名只取 MIME 类型中的字母与数字：文档能指明格式，不能指定路径。
