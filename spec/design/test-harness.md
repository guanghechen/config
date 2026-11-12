# 测试架构与执行

本文是测试约定的唯一定义处：目录与布局、依赖、执行与失败契约、harness 与资源生命周期、时序，以及 Rust、
Node 测试的放置。可执行命令与编写示例见[测试指南](../../__test__/README.md)，benchmark 见
[Benchmarks](../../__test__/bench/README.md)。

## 范围与目录

Lua、Node 测试及跨语言共享 fixture 位于顶层 `__test__/`，与生产 `lua/` 分离。Rust unit tests 位于
`rust/<crate>/src/` 对应源码模块的 `#[cfg(test)]` 中，共享 Rust 测试支持也留在所属 crate。

| 路径                      | 用途                                                      |
| ------------------------- | --------------------------------------------------------- |
| `__test__/run.lua`        | 公共 CLI 与 suite 子进程入口                              |
| `__test__/support/`       | Harness、共享原语与按领域划分的测试支持                   |
| `__test__/specs/`         | 唯一的 Lua spec 发现目录，路径对应被测的生产模块          |
| `__test__/specs/support/` | 测试基础设施自身，包括 benchmark 统计                     |
| `__test__/fixtures/`      | 跨 spec 或语言共享的数据、oracle 与子进程入口脚本         |
| `__test__/node/`          | Node 测试，由 `node --test` 执行                          |
| `__test__/manual/`        | 手动运行的真实 server 与完整配置检查                      |
| `__test__/bench/`         | 可选的 benchmark driver，结果写入被 Git 忽略的 `results/` |
| `rust/<crate>/src/`       | Rust unit test，由 `cargo test` 执行                      |

### Spec 布局

- Spec 路径对应被测模块：`lua/era/m/git/hunk.lua` 的 spec 是 `specs/era/m/git/hunk_spec.lua`；仓库根的
  `init.lua` 与 `lsp/*.lua` 对应 `specs/init_spec.lua` 与 `specs/lsp/`。
- 一个 spec 覆盖一个生产模块或一个 feature 目录；测试另一模块的 case 放进那个模块的 spec。一个模块拆成多个
  spec 时，放进以模块命名的目录、按契约命名，不使用 `<module>_<contract>_spec.lua` 并列文件，例如
  `era/m/git/buffer.lua` 的 `git/buffer/{attach,documents,reset,write_index}_spec.lua`；feature 目录同理，indentline
  的 `parser_spec.lua`、`render_spec.lua`、`frame_spec.lua`、`provider_spec.lua` 与 `setup_spec.lua` 分别覆盖纯计算、
  buffer/cache、native rendering 和生命周期。
- Spec 的文件与目录形态跟随生产代码：`x/init.lua` 的 spec 放在 `x/` 内，不并列为 `x_spec.lua`；只有生产代码
  同时有 `x.lua` 与 `x/` 时（如 `era/plugin.lua` 与 `era/plugin/`），spec 才同时有 `x_spec.lua` 与 `x/`。
- Spec 目录可以带 `README.md` 说明该 feature 的验证入口；发现只匹配 `*_spec.lua`。

### Helper 与 fixture

- Helper 先留在 spec 内；被两个以上 spec 使用时提取到 `__test__/support/`。通用原语在 `harness`、`bootstrap`、
  `ui`、`ui_grid`、`process`、`fs`、`git`；feature 支持按领域命名，例如 `treeview`、`explorer`、`diffview`、
  `picker`、`lsp`、`cmp/`。
- 小型 fixture 内联在 spec；`__test__/fixtures/` 按 spec 路径存放共享数据、Lua oracle（`*_lua_reference.lua`）与
  子进程入口脚本。Test double 与 builder 属于 support。
- 本地 harness 不引入第三方依赖、生产抽象或 runtime plugin system。

## 职责与依赖

| 组件                         | 职责                                   | 持有状态                        |
| ---------------------------- | -------------------------------------- | ------------------------------- |
| `__test__/run.lua`           | 定位 checkout、准备 runtime、分派执行  | 进程 CWD、runtime 与 Lua paths  |
| `__test__.support.runner`    | 发现、筛选、启动、超时控制与汇总       | suite 列表、子进程结果          |
| `__test__.support.harness`   | 注册 case、断言、执行、清理与报告      | case 注册表、case/suite cleanup |
| `__test__.support.bootstrap` | 准备显式声明的应用 globals 与替身      | 交由 harness 恢复的 global 替换 |
| 其余 `__test__.support.*`    | 子进程、Git、Treeview 等多处共用的步骤 | 由调用方 harness 登记的资源     |
| `*_spec.lua`                 | 定义可观察行为与回归用例               | 本地 fixture、资源 handle       |

