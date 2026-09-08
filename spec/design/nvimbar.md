# nvimbar

`era.m.nvimbar` 为 statusline、tabline 和 window winbar 提供组件组装、独立刷新与宽度分配。

## 数据流与职责

```text
dirty event → bar:refresh() → component request → shared queue
                                                    ↓
                                           factory / refresh
                                                    ↓
                                         version + owner check
                                                    ↓
                                           data snapshot
                                                    ↓
                                      notification policy → signal hub
                                                                  ↓
                                             throttled publication → render → on_fulfilled
```

- 调用方拥有 dirty event、可见性和最终写入目标；收到事件时消费 dirty state，不能在异步结果发布时清除后来的 dirty event。
- `Nvimbar` 拥有当前 context、组件顺序、优先级和发布调度，并保留已发布内容对应的数据快照，直到下一次发布或 dispose。重新取数和显式 `render()` 不会提前释放屏幕上仍在使用的数据。
- `Component` 独占刷新状态、版本、CancellationToken 和已提交快照。组件之间不等待数据，也不共享这些状态。
- `Nvimbar` 模块组装一个共享 `SignalHub`。每个 bar 与每个 placed component runtime 都注册独立 role；通知定向发送到所属 bar，fork 使用自己的身份。创建方必须显式 dispose；销毁时注销身份，Hub 不持有已销毁 bar 的回调。
- `queue` 只负责调度与 Future deadline。所有 bar 共用一个 unref timer。首次取数（包括 factory）独占一个 turn，并在前后让出，允许先就绪的内容发布；已有成功快照的 warm refresh 可在约 1ms 的时间预算内批量执行，让同一 bar 的 publication 合并。预算在每个任务返回后检查，不能抢占单个同步函数。下一轮按 1ms 调度，追加任务不会推迟更早的调度。

这是 Neovim 主线程上的协作式异步，不是线程并行。单个同步 `require` 或 Lua 函数仍会阻塞当前轮；进程与 I/O 必须使用真正的异步 API。分批加载不承诺降低全部文件读取的总耗时。

排队任务具有取消句柄。cancel / dispose 立即释放排队回调；队列跳过废弃项时仍遵守当前轮的时间预算，但不为废弃项消耗独立的 cold turn。

## 组件契约

```lua
local c = era.m.nvimbar.component

bar:place({
  position = "left",
  priority = 100,
  component = c.lazy(function()
    return c.host.username("f_sl")
  end),
})
bar:place({
  position = "right",
  priority = 100,
  notify = { strategy = "throttle", interval = 32 },
  component = c.lazy(function()
    return {
      name = "example",
      will_change = function(context, prev_context)
        return context.changedtick ~= prev_context.changedtick
      end,
      refresh = function(context, token)
        -- 返回独立快照，或最终解析为该快照的 stl.c.Future。
        return { text = "ready", hltext = "ready" }
      end,
    }
  end),
})
bar:refresh()
```

