# Agent Instructions

## 工作规则

- 修改前检查 Git 状态，保留用户已有改动。Git 写操作须有明确授权；commit 授权包含暂存对应改动，push 需单独授权。
- 非平凡修改前说明范围与验证方式，改动限于当前任务。删除功能时同步检查入口、样式、API、依赖及旧持久化状态。

## 架构

React + TypeScript + Tailwind 应用；API 和 WebSocket 通过 Vite server plugins 提供。

- `src/common/`：通用工具、样式、hooks、快捷键和公共组件；组件通过 props 接收业务数据，可有本地交互状态。
- `src/context/`：跨页面状态；`src/hook/`：业务与 API hooks，可消费 context。
- `src/container/`：连接状态与 UI 的可复用功能模块。
- `src/view/`：页面和文件类型查看器；私有 context、layout、pane 留在所属模块。
- `shared/`：共享契约、工具和客户端 API；`server/`：服务端实现。
- `@/` 指向 `src/`，`@/shared/` 指向根目录 `shared/`。

依赖约束针对上述顶层目录：view 可消费 container、hook、context、common；container 可消费 hook、context、common；hook 可消费 context、common；context 可消费 common。common 不依赖业务层，模块内部优先直接引用具体文件，避免 barrel 循环。已有例外不扩大，也不在无关任务中顺带重构。

浏览器代码不得导入 server、根目录 `env.ts` 或 Node 专属模块。shared 中供前后端共用的契约和工具应保持环境无关；客户端 API 不因此自动成为服务端可用模块。

沿用所属模块的状态管理方式，不强制所有组件使用 ViewModel。异步结果须忽略过期请求；创建的订阅、timer 和 DOM 资源须有对应清理。优先复用已有工具，避免仅为表面重复创建通用框架。

## 验证

- 修改后运行 `pnpm format`；只读分析或审查不运行会写文件的命令。不得使用其他 `pnpm` 或 `npm` 命令进行验证。
- 依赖安装与 lockfile 同步属于修改操作，不受上述验证命令限制，但仍须符合用户授权范围。
- 使用 Node 24+ 直接执行相关测试：`node --test <test-file>`；不假定存在 package test/build script。
- `tests/virtual-list.browser.test.mjs` 通过 `CHROMIUM_PATH` 使用已有 Chromium；测试跳过不算通过。
- `pnpm format` 会修改文件，完成后检查 diff；格式检查通过不等于类型检查或功能验证通过。
