# Tsuki

Tsuki is a Chrome/Edge Extension for improving website themes and readability. It also provides an
optional, capability-scoped Agent Bridge for explicitly granted pages.

## Chunkbase Seed Map

Tsuki 为 [Chunkbase Seed Map](https://www.chunkbase.com/apps/seed-map)
提供占满视口的地图布局：隐藏顶部导航与装饰标题、底部 AdThrive 悬浮广告、视频广告占位、Raptive 条款与合作标识底栏，以及地图下方的使用说明、排错、评论与页脚。

保留种子、版本、维度、图层和坐标控件；Seed 输入与按钮、版本及维度下拉框集中靠右，仅 Seed 显示前置标签。地图填充剩余空间，页面本身不滚动、不显示滚动条。地图拖动和滚轮缩放继续由 Chunkbase 提供；Expand
Map 模式下地图覆盖整个视口。

展开图层列表时使用列表内部滚动；窗口高度不足时控制区也可内部滚动，地图和坐标栏保持可用。

X/Z 坐标输入框及其表单关闭浏览器自动填充，避免保存信息提示遮挡地图。

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
