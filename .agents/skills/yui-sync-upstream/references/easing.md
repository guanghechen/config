# easing

## 镜像取材

- 仓库：[guanghechen/mirror](https://github.com/guanghechen/mirror.git)。
- 预期 ref：`refs/heads/nvim@easing`；2026-10-14 远端查询未找到，尚待建立或确认映射。
- 分支可用前仅保留本地来源盘点。以下同步步骤以确认镜像分支为前提，不从原始项目补取材料。

## 来源与本地范围

- 原始项目（仅归属说明）：`EmmanuelOga/easing`，入口 `lib/easing.lua`。
- 本地：[lua/stl/external/easing.lua](../../../../lua/stl/external/easing.lua)，由 `stl.easing` 导出。
- 来源锚点：`7944abdee5997b8d4e1cfc5d5522967ccfd86e32`，见本地首行；保留 Robert Penner 的 BSD notice。
- 主要消费者：[scroll.lua](../../../../lua/era/dressing/scroll.lua)、[dim.lua](../../../../lua/era/dressing/dim.lua)。

## 如何更新

1. 对比具体 easing 函数的公式与边界修复；保持 `t, b, c, d` 以及 elastic/back 可选参数的含义。
2. 沿用本地返回的 module table 和函数名；检查消费者实际使用的曲线，例如 `outQuad`。
3. 对修改曲线核对起点、终点、中间采样与数值容差；elastic/bounce 的 overshoot 不能当成统一的单调性错误。
4. 保留 BSD notice，并记录采纳的公式变化及来源 SHA。

## 验证

```sh
nvim --headless -u NONE -i NONE -n -c "lua local e = dofile('lua/stl/external/easing.lua'); assert(e.linear(0,2,3,10)==2); assert(e.linear(10,2,3,10)==5)" -c 'qa!'
nvim -l __test__/run.lua __test__/specs/era/dressing/scroll_spec.lua
nvim -l __test__/run.lua __test__/specs/era/dressing/dim_spec.lua
```

首条仅是加载与 linear 端点 smoke check；实际修改其他曲线时必须补相应数值采样，不能据此宣称全部公式已验证。

## 最近检查（2026-10-14）

- 本次远端 refs 查询仍未找到 `refs/heads/nvim@easing`；没有可固定的同步目标。
- 已保留本地来源盘点；未进行代码移植或推进已同步 revision。镜像分支可用后再执行上述核对与验证。