- `place({ position, priority?, component, notify? })` 接受一个 placement 对象：`position` 为 `left / center / right`，`priority` 默认为 `1`，`component` 为 definition 或 factory。该方法只读取传入对象，并返回 bar 以支持链式调用。调用方通过 `local c = era.m.nvimbar.component` 和 `c.lazy(function() return c.host.username(position) end)` 声明延迟构造，保留 LuaLS 对 placement 字段、constructor、参数和返回值的校验。`lazy` 只标记并返回 factory，不执行或缓存结果；模块加载、参数求值与构造在队列中执行，每个 runtime 独立构造，成功后不再调用 factory。已加载的无参 constructor 可写成 `c.lazy(constructor)`，已有 definition 可直接传入。
- placement 与 raw definition 都可提供 `notify = { strategy, interval? }`。placement 覆盖整个 policy，省略时使用 raw 默认；factory 的默认值在初始化后确定，配置会复制后保存。默认 `immediate` 不接收 interval；`debounce` 与 `throttle` 要求正整数毫秒。debounce 在安静一个 interval 后发送最新通知；throttle 立即发送首条，窗口内合并为固定截止时间的一条尾沿通知，后来的变化不会推迟截止时间。
- notification policy 只控制组件何时唤醒 bar，不延迟取数或快照提交。其它组件通知、显式 refresh 或直接 render 都可能提前展示已提交数据；它不是每个组件的显示频率上限。scope 切换、cancel 和 dispose 会取消该组件未发出的通知，新的 scope 重新开始计时。
- `refresh(context, token)` 获取数据，不接收布局宽度。返回 `nil` 表示当前无内容；不提供自定义 `render` 时返回 `{ text, hltext }`。
- 可选的 `render(snapshot, context, remain_width)` 返回 plain text 和 Neovim statusline text。它只读取快照、当前 context 与必要的窗口几何信息，不能启动取数、修改快照或再次请求刷新。
- 目录按钮以不可变的绝对路径为目标，快照持有目标对象，点击注册表只保留弱引用。相同路径复用身份，取数不会重定向旧按钮；目标不再被当前或已发布快照引用后可回收，过期点击直接忽略。调试组件 `render_count` 在实际执行组件布局时计数，不在取数时累加。
- `will_change(context, prev_context, snapshot)` 是唯一可选的取数判断入口，默认需要刷新。它同步返回 boolean，必须便宜、无副作用；返回 false 时复用现有数据。`prev_context` 与 `snapshot` 分别是该 runtime 上一次成功取数的 context 和数据，按 readonly 使用；成功数据可以为 nil 或 false。外部依赖由组件在取数时记录到数据快照中，再自行比较，runtime 不构造、复制或深比较通用 cache key。
- 只有同 scope 的 `ready` 状态才会在请求阶段调用 `will_change`。首次取数、cancel 后重新请求、scope 切换、失败重试和 `refresh(true)` 都直接取数。判断抛错或返回非 boolean 时保留旧快照并进入 `failed`，下一次请求可以重试。
- 与 UI scope 无关的成功数据由组件 definition 自己缓存。Python 版本按 interpreter path 缓存，buffer / window 切换复用版本，但每次请求重新生成当前 venv 的显示名；失败、无法解析、取消或超时后的输出不写入缓存。版本解析失败按取数失败处理，后续相同依赖的刷新可以重试。
- `condition(context)` 在异步任务中执行。返回 false 会正常提交空快照，状态为 `ready`。
- 返回 Future 时默认 timeout 为 3000ms，可通过 `timeout` 覆盖。同步 factory / refresh 无法被 timer 抢占。
- 取数失败保留同 scope 的旧快照并报告错误。不在后台自动重试；下一次 `refresh()` 可以重试失败组件。`refresh(true)` 完全绕过 `will_change`。
- `render()` 同步排版当前 context 下已提交的组件数据，不取数或发布；`snapshot()` 只读取最近一次发布的字符串缓存，不重新构建 context 或排版。`refresh()` 只提交异步请求。旧的 `render(true)` 和 bar Scheduler 已移除；`will_change` 不控制布局，宽度变化仍可直接重新排版已有数据。
- 公开的 `render()`、`snapshot()`、`place()`、`cancel_refresh()`、`refresh()` 和 `fork()` 通过 `__health__` 拒绝已 dispose 的实例；`dispose()` 保持幂等。异步回调在内部检查失效状态并安静退出。非法 position 保持报告错误后返回 bar 的行为，不添加组件。

context 与快照在组件边界按 readonly 使用。context 包括 `winnr`、`bufnr`、`tabnr`、路径、filetype、mode、cursor、line_count 和 changedtick；不预先读取 fileicon、Git 或 LSP 数据。完整 context 在请求和布局时构建，组件的 owner 校验只读取 window / buffer / tab / filepath / cwd。信息组件只读取已加载的 optional backend，backend 自己负责初始化和后续 dirty event。

## 状态与结果提交

| status | 含义 |
| --- | --- |
| `idle` | 尚无请求，或之前的请求已取消 / owner 已失效 |
| `queued` | 等待共享队列执行，后来的请求合并到最新 context |
| `running` | 已开始初始化或取数，最多一项工作在运行 |
| `ready` | 最新有效请求已提交，快照可以为空 |
| `failed` | 最新有效请求失败，等待下一次请求重试 |

状态与缓存分离：`queued`、`running`、`failed` 都可能保留旧快照；`ready` 不保证有可见文本。dispose 是对象生命周期终点，不增加一种刷新状态。

每个组件维护单调递增的 `requested_version`，任务启动时记录 `running_version`。运行期间的新请求合并到最新版本与 context；完成时以候选结果及其取数 context 为比较基准，对最新请求调用 `will_change`。返回 false 时，该结果可以满足合并后的请求，按最新版本提交，避免重复事件使异步取数反复失效；返回 true 或未提供判断函数时，丢弃候选结果，仅补跑最新请求。没有新请求时不重复调用判断函数。

运行期间出现强制刷新、最新请求与候选结果的 scope 不同，或旧任务失败 / 超时时，不能用候选结果满足待处理请求。强制刷新不会被后来普通请求覆盖；过期的失败不能覆盖新请求。每个 placed runtime 使用自己的比较基准，直接复用同一 raw definition 也不共享这些状态。

取消先提交 idle、context、排队句柄及强制刷新状态，再触发 cancellation callbacks。bar 整体取消先对全部组件完成状态清理，再统一触发旧 token 的回调，保留回调中发起的新请求。

提交还必须满足：组件未 dispose、任务仍拥有 active identity、window / buffer / tab / filepath / cwd 仍匹配当前 owner。即使切换后还没收到新 refresh，旧 Future 也不能提交到新 owner。

当 context 已过期，runtime 通知 bar 重新请求当前 context；该路径独立于发布。这样启动时 buffer 重命名、切换等变化即使没有后续 dirty event，也不会让组件永久停在 `idle`。

Future 可以从 libuv fast event 完成；runtime 会先切回 Neovim 主循环，再执行 owner 校验和提交。