Support 创建的进程、目录、仓库、buffer 与 window 都通过调用方 harness 的 `defer` 清理；临时目录一律位于系统
临时目录，不写入 checkout。

进程内依赖保持单向：

```text
CLI entry -> runner
suite entry -> spec -> harness
                   -> bootstrap -> explicitly requested production modules
                   -> production modules under test
```

Runner 通过 `--suite` 启动新进程；该分支直接加载 spec，不导入 runner。生产 Lua 不得导入测试支持、引用
`__test__` 或暴露 test-only hook。生产与测试共用的纯逻辑放在正常 domain module，例如 `era.m.ai.capture`。
Harness、runner 不导入生产模块；bootstrap 不导入 runner 或 suite。

原生库：spec 与 bench 通过 `require("yoz")` 加载本平台安装在 runtimepath 上的库（`lua/yoz.so`，Windows 为
`lua/yoz.dll`），由 `node script/build.mjs` 按当前平台构建；不依赖 `rust/target` 下的 debug 构建，runner 也不编译
native module。Baseline 比较按同样的路径加载另一个 checkout 中安装的库。

## 执行契约

公共命令：`nvim -l __test__/run.lua [--list] [--timeout ms] [--jobs n] [path-filter]`。

- `path-filter` 是 spec 路径的字面子串：完整路径选择一个 suite，目录路径选择其下的 specs。
- 递归发现并排序所有以 `_spec.lua` 结尾的普通文件，不使用 helper 文件名黑名单。每层目录读取和 entry 检查
  都必须成功；任一失败均在启动 suite 前终止 discovery。
- 入口从自身位置解析 canonical checkout，将 CWD 设为该目录，并配置 runtimepath、packpath 与 Lua paths，同时
  保留 Neovim 内置 runtime/library 目录及独立于 `$VIMRUNTIME` 安装的 bundled parsers。
- 每个 suite 使用独立的 `--headless -u NONE -i NONE -n` Neovim 进程。应用配置与 plugin 不自动启动；测试
  composed runtime 时显式加载 `ark.bootstrap`。只有断言完整启动结果的 suite（如 keymap 覆盖）在子进程中以本
  checkout 为 config 目录启动完整配置，state 与 cache 位于临时目录，依赖本机已安装的 plugin，未安装时 skip。
- Runner 以 argv 形式的 `vim.system` 并发执行最多 N 个 suite（`--jobs`，默认取硬件线程数的一半，最多 8）；各
  suite 的输出整块写出，并按发现顺序排列，与顺序执行时一致。`--jobs 1` 即顺序执行。
- 启动顺序按上次记录的耗时从长到短，没有记录的 suite 最先启动，避免慢 suite 最后才开始而拖长全程。CLI 每次
  运行后把各 suite 耗时合并写入 `stdpath("cache")/test-suite-durations.json`，并删去已不存在的 suite；记录缺失
  或无法读取时按发现顺序启动。记录只影响启动顺序，不影响输出与结果。
- Suite 进程的环境去掉 `TMUX` 与 `TMUX_PANE`，子进程随之继承，测试无法驱动用户真实的 tmux。每个 suite 使用
  本次运行目录下独立的 `XDG_STATE_HOME`，运行结束后删除，undo 文件等 state 不进入用户目录。
- 默认每个 suite 超时 30 秒，可由 CLI 覆盖；超过共享上限的 suite 在开头的注释行声明 `--- Timeout: <ms>`，取两者
  较大值。失败或超时不阻止其它 suite；不自动重试、安装依赖或编译 native module。
- Suite 与 CLI 以 `:cquit` / `:qall!` 退出：退出码不变，并执行 Neovim 的退出清理，删除各进程的 server socket
  目录。

| 触发条件                         | 必须行为                                  |
| -------------------------------- | ----------------------------------------- |
| Root 缺失、目录不可读或零匹配    | CLI 非零退出，不将零测试视为成功          |
| 无效 option 或 timeout 参数      | 启动前给出可操作的诊断                    |
| 空文件、遗漏 `t:run()` 或无 case | 子进程非零退出；无 case 时仍清理 suite    |
| Spec 加载或断言错误              | 子进程报告失败，后续 suite 继续           |
| Case cleanup 错误                | 保留原始错误与清理错误，继续其余 cleanup  |
| 子进程启动失败或非零退出         | 记录 suite 失败，后续 suite 继续          |
| Suite 超时                       | 终止子进程、报告 timeout，后续 suite 继续 |

依赖缺失时保留原始诊断，不由 runner 安装或替换依赖。状态不跨 suite 进程共享。

