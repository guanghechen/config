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

以下列出主要字段，完整类型见 [types.lua](../../../lua/era/m/plugin/types.lua)。

```lua
---@class era.m.plugin.IConfig
---@field public lockfile               string       -- Lock file path
---@field public root                   string       -- Plugin install directory
---@field public ui                     era.m.plugin.IUIConfig

---@class era.m.plugin.IUIConfig
---@field public size                   { width: number, height: number }
---@field public border                 string       -- Border style
---@field public title                  string       -- Window title
---@field public icons                  era.m.plugin.IIcons
```

```lua
---@class era.m.plugin.IPluginSpec
---@field public name                   string           -- Plugin name (directory name)
---@field public url                    string|nil       -- Git repository URL
---@field public branch                 string|nil       -- Git branch
---@field public main                   string|nil       -- Main module name
---@field public build                  string|(fun(): nil)|nil  -- Build command or callback
---@field public cond                   (fun(): boolean)|nil  -- Condition function
---@field public enabled                boolean|nil      -- Enable/disable plugin
---@field public lazy                   boolean|nil      -- Lazy load flag
---@field public event                  string|string[]|nil   -- Event triggers
---@field public cmd                    string|string[]|nil   -- Command triggers
---@field public ft                     string|string[]|nil   -- Filetype triggers
---@field public keys                   era.m.plugin.IKeySpec[]|nil  -- Keymap triggers
---@field public dependencies           string[]|nil     -- Dependency plugin names
---@field public opts                   table|(fun(): table)|nil  -- Plugin options
---@field public config                 (fun(spec: era.m.plugin.IPluginSpec, opts: table): nil)|nil  -- Config function
```

初始化示例：

```lua
local specs = {
  {
    name = "flash.nvim",
    main = "flash",
    event = { "VeryLazy" },
    opts = {},
  },
}

require("era.m.plugin").setup(specs)
```

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

## 高亮

全部使用 `m_pl_` 前缀：

| Highlight group                                    | 用途                 |
| -------------------------------------------------- | -------------------- |
| `m_pl_h2`                                          | Section 标题         |
| `m_pl_bold`                                        | 加粗文字             |
| `m_pl_comment`                                     | 弱化文字             |
| `m_pl_loaded` / `m_pl_not_loaded`                  | 已加载 / 未加载 icon |
| `m_pl_running` / `m_pl_error`                      | 运行中 / 错误状态    |
| `m_pl_time`                                        | 加载耗时             |
| `m_pl_event` / `m_pl_cmd` / `m_pl_ft` / `m_pl_key` | 对应 lazy trigger    |
| `m_pl_dep`                                         | 依赖                 |
| `m_pl_commit_from` / `m_pl_commit_to`              | 旧 / 新 commit hash  |