组件完成通过 `nvimbar.component.changed` 通知所属 bar，payload 为触发通知时的 readonly context，后来的未完成请求不会改写它，scope 为 `nvimbar`；bar 在接收延后通知时再次检查 owner，过期时请求最新 context。任务发现 owner 已失效时通过 `nvimbar.component.stale` 立即请求重取，不经过通知限频。两类消息的 from/original 均由 Hub 填入组件身份，to 为所属 bar；投递错误由 nvimbar 适配层统一报告。

取消与超时会取消传给 provider 的 token；provider 负责停止自己的进程或 I/O。active identity 和版本检查仍是阻止 late write 的最后保证，不依赖底层操作能否实际停止。

旧快照仅在相同 `winnr / bufnr / tabnr / filepath / cwd` 下显示。跨 scope 先显示其他已就绪组件，再等待本 scope 的结果。

## 发布、布局与窗口生命周期

- 每次有效请求和组件通知都可以安排发布；同一轮的发布合并为一次，`draw_interval` 默认 16ms，设为 0 时只合并当前轮。首次组件完成可以立即安排发布，避免启动占位内容阻挡首个就绪结果；之后首沿与固定截止时间的尾沿控制布局频率，持续请求不会让最后的更新饿死。interval 到期后直接执行布局与 `on_fulfilled`，不再追加一次主循环切换。
- 组件完成但文本未变时跳过结果回调；显式 `refresh()` 仍保证一次结果回调，确保切回某个 tabline 等场景能恢复目标。发布只排版当前已有快照，不启动任何组件取数。组件通知与绘制的 deadline 均复用 queue 的单个 unref timer，已进入到期快照的 callback 仍会检查取消或替换状态。
- 数据快照可以缓存，布局按最新宽度重新计算。高优先级结果晚到时重新分配剩余宽度，不要求其他组件重新取数。
- Buffer list 在刷新时复制文件名、图标、modified / pinned 与诊断计数。Modified 状态使用 `getbufvar(bufnr, "&modified")` 直接读取当前 tab 的 buffer，避免全局 `getbufinfo` 扫描和无关 metadata 的构造；先按文件名识别重复项，只对同名 buffer 做目录排序与消歧。布局只格式化可见条目和左右边界候选项，不再访问 buffer metadata 或 backend。
- 普通 statusline / tabline / winline 和 window fork 在目标 option 已等于结果时跳过重复写入；显式 refresh 仍然通知调用方，目标被其它 owner 改写后可以恢复。
- 调用方隐藏目标时用 `cancel_refresh()` 取消组件取数，并用 `validate` 在取数和发布时检查可见性、window / buffer ownership；取消取数保留已提交快照，不撤销已排队的发布。Statusline 在 command mode 发布后显式 redraw，确保内置 cmdline 安静等待时也能更新屏幕。
- Statusline 在 `VimLeavePre` dispose，取消在途任务和 Python probe；迟到的 dirty / mode 回调在 dispose 后直接退出。
- 分隔符参与宽度预算；center 内容在空间紧张时仍参与输出。某组件的布局抛错只隐藏该组件并报告错误，不触发发布循环，也不改变已成功获取的数据状态。
- `fork(winnr, padding?)` 为 widget 的额外窗口创建独立 bar、组件 runtime 和发布目标，绑定创建时的 window / buffer。相同绑定复用已有 fork；窗口切换到其他 buffer 后停止发布，避免终端或便签的 bar 覆盖新的 window owner。重新绑定时 dispose 旧 fork。
- 父 bar 刷新时同时刷新自己的 forks；关闭目标窗口会 dispose 对应 fork，父 bar dispose 时取消所有 forks。排队任务、Future late result 和已 schedule 的发布均不能写入已 dispose 的实例。
- `dot.win` 已有的 window owner / fork 关系继续由 `dot.win` 管理；其源窗口关闭后，仍有效的目标 owner 可以继续独立刷新。

## 验证

- `nvim -l __test__/run.lua __test__/specs/era/m/nvimbar`
- `nvim -l __test__/run.lua __test__/specs/era/dressing`
- `nvim -l __test__/run.lua`
- `nvim --headless -u NONE -i NONE -n -l __test__/bench/nvimbar.lua`

核心用例覆盖 lazy loading、请求合并、独立完成、过期结果与失败隔离、timeout / cancel / dispose、will_change 与 retry、几何变化、宽度预算和窗口生命周期。调用方测试等待可观察的 UI 状态，不使用固定 sleep 代替异步完成条件。

通知策略与绘制 cadence 使用可控时钟验证；原生终端测试覆盖延后数据与 debounce 通知在 command line 停止输入后仍更新屏幕。Benchmark 比较同轮完成和跨轮陆续完成的组件，报告布局次数、累计 CPU 与最后一个结果到发布的等待时间；不把批平均耗时称为 UI 尾延迟。

无阻塞实现的未决设计问题。异步布局不负责修复系统对单次文件打开的授权等待。
