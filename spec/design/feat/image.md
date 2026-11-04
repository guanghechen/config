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
或 pane 隐藏时丢弃上传）；没有 `TMUX_PANE`（如 popup）或设置失败时不启用 image。

## 状态归属

- `placement` 是 placement identity 的唯一 writer，并向 `image` 注册已分配的 ID。
- `image` 持有 image identity、转换/发送状态及已注册 placements。
- `state` 持有配置、source 路径与文件版本、图像尺寸与尺寸计算，通过 `terminal` 读取 terminal 尺寸。
- `env` 持有 terminal environment metadata 与 output transform。
- `terminal` 负责 terminal measurement 与 graphics-protocol output，只读取 `env`，不反向依赖 `state`。
- `doc` 持有 document queries，并向 `inline` 注入 query contract；`inline` 不反向解析 `doc`。
- `hidden` 只表示 conceal 状态。没有窗口显示 buffer 时 placement 不渲染，也不改变 `hidden`。
- inline placement 在转换完成前和失败后都保留一个位置 extmark，`inline` 依此找回并复用它。

## Buffer 生命周期

- 图片 buffer 每次被读取（`:edit`，或 `checktime` 在文件改动后的重新加载）都先关闭已有 placements，再建新的。
- `doc` 为每个 buffer 只保留一个 `inline`。buffer 卸载（`:edit`、`:bdelete`）时 `inline` 随之 dispose，
  下次 FileType 时重新创建；`checktime` 的重新加载保留它，读入新文本后重建全部 placements。

## 版本与缓存

- source 由 path 与 page 标识，版本取文件状态（inode、size、mtime、ctime）；data URI 按内容寻址，没有版本。
- `image` 为每个 source 只登记当前版本。版本变化时创建新 image，旧版本退役；最后一个 placement 离开后，
  释放它在 terminal 中的图像数据（`d=I`）并删除其转换产物。
- `placement` 每次 update 先跟随 source 到当前版本，因此改写或后来才创建的文件会重新转换并显示；
  失败结果只在同一版本内复用。
- 转换产物按 source 版本命名，写入完成标记后才被复用，中断的转换会重新执行；同一次转换中由前序步骤写出的产物
  （如 `convert` 顺带写出的 `.info`）直接沿用。清理只删除缓存目录中由该转换命名的直接子文件，不删除 source。

## 转换

- 每个转换步骤最多运行 `convert_timeout`（默认 30s），超时即被终止并按失败处理，转换槽位随之释放。
- ImageMagick 以 `-limit` 运行：宽高超过 16K 像素的图片直接失败，内存与磁盘 pixel cache 有上限。
- data URI 按浏览器的宽松规则解码（忽略换行、接受 URL-safe 字符与缺省 padding）；无法解码时只让这一张图失败。
