# Statusline Runtime Refactor Draft

## 1. Problem Statement

当前 Rust statusline 已经接管 `status02`，但 runtime 边界仍偏混杂：

- generic rendered cache 与 component snapshot cache 重叠，cache option 会膨胀。
- `DurationComponent` 仍通过 tmux `#(...)` 调 shell。
- commit 每次写入过多长 option，容易触发 `tmux command too long`。
- component contract 名义上有 `snapshot/render`，但 `ComponentSnapshot::Rendered` 让两层职责退化为同一件事。

目标：重构为更小的 core、更清晰的 component plugin、更有界的 cache、更少的 tmux 写入。

## 2. Context and Constraints

- `status01` 继续作为 fallback。
- `status02` 继续由 Rust renderer 持有。
- tmux native window list 保留。
- 不引入 daemon；继续使用 CLI + tmux option cache。
- 不实现动态第三方插件；但 component 按 plugin contract 组织，core 可无 optional component 运行。
- macOS metrics 继续可用，其他平台 graceful hidden；CPU 使用 native ticks，memory/network 暂用系统命令。

## 3. Decisions

| Question                 | Options                                      | Decision                     | Rationale                         |
|--------------------------|----------------------------------------------|------------------------------|-----------------------------------|
| cache 形态               | multi-record / single-slot / file cache      | single-slot tmux option      | 最简单，避免膨胀，保留跨进程状态  |
| generic rendered cache   | 保留 / 删除                                  | 删除                         | 渲染便宜，重复缓存 rich_text 不值 |
| component snapshot       | enum rendered / typed snapshot / plain data  | component-owned plain data   | core 不关心内部数据，SRP 更清晰   |
| metrics 刷新             | 每次采样 / TTL / daemon                      | TTL + stale fallback         | 避免每次 spawn 系统命令           |
| commit 策略              | full commit / delta commit                   | delta commit                 | 降低 tmux payload                 |
| duration                 | shell script / Rust computed                 | Rust computed                | 消除 status refresh shell spawn   |
| plugin 形态              | dynamic plugin / static component plugin     | static component plugin      | 满足边界，不增加复杂度            |

## 4. Risk Notes

| Risk                | Trigger                         | Evidence                   | Impact                 | Mitigation                     |
|---------------------|----------------------------------|----------------------------|------------------------|--------------------------------|
| layout 视觉回归     | row compose 改动                 | status02 由多段拼接        | 状态栏错位             | 保持 current format contract   |
| stale metrics       | 系统命令失败                     | provider 可能失败          | metrics 隐藏或旧值     | stale -> hidden -> continue    |
| tmux command 过长   | status/session/cache 内容增长    | 已出现 command too long    | apply 失败             | bounded cache + delta commit   |
| status-left clipping| 一行 wide session list 超过静态 64 | 最后 inactive slant 被裁剪 | 右边界颜色/形状异常   | dynamic `status-left-length`   |
| event 行为变化      | 去掉 generic rendered cache      | event skip 依赖旧 cache    | 非订阅组件仍需刷新     | render cheap，snapshot TTL     |

## 5. Draft Decisions

最终实现推荐“三刀”：

1. 删除 generic rendered cache，所有 component 每次参与 compose。
2. component cache 改为 single-slot，只保存必要 raw state 或 compact rendered fallback。
3. commit 改为 delta，只写实际变化的 tmux options。
4. `status-left-length` 由 renderer 按 faithful left literal width + 2 padding 计算，并以 client width 封顶，避免 wide 一行 session list 的右侧 slant 被静态长度裁剪。

## 6. Examples

### Example A: CPU

Before:

```text
@GHC_STATUS_COMPONENT_CACHE_cpu = rendered + v1 + v2 + v3 + v4 rich_text records
```

After:

```text
@GHC_STATUS_COMPONENT_CACHE_cpu = timestamp\tpercent
```

### Example B: Duration

Before:

```tmux
#(~/.config/tmux/script/duration.sh #{session_created})
```

After:

```text
Rust computes "4d1h" and writes literal status fragment.
```

### Example C: Commit

Before:

```text
always set LEFT/RIGHT/SESSION_FORMAT/CURRENT_FORMAT/layout/status/cache...
```

After:

```text
set only changed options; no changed option -> no tmux write.
```
