# 测试执行流程

本文补充[测试架构](arch.md)中的执行与失败契约。所有测试源码位于 `__test__/`。

Repository health check 依次执行各语言检查，并保留各 runner 的退出码；某项失败不跳过后续检查：

- Node：通过 `node --test` 执行 `__test__/node/` 下的 specs。
- Lua：通过 `__test__/run.lua` 执行 specs。
- Rust：执行 `cargo test --workspace --all-targets`；Cargo 通过原源码模块的 `cfg(test)` include 编译 `__test__/rust/`。

## Lua CLI 与 suite 子进程

1. `__test__/run.lua` 定位 canonical checkout，准备 CWD、runtimepath、packpath 与 Lua module path，
   保留 Neovim 内置 runtime/library 目录。
2. 父进程解析字面路径 filter、`--list` 与 `--timeout`。无效参数、不可读目录或空选择在启动前报错。
3. 收集并排序 `__test__/specs/**/*_spec.lua`；list 模式只输出选中路径。
4. 对每个选中路径，启动干净的 Neovim 进程执行 `__test__/run.lua --suite <path>`；子进程准备同一 checkout。
5. 子进程加载 spec。Spec 声明 globals、创建 harness、注册 cases，并调用 `t:run()`。
6. 每个 case 执行后清空自己的 cleanup stack；最后一个 case 结束后清理 suite 资源。子进程保留失败诊断、报告并退出。
7. 父进程记录输出与退出码。启动失败、非零退出或超时均计为 suite 失败，随后继续执行。
8. 父进程汇总结果；任一 suite 失败则返回非零退出码。

## Case 生命周期

| 阶段          | Owner   | 结果与不变式                           |
| ------------- | ------- | -------------------------------------- |
| 注册          | Spec    | 具名可调用 case 与已声明的 suite 资源  |
| 执行          | Harness | 同时只有一个活动 case cleanup stack    |
| Case cleanup  | Harness | 逆序尝试全部 case cleanup              |
| Suite cleanup | Harness | 最后一个 case 后尝试全部 suite cleanup |
| 报告          | Harness | 保留计数、原始错误与 cleanup 错误      |
| 进程退出      | Runner  | 记录退出码，允许启动下一个 suite       |

Suite 资源比 case 资源存活更久。Cleanup handle 即使提前调用，也最多执行一次。
空 suite 仍释放资源并报告失败。

## 失败契约

| 触发条件                    | 必须行为                                  |
| --------------------------- | ----------------------------------------- |
| Root 缺失或零匹配           | CLI 非零退出，不将零测试视为成功          |
| 无效 option 或 timeout 参数 | 启动前给出可操作的诊断                    |
| 空文件或遗漏 `t:run()`      | 子进程非零退出                            |
| 未注册 case                 | Harness 报告失败并清理 suite              |
| Spec 加载或断言错误         | 子进程报告失败，后续 suite 继续           |
| Case cleanup 错误           | 保留原始错误与清理错误，继续其余 cleanup  |
| 子进程启动失败              | 记录 suite 失败，后续 suite 继续          |
| Suite 超时                  | 终止子进程、报告 timeout，后续 suite 继续 |

不重试或静默跳过。依赖缺失时保留原始诊断，不由 runner 安装或替换依赖。
应用 bootstrap 必须显式请求；状态不跨 suite 进程共享。
