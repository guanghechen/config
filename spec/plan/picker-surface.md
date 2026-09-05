# Picker / Searcher 共享 Surface 验收记录

对应设计：[Picker / Searcher 共享 Surface](../design/feat/picker-surface.md)。

## 状态

- 验收日期：2026-08-16
- 结果：通过
- 当前配置：`/Users/wanchenfang/.config/nvim`
- 旧基线：`nvim-nvchad` commit `6d132c783ba3bb89e476e01c75e18af4c8656025`

原 `../nvim-nvchad` index/worktree 已包含待测改动，不能作为基线。验收从该仓库记录的 commit 使用
`git archive` 导出 clean config，并复用原 `nvim-nvchad` data/plugins：

```sh
baseline_commit=6d132c783ba3bb89e476e01c75e18af4c8656025
baseline_root=$(mktemp -d /tmp/nvim-baseline-config.XXXXXX)
mkdir -p "$baseline_root/nvim-nvchad"
git -C ../nvim-nvchad archive "$baseline_commit" | tar --no-mac-metadata -x -C "$baseline_root/nvim-nvchad"
cp ../nvim-nvchad/lua/yoz.so "$baseline_root/nvim-nvchad/lua/yoz.so"

XDG_CONFIG_HOME="$baseline_root" \
NVIM_APPNAME=nvim-nvchad \
LUA_PATH="$baseline_root/nvim-nvchad/lua/?.lua;$baseline_root/nvim-nvchad/lua/?/init.lua;;" \
nvim --cmd "set runtimepath^=$baseline_root/nvim-nvchad" \
  -u "$baseline_root/nvim-nvchad/init.lua"
```

## 自动验证

- `nvim -l __test__/run.lua`：103 suites，0 failed。
- LuaLS Error-level：509 files，0 problems。
- Stylua、`git diff --check`、shared dependency checks：通过。

## Surface E2E

- `%34`：当前配置，fixture `/private/tmp/nvim-tree-perf.tgxPSE/a/fixture`。
- `%44`：clean 旧基线，fixture `/private/tmp/nvim-tree-perf.tgxPSE/b/fixture`。
- 每轮同时创建 Picker/Searcher 的 Result/Preview 四个 surface。
- Result 各绘制 6,289 rows，Preview 各绘制 200 rows。
- 三轮记录 open、redraw、navigation、hide/show；表中为三轮 median。
- heap 使用 clean process 首轮、两次 full GC 后的增量。

| 指标                              | 当前      | 旧基线    | 差异       |
|:----------------------------------|----------:|----------:|-----------:|
| Open 4 surfaces                   | 20.989 ms | 18.904 ms | +11.03%    |
| Redraw 4 surfaces                 | 2.953 ms  | 3.623 ms  | -18.49%    |
| Navigate 200 enqueue              | 0.287 ms  | 0.272 ms  | +0.015 ms  |
| Hide/show 4 windows               | 2.052 ms  | 2.893 ms  | -29.07%    |
| Live Lua heap delta               | 92.7 KiB  | 146.7 KiB | -36.81%    |
| Post-dispose Lua heap delta       | 81.4 KiB  | 180.2 KiB | -54.83%    |

两侧 10 项 correctness checks 全部通过：Result/Preview 创建、6,289 rows、filetype、wintype、
Picker relative number、Searcher relative-number policy 与 status winbar。

Open 三轮范围分别为 `19.353–22.170 ms` 与 `15.776–21.623 ms`，分布重叠；当前 median
多 `2.085 ms`，未形成用户可感知的显著回退。Redraw、hide/show 与 Lua heap 明确改善，
稳态 heap 满足“不增加超过 1%”的验收门槛。

## Tree selection regression probe

使用真实 `stl.c.Filetree + era.m.picker.FiletreeView` 扫描 5,612 files，执行：

```text
reset -> select leaf -> reset/rebuild -> only_selected render
```

- 当前：`selected=true`、`dirty=true`、`selected_maximum=3`、`visible_rows=1`、`PASS=true`。
- 旧基线：`selected=true`、`dirty=false`、`selected_maximum=nil`、`visible_rows=0`、`PASS=false`。

该 probe 直接覆盖 reset；search publication 复用同一 reset contract，rename/move rebuild 由 composer 回归测试覆盖。
