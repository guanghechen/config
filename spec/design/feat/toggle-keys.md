# 开关键

Picker 与 searcher 的各窗口，以及 Explorer、Diffview、Git Files 的 pane，用 `t` 开头的键切换显示与匹配开关。
键由 `stl.e.ToggleKeyEnum` 统一定义，开关声明自己的键，界面不按开关在列表中的位置编号。

## 编号

| 键   | 开关       |
| :--- | :--------- |
| `t0` | 设置       |
| `t1` | 只看已选   |
| `t2` | 树 / 列表  |
| `t3` | 压缩目录   |
| `t4` | fuzzy      |
| `t5` | 大小写敏感 |
| `t6` | regex      |
| `t7` | exclude    |
| `t8` | gitignore  |
| `t9` | replace    |

- 编号在各界面含义相同；界面没有某个开关时编号空着，不挪作他用。
- 没有显示开关（`t0`–`t3`）的界面把匹配开关放在 `t1`–`t3`：fuzzy `t1`、大小写 `t2`、regex `t3`；replace 仍为
  `t9`。这类界面是 list picker（含 find buffers）、Find Explorer 与 search in buffer。
- 编号已用满，新增开关一律用字母。

## 字母键

只在一个界面出现的开关用 `t` 加按含义取的字母，不占编号：

| 键   | 开关                                 |
| :--- | :----------------------------------- |
| `ts` | find buffers 的范围                  |
| `tb` | diagnostics 的只看当前 buffer        |
| `tl` | search in files 的 match limit       |
| `th` | Explorer 的隐藏项，`H` 同义          |
| `tz` | Diffview 的默认 diff 折叠            |
| `tu` | Diffview 的 untracked files          |
| `tp` | Git Files 的 diff preview            |

`tr` 是 replace（`t9`）的助记别名，search in files 与 search in buffer 都有。

## 显示与 Insert

- Winbar 与 tabline 在开关图标旁以上标标出它的键：编号显示上标数字，字母显示上标字母，如 `ts` 显示 `ˢ`。
- Picker 与 searcher 结果区的开关按编号升序排列，字母键排在最后。
- Picker 与 search in files 在 Insert 下另以 `<C-<编号>>` 切换带编号的开关；字母键没有 Insert 别名。Winbar 与 tabline
  中的开关图标也可点击切换。
