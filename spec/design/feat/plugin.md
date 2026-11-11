# Plugin 管理

`era.m.plugin` 提供本地 plugin 管理：按 event、command、filetype 或 keymap lazy load，
按 `lazy-lock.json` 同步版本，以及 install、update、clean、build 和统一状态窗口。

## 模块边界

| 模块         | 职责                                |
| ------------ | ----------------------------------- |
| `types.lua`  | 类型定义                            |
| `state.lua`  | 配置、lock 与 specs                 |
| `loader.lua` | 加载 plugin、注册 lazy triggers     |
| `action.lua` | Install、sync、update、clean、build |
| `widget.lua` | 状态与操作进度渲染                  |
| `view.lua`   | 浮动窗口生命周期                    |
| `init.lua`   | 公共 API 与模块组装                 |

按基础能力到调用方排列：

```text
types -> state -> loader -> action -> widget -> view -> init
```

## 配置与 Plugin spec

Config 与 plugin spec 的类型见 [types.lua](../../../lua/era/m/plugin/types.lua)。

`lua/era/plugin.lua` 从 raw specs 组装最终配置：确定 URL、branch、name、main 与 cond，
在 cond 满足时加载 `era.plugin.*` 的详细配置，再调用 `era.m.plugin.setup(specs)`。
详细配置模块名由 plugin name 去掉 `.nvim` / `.lua` 后缀，并将 `.`、`_` 转为 `-`。

## 命令与操作

`:Plugin` 打开状态窗口。打开窗口只读取状态；操作由以下按键显式触发：

| 按键 | 行为                            |
| ---- | ------------------------------- |
| `I`  | 安装缺失 plugins                |
| `S`  | 同步到 lock file 的精确 commit  |
| `U`  | 获取并 checkout 远端最新 commit |
| `X`  | 删除未使用的 plugin 目录        |
| `gb` | Build 当前 plugin               |
| `q`  | 关闭窗口                        |

## 状态窗口

窗口在同一界面中展示 plugin 清单、启动耗时和操作进度：

- 顶部依次显示 Neovim、startup plugins、Dressing 耗时；Dressing summary 与其 section 使用同一总和。
- Missing plugins 和 orphan directories 位于已安装 plugins 之前。
- 活动任务按 `Installing`、`Syncing`、`Updating`、`Building` 与 `Queued` 分组。
  共 8 个并发槽位；获得槽位后 queued job 才进入 running。
- Startup plugins 按 inclusive load time 降序排列；runtime-loaded 与 not-loaded 分组展示。
- Dressing 是只读 section，按耗时降序、名称升序排列，显示各模块耗时与总和。
- 已完成的 install/sync/update/clean/build 任务显示在所属 plugin 或 orphan row 下。
  无变化的 update 不展示；有效结果和错误保留至下一次操作替换 task snapshot。
- Header 汇总进度；刷新按 event-loop tick 合并。Plugin 跨 section 移动时，光标继续跟随同一 plugin。

### Startup 计时

- `Neovim (UIEnter)`：从进程启动时间 `v:starttime` 到 `UIEnter`。
- `Plugins (Startup)`：截至 `VeryLazy` 的顶层 plugin load spans；之后 runtime trigger 加载的 plugin 不计入。
- Plugin 总耗时对嵌套依赖只计一次；单个 plugin 的时间为 inclusive，可能包含依赖加载。
- Snapshot 在 `VeryLazy` 后定稿。Neovim 与 plugin 指标边界不同，不能相加。

### Dressing 计时

Dressing 由 `era.dressing` 初始化并计时；vendor 提供有序模块列表，plugin 窗口只读取结果：

```lua
era.dressing.setup({ "notifier", "ui_attach" })
local timings = era.dressing.get_load_times() -- module name -> milliseconds
```

- `setup(names)` 顺序执行模块。每个 span 从解析模块前开始，到 `dressing()` 返回结束；直接访问模块只触发 lazy load，不执行 setup。
- 记录第一次正常返回的耗时，包含 cold `require`、同步依赖与 feature-gate 检查，不包含 scheduled callback 和后续渲染。
- 重复调用仍执行模块，但保留首次计时。错误原样传播并中止序列；已完成模块的计时和事件保留，不自动重试。
- 计时独立于 plugin setup 和 `VeryLazy`；记录新数据时，`DressingLoad` 刷新已打开的状态窗口。
- Dressing 总耗时为已记录 spans 的和。Span 为 inclusive，嵌套工作可能重叠；Dressing、plugin 与 Neovim 总耗时不能相加。
- Dressing 不参与 plugin 数量统计或基于光标的 plugin 操作。

## Lock file 契约

使用与 lazy.nvim 相同的 `lazy-lock.json` 结构；示例中的 commit 为完整 SHA-1 格式：

```json
{
  "plugin-name": { "branch": "main", "commit": "0123456789abcdef0123456789abcdef01234567" }
}
```

Sync 只读 lock file，规则如下：

- Commit 必须是完整 Git object ID：SHA-1 为 40 位、SHA-256 为 64 位十六进制字符。
  缩写 ID 在任何 Git 操作前以 `Invalid lock entry` 拒绝。
- 已配置但无 lock entry 的 plugin 标为 `Unpinned`。
- 已安装 plugin 存在 worktree 改动时标为 `Dirty worktree`，不执行 checkout。
- Checkout 后验证完整 commit 精确匹配。新安装或 checkout 发生变化时执行 plugin build。
