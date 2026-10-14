# nvim-lspconfig

## 镜像取材

- 分支：[nvim@nvim-lspconfig](https://github.com/guanghechen/mirror/tree/nvim%40nvim-lspconfig)。
- 完整 ref：`refs/heads/nvim@nvim-lspconfig`；2026-10-14 已确认远端存在，使用前重新解析固定 SHA。
- 本文的上游代码、文档和测试均从该镜像分支取材，文件路径相对分支根目录。

## 来源与本地范围

- 原始项目（仅归属说明）：`neovim/nvim-lspconfig`，主要入口是 `lsp/<server>.lua` 及对应配置文档。
- 本地：[lsp/](../../../../lsp/) 中的原生 server definitions（`vim.lsp.Config`），
  由 [era.m.lsp](../../../../lua/era/m/lsp/init.lua) 按 filetype 调用 `vim.lsp.enable()`。
- 关联适配：[fn.lua](../../../../lua/era/m/lsp/fn.lua) 的 root/binary 查找、
  [event.lua](../../../../lua/era/m/lsp/event.lua) 的 capabilities 与 attach/detach、
  [typescript.lua](../../../../lua/era/m/lsp/typescript.lua) 的 TypeScript server 选择。
- 关系：配置与必要回调的派生实现；本地直接维护这些定义，不依赖 nvim-lspconfig runtime，不能用统一插件版本作为基线。

下表保留 2026-10-14 本次同步前的来源锚点，作为历史基线。已改文件的源码链接记录本次上游参考 revision，
见文末「最近核对」；参考 revision 不表示本地与上游逐项完全一致。

| 本地 server（`lsp/<name>.lua`）                          | 本次同步前的来源锚点                       |
| -------------------------------------------------------- | ------------------------------------------ |
| `basedpyright`                                           | `a1d25809c5f732756cbc06a995e1426b956cdad9` |
| `bashls`、`cssls`、`dockerls`、`jsonls`、`ruff`、`taplo` | `5a49a97f9d3de5c39a2b18d583035285b3640cb0` |
| `clangd`                                                 | `cfc12beefe39cdcb77ff81fa49e71cc42cdf4fbc` |
| `denols`、`eslint`、`vtsls`                              | `78596b61676d361a74ea3f3abbbf83d5fe6f5519` |
| `docker_compose_language_service`                        | `030a72f0aa4d56f9e8ff67921e6e3ffd0e97bf07` |
| `emmet_language_server`、`html`                          | `ff18d1256877361113edc2970a2c367043d6414c` |
| `lua_ls`                                                 | `34229c6e021f8d2b9c947222ccd03605040b81b5` |
| `pyright`                                                | `2bf52f747b8633d38b671d0e9b968ec0a3133bcb` |
| `roslyn_ls`                                              | `43ed3797b266e1ee8d222e491379ad471c9d3146` |
| `rust_analyzer`                                          | `784531c83cdab93ed7a2ec10f0111ca564b1c18a` |
| `tailwindcss`                                            | `82af15ba583c8e1ba1e5f718ec3e287b89265a0c` |
| `yamlls`                                                 | `592de750bf5b8c45fc48cebfde585721626ffd6d` |
| `dartls`                                                 | 仅指向可变的 `master`，无固定 revision     |
| `biome`、`tsc`                                           | 本地未记录 nvim-lspconfig 来源锚点         |

`dartls` 首次核对须建立固定参考 SHA。`biome`、`tsc` 在镜像中存在同名定义，但本地没有记录派生 revision，
先建立配置与行为对应关系；不能仅因同名就声明具有相同来源基线。

## 如何更新

1. 按用户指定的 server/文件确定范围；整库同步时先列出当前本地定义，不自动引入上游全部 servers。
   有对应范围的已审查记录时从该 revision 比较增量，并继续处理未决项；否则按上述来源锚点或基线缺口建立对应关系。
2. 逐 server 核对 `cmd`、`filetypes`、`root_dir/root_markers`、`workspace_required`、
   `settings/init_options` 和 handlers/lifecycle callbacks 的变化。继续使用原生配置加载方式，
   将上游 helper 调用适配到本地或 Neovim API，避免引入 `lspconfig` runtime 依赖。
3. 保留本地 filetype 启用映射、capabilities、attach/detach 与 server-specific callbacks。
   涉及 filetypes 或 server 更名时同时检查 `era.m.lsp` 的启用入口；只因上游增加定义不自动启用它。
4. 对照现有实现与回归用例保留 Node/Deno 准入、`tsc/vtsls` 选择和 workspace SDK、
   Biome/ESLint 共存规则、项目 binary 查找，以及 JSON/YAML schemas 等本地设置。
   root 或启动逻辑变化须验证嵌套项目、无 marker、缺少 executable 和多 buffer 场景。
5. 区分配置迁移与 language server 包升级，核对当前已安装 server 是否支持新参数和 settings；包更新沿用已有授权。
   按文件记录目标 SHA、采纳/保留/未决差异及验证结果，保留所移植代码的 license/attribution，不推进未核对 server 的记录。

## 验证

```sh
nvim -l __test__/run.lua era/m/lsp/
```

现有 `init`、`fn`、`event`、`biome`、`typescript`、`typescript_activation`、`server_commands`、`rust_analyzer` suites
覆盖启用入口、root/executable 查找、公共事件、Biome/ESLint 与 TypeScript 选择等行为，不代表每个 server 的配置均已验证。
修改其他 server 时补对应配置/回调的定向用例；需要真实 server 时使用任务 fixture 与已安装工具，
按 [LSP headless debug guide](../../../../spec/debug/lsp.md) 检查实际 attach、root、settings 和目标行为，
并记录 server 版本与未覆盖项。

## 最近核对（2026-10-14）

- 审查目标：`ac062d0d01c019c0dbdb798968f3e5d8b35c3853`（`nvim@nvim-lspconfig`）。
- 源码参考：本次已改动的 `cssls`、`eslint`、`html`、`jsonls`、`rust_analyzer`、`tailwindcss`、`yamlls`
  的 `Upstream reference` 链接均指向上述固定目标；旧来源锚点保留在前表。
- 基线与范围：表列全部 23 个 server 已逐文件对照。20 个固定锚点均已核实为目标祖先；dartls、biome、tsc 首次建立固定参考，原有来源缺口保持注明。
- 结果：已移植 cssls/eslint/html/jsonls/tailwindcss/yamlls 的按 workspace 选择 executable；修正 Tailwind 在加载时绑定 editor cwd 的问题。rust_analyzer 支持显式 `cargo.sysrootSrc/sysroot` 复用，并在 Cargo 项目缺少 cargo 时停止 metadata 启动。clangd 复合 filetypes、Pyright tagged hints、ESLint workspace URI/flat-config 默认值及 Rust runnable environment 已由本地实现覆盖。
- 验证：`era/m/lsp/`：11 suites、84 cases 通过；6 个已改 command 的真实已安装 server 均通过 initialization smoke。其他 server 未逐一进行实机回归。
- 实机环境：macOS、Neovim 0.12.6；cssls/eslint/html/jsonls 使用 `vscode-langservers-extracted 4.10.0`，Tailwind 使用 `@tailwindcss/language-server 0.16.0`，YAML 使用 `yaml-language-server 1.24.0`。
- 保留差异：TypeScript 的项目版本选择、tsc/vtsls/Deno 准入、Biome/ESLint 共存、schema 与 UI settings；不引入全局 TypeScript fallback、同步 `--version` 探测或每次 root 解析的同步 `cargo -Z` sysroot 查询。继续使用本地异步 metadata 路径。完整许可见 [LSP 入口顶部注释](../../../../lua/era/m/lsp/init.lua)。
