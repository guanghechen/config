# stl.os 设计规范

`stl.os` 是系统交互边界层，目标是把“业务 filepath 语义”和“OS 调用语义”显式隔离。

## 设计目标

1. 业务层统一使用 slash path（`/` 分隔）。
2. 仅在系统调用前临时转换为 `os path`。
3. 为 remote filesystem 预留 adapter 扩展点，不污染业务层。

## 模块结构

| 模块             | 职责                                                            |
|:-----------------|:----------------------------------------------------------------|
| `stl.os.path`    | 维护 `filepath <-> os_path` 转换，统一 slash-only 路径语义      |
| `stl.os.fs`      | 文件系统 facade（`stat/rename/delete/scandir` 等）+ adapter 机制 |
| `stl.os`         | 聚合入口（`stl.os.path`、`stl.os.fs`）                          |

实现约束：

1. 无状态的 slash-only lexical operation 使用 `yoz.canonical_path`。
2. `relative` 在 CWD contract 完成前保持使用 `yoz.path`。
3. OS separator 转换使用 `yoz.path`。
4. `stl.os.path` 不依赖 `dot.path`。
5. Lua-facing `yoz.path.set_cwd` 与 `yoz.canonical_path.set_cwd` 共用一个 binding 写入路径，同步更新两份 native cache。

## 路径语义约束

1. `filepath`：业务层路径，始终使用 `/`。
2. `os_path`：系统调用路径，分隔符由 `stl.env.PATH_SEP` 决定。
3. `URI-like` 名称（例如 `diffview://null`）不参与路径转换。
4. 本地 adapter（`stl.os.fs` 默认实现）不接受 `URI-like` 输入，统一返回 `bad_scheme`。

## stl.os.path API

| API                                 | 说明                                           |
|:------------------------------------|:-----------------------------------------------|
| `normalize(filepath, keep?)`        | 归一化为 slash path                            |
| `to_os(filepath, keep?)`            | slash path 转 os_path                          |
| `from_os(os_path, keep?)`           | os_path 转 slash path                          |
| `join(from, to)`                    | 以 slash 语义拼接路径                          |
| `relative(from, to)`                | 以 slash 语义计算相对路径                      |
| `resolve(cwd, to)`                  | 以 slash 语义解析绝对路径                      |
| `dirname(filepath)`                 | 以 slash 语义获取父目录                        |

## stl.os.fs API

| API                                 | 说明                                           |
|:------------------------------------|:-----------------------------------------------|
| `stat(filepath)`                    | 获取文件信息                                   |
| `exists(filepath)`                  | 判断路径是否存在                               |
| `is_dir(filepath)`                  | 判断是否目录                                   |
| `mkdir_p(dirpath)`                  | 递归创建目录                                   |
| `rename(source, target)`            | 重命名/移动                                    |
| `delete(filepath, recursive?)`      | 删除文件/目录                                  |
| `scandir(dirpath)`                  | 列举目录项                                     |
| `set_adapter(adapter)`              | 设置 FS adapter（remote 扩展入口）             |
| `get_adapter()`                     | 获取当前 adapter                               |
| `reset_adapter()`                   | 回退到本地 adapter                             |

## Adapter 约束

`stl.os.fs` 的 adapter 必须完整实现以下方法：

1. `stat`
2. `exists`
3. `is_dir`
4. `mkdir_p`
5. `rename`
6. `delete`
7. `scandir`

若缺失方法，`set_adapter` 会直接报错。

## 使用规范

1. 业务模块（例如 explorer）内部只保留 `filepath`。
2. 对系统的读写调用统一通过 `stl.os.fs`，或在调用前用 `stl.os.path.to_os`。
3. 禁止在业务层散落私有 `to_os_filepath` 实现。

## 迁移建议

1. 先收口路径转换：统一改为 `stl.os.path.to_os`。
2. 再收口系统调用：逐步从 `vim.fn`/`vim.uv` 迁到 `stl.os.fs`。
3. 最后增加 remote adapter，并保持业务层调用不变。