Repository health check（`node script/healcheck.mjs`）依次执行 Requirements、Git whitespace、Format、LuaLS、
Node tests、Lua tests、Clippy、Cross-target clippy 与 Rust tests，保留各项退出码；某项失败不跳过后续检查。

## Harness 与资源生命周期

- 每个 suite 使用一个 harness，以脚本路径命名，并以 `t:run()` 结束 spec。Spec 没有文件头，不声明
  `__module_name__`。`harness:run({ exit = false, quiet = true })` 只用于 harness 自测，以及借 harness 搭建场景、
  需要在 case 之后继续写出结果的 bench driver。
- `t:defer(fn)` 注册 cleanup，返回幂等的提前释放 handle；`patch_global`、`patch_table` 与 bootstrap 的
  `with_*` 替身使用同一套清理机制。
- Case 内注册的资源归该 case；顶层注册的资源归 suite，可供所有 case 使用。成功和失败后都按注册逆序清理。
- 资源在获取后立即登记：`t:tempdir()`、`t:buffer()`、`t:window()`、`UI.open()`、`git.repo()` 自带登记；其余
  资源紧随获取调用 `t:defer`。释放资源前，异步任务必须完成或取消。
- 环境无法执行某个行为时（例如文件系统拒绝某个文件名、缺少平台工具或本机 plugin），case 调用
  `t.skip(reason)`：输出 `SKIP <case>: <reason>`，计入汇总，不使 suite 失败。不以 skip 掩盖失败，也不以
  `return` 代替 skip。
- Case 名称描述可观察行为。回归用例包含触发输入，并断言受影响结果。

## 时序

Suite 并发运行，CPU 竞争会拉长异步工作，因此等待按断言的性质选择：

- 正向结果（某事应当发生）等条件成立：`t.wait_until`、`t.await`；Future 可能失败时用 `t.settle`；条件中要发
  RPC 时用 `ui:wait_until` 或 `ui:wait_lua`，因为在 `vim.wait` 回调中发起的请求会让外层等待无法超时。超时取
  常规值（不少于 5 秒），只是失败兜底，不表达延迟要求。
- 负向检查（某事不应发生）用固定观察窗口，窗口结束后断言。
- 一步同时包含两者时，先等满窗口，正向期望未满足再继续轮询到截止时间，例如 completion behavior trace 与
  PTY 场景 fixture。
- 断言不写在 Future 回调中，先等待 Future 再断言。排空已排队的 `vim.schedule` 回调用 `t.drain()`；需要逐步
  控制时用 `bootstrap.with_schedule`。其余固定等待只用于跨越 `timeoutlen` 这类时间阈值。
- 墙钟预算不写进测试；需要量化延迟时放进 benchmark。

## Rust 与 Node 测试

Rust unit tests 定义在被测模块的 `#[cfg(test)] mod tests` 中，保留 private access 与 platform gate；较长的
测试放在 `<module>/tests.rs`，再按契约拆成 `<module>/tests/<contract>.rs` 子模块；测试文件之间不互相导入。
共享支持只放在 `#[cfg(test)] test_support.rs`：crate 级的 `TempDir`、`eventually`（轮询条件，超时即失败）、
`percentile` 与 `isolated`（在子进程中单独重跑会耗尽进程级资源的测试），以及 `ux/treeview`、`ux/filetree`、
`git` 各自的 fixture 与测试替身。文件操作共享进程级的活动 job 上限；启动操作或创建文件的测试在第一行持有
`ux::filetree::test_support::operations()`，避免并发运行的测试互相耗尽该上限。

生产代码不含测试钩子，普通 build 不包含测试代码。测试函数以 `t_` 开头；release 模式的测量放在
`perf_tests.rs` 的 `#[ignore]` 测试中，只断言正确性并打印样本。异步条件用 `eventually` 等待；固定 sleep 只用于
断言一段时间内不发生某事，或跨越 deadline、watch 合并窗口等时间阈值。

Node 测试是 `__test__/node/` 下平铺的 `*.test.mjs`，按被测脚本命名（`script/benchmark/*` 与 bench CLI 加
`benchmark-` 前缀），直接导入生产脚本。跨语言共享 fixture 路径相对于 checkout root 解析。

## 基础设施验证

`specs/support/` 覆盖 discovery 边界、稳定排序、字面筛选、空选择、子进程状态隔离、含空格与 Unicode 的路径、
从其他 CWD 执行、加载/case/cleanup 失败、空 spec、遗漏 run、进程失败、超时和 CLI 诊断，并发上限、按发现
顺序输出、suite 环境不含 tmux 变量、`--jobs` 参数校验、按耗时记录的启动顺序及记录的更新、清理和容错，以及
harness、bootstrap、ui、fs、git 原语自身的契约。
