# 测试架构

## 范围与目录

所有 Lua、Node、Rust 测试及共享 fixture 均位于顶层 `__test__/`，与生产 `lua/` 分离。
Lua spec 按被测模块或 feature 分组，以 `*_spec.lua` 结尾；相关行为可共用目录，例如
`__test__/specs/era/m/diffview/workspace/`。

| 路径                                 | 用途                                 |
| ------------------------------------ | ------------------------------------ |
| `__test__/run.lua`                   | 公共 CLI 与 suite 子进程入口         |
| `__test__/support/`                  | 共享执行工具与 fixture 支持          |
| `__test__/specs/`                    | 唯一的 Lua spec 发现目录             |
| `__test__/specs/support/`            | 测试基础设施自身                     |
| `__test__/node/*.test.mjs`           | Node 测试，由 `node --test` 执行     |
| `__test__/rust/<crate>/**/*_test.rs` | Rust unit test，由 `cargo test` 执行 |
| `__test__/fixtures/`                 | 跨 spec 或语言共享的 fixture         |

小型 fixture 留在所属 spec；helper 只有被多个 spec 实际使用时才提取到共享目录。
本地 harness 不引入第三方依赖、生产抽象或 runtime plugin system。

## 职责与依赖

| 组件                         | 职责                                  | 持有状态                        |
| ---------------------------- | ------------------------------------- | ------------------------------- |
| `__test__/run.lua`           | 定位 checkout、准备 runtime、分派执行 | 进程 CWD、runtime 与 Lua paths  |
| `__test__.support.runner`    | 发现、筛选、启动、超时控制与汇总      | suite 列表、子进程结果          |
| `__test__.support.harness`   | 注册 case、断言、执行、清理与报告     | case 注册表、case/suite cleanup |
| `__test__.support.bootstrap` | 准备显式声明的应用 globals            | 交由 harness 恢复的 global 替换 |
| `*_spec.lua`                 | 定义可观察行为与回归用例              | 本地 fixture、资源 handle       |

进程内依赖保持单向：

```text
CLI entry -> runner
suite entry -> spec -> harness
                   -> bootstrap -> explicitly requested production modules
                   -> production modules under test
```

Runner 通过 `--suite` 启动新进程；该分支直接加载 spec，不导入 runner。
生产 Lua 不得导入测试支持、引用 `__test__` 或暴露 test-only hook。生产与测试共用的纯逻辑
放在正常 domain module，例如 `era.m.ai.capture`。Harness、runner 不导入生产模块；bootstrap
不导入 runner 或 suite。

Rust 源码只保留 `#[cfg(test)] mod ... { include!(...); }` 接线。Include 从
`CARGO_MANIFEST_DIR` 定位 `__test__/rust/`，保留原模块名、private access 与 platform gate；
普通 build 不包含测试代码。Node spec 直接导入生产脚本。共享 fixture 路径相对于 checkout root 解析。

## 执行契约

公共命令：`nvim -l __test__/run.lua [--list] [--timeout ms] [path-filter]`。

- `path-filter` 是 spec 路径的字面子串：完整路径选择一个 suite，目录路径选择其下的 specs。
- 递归发现并排序所有以 `_spec.lua` 结尾的普通文件，不使用 helper 文件名黑名单。
- 每层目录读取和 entry 检查都必须成功；任一失败均在启动 suite 前终止 discovery。
- 入口从自身位置解析 canonical checkout，将 CWD 设为该目录，并配置 runtimepath、packpath 与
  Lua paths，同时保留 Neovim 内置 runtime/library 目录及独立于 `$VIMRUNTIME` 安装的 bundled parsers。
- 每个 suite 使用独立的 `--headless -u NONE -i NONE -n` Neovim 进程。应用配置与 plugin
  不自动启动；测试 composed runtime 时可显式加载 `ark.bootstrap`。
- Runner 使用 argv 形式的 `vim.system` 顺序执行 suite。默认每个 suite 超时 30 秒，可由 CLI 覆盖。
  失败或超时不阻止后续 suite；不自动重试、安装依赖或编译 native module。

以下情况必须返回非零退出码：未选中 suite、目录缺失、CLI 参数无效、空 spec、遗漏 `t:run()`、
加载错误、case/cleanup 失败、子进程启动失败、子进程非零退出或超时。

## Harness 与资源生命周期

- 每个 suite 使用一个 harness，并以 `t:run()` 结束 spec。
- `t:defer(fn)` 注册 cleanup，返回幂等的提前释放 handle；`patch_global`、`patch_table` 使用同一套清理机制。
- Case 内注册的资源归该 case；顶层注册的资源归 suite，可供所有 case 使用。
- 成功和失败后都按注册逆序清理。Cleanup 错误与原始错误同时保留，且不跳过剩余 cleanup。
- 没有 case 的 suite 仍清理 suite 资源，并报告失败。
- Spec 负责临时文件、仓库、buffer、window 与异步任务；释放资源前，异步任务必须完成或取消。

`harness:run({ exit = false, quiet = true })` 供 harness 自测使用；普通 spec 使用默认的进程退出模式。
Bootstrap helper 显式声明所需 globals，并通过 harness 注册恢复操作。

## 测试边界与命名

按契约拆分 spec。例如 indentline 的 `parser_spec.lua`、`render_spec.lua`、`frame_spec.lua`、
`provider_spec.lua` 与 `setup_spec.lua` 分别覆盖纯计算、buffer/cache、native rendering 和生命周期，
各自使用独立 fixture 与失败信号，并归在同一 feature 目录。

Case 名称描述可观察行为。回归用例包含触发输入，并断言受影响结果。
所有 Lua specs 使用相同的 harness 与资源生命周期。

## 验证

基础设施测试覆盖 discovery 边界、稳定排序、字面筛选、空选择、子进程状态隔离、含空格与 Unicode
的路径、从其他 CWD 执行、加载/case/cleanup 失败、空 spec、遗漏 run、进程失败、超时和 CLI 诊断。

状态转换见[执行流程](flow.md)，可执行命令与示例见[测试指南](../../../__test__/README.md)。
