# Tsuki

Tsuki is a Chrome/Edge Extension for improving website themes and readability. It also provides an
optional, capability-scoped Agent Bridge for explicitly granted pages.

## Chunkbase Seed Map

Tsuki 为 [Chunkbase Seed Map](https://www.chunkbase.com/apps/seed-map)
提供宽屏布局：隐藏底部 AdThrive 悬浮广告，压缩顶部装饰与设置区域，使地图随窗口尺寸扩展。原生地图计算、图层和 Expand
Map 功能继续由 Chunkbase 提供；窄窗口保持纵向滚动。

扩展面板中的站点开关可恢复原始布局。修改源码并重新构建后，在浏览器扩展管理页重新加载 Tsuki，再刷新 Seed
Map 页面。

## Agent Bridge from a source checkout

Requirements: Node.js 18+, Chrome/Edge 116+, and the workspace dependencies installed with pnpm.

```bash
pnpm agent:skill:link
pnpm agent:start
```

Enter the broker's single-use pairing code in Tsuki's **Agent bridge** panel, then enable **Read
access** for the intended origin. Agent notes and page actions require separate per-origin grants.
Start a new Codex turn after linking so the skill is discovered.

The link command refuses to replace an existing `$CODEX_HOME/skills/tsuki-agent` path. Remove only a
link created by this checkout with:

```bash
pnpm agent:skill:unlink
```

The Agent Bridge intentionally excludes clicking, form filling, navigation, cookies, website
storage, process memory inspection, network interception, and arbitrary JavaScript. Its only page
actions are scrolling a referenced element into view and displaying a temporary highlight overlay.
