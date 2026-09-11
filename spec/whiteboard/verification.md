# Whiteboard v1 验证记录

验证日期：2026-09-11。

## 功能与契约

Node 24 执行以下测试，62 项通过，无跳过：

```sh
node --test tests/whiteboard.test.mjs tests/whiteboard-organization.test.mjs tests/whiteboard-transforms.test.mjs tests/whiteboard-sketch.test.mjs tests/whiteboard-theme.test.mjs tests/whiteboard-drawing.test.mjs tests/site-theme.test.mjs tests/file-access.test.mjs tests/websocket-auth.test.mjs
```

覆盖坐标转换、缩放锚点、形状/笔迹命中、连线绑定、事务历史、删除与复制、导入校验、并发保存冲突、文件权限保留、过期 Markdown 响应丢弃，以及既有 HTTP / WebSocket 鉴权与路径授权。

通过已安装的 Playwright CLI 与 Chromium 验证真实组件和文件 handler：

- 创建图形和自由笔，绑定两个节点的连线，移动、拉伸、undo/redo。
- Markdown 原地 Monaco 编辑，中英文快速粘贴、快捷键保存、公式、代码、表格和 Mermaid 渲染。
- 复制粘贴；导出再导入保持元素一致；无效导入保留当前场景；页面刷新恢复草稿。
- 两个节点引用同一 `.md`，外部修改后不刷新页面即可同步更新。
- 编辑期间发生外部修改，保存返回 409，本地中英文草稿保持完整，并可查看磁盘版本、重新加载；随后保存返回 200，两个节点与实际源文件一致。
- 打开 `.whiteboard` 文件、写回、刷新恢复；外部修改时拒绝覆盖，支持从源文件重新加载。
- 图形内中英文标签随移动、拉伸和保存恢复；连线标签支持原地编辑。
- 已有连线的端点可重接到另一节点或解除绑定；取消拖拽、undo/redo 恢复端点与标签，取消标签编辑不增加历史记录。
- 分组/取消分组按钮与快捷键、Shift 整组切换、框选部分成员后整体拖动，以及双击仅编辑成员标签。
- 重复与多次粘贴产生独立 group ID，内部连线指向对应副本；组样式修改、删除与恢复不破坏组外连接。
- 对齐以组为单元并保留内部位置；取消分组后可等间距分布。分组在草稿刷新及导出/重新导入后保持完整。
- 单个节点、普通多选和分组通过统一手柄拉伸；Shift 保持宽高比，Markdown 按新宽度排版。验证了最小尺寸、对角固定、点击手柄不跳变、Esc 取消，以及 50% 缩放时的坐标转换。
- 方向键长按和组合方向键只产生一条历史，Shift 使用 10 单位步长；Esc 取消后忽略仍按住的重复事件。焦点切到标题或鼠标切换选区时提交旧事务，后续操作可以独立撤销。
- 标题输入框、标签编辑器、Monaco 保留方向键行为；方向键的世界坐标步长不随镜头缩放变化。拉伸期间其他编辑命令不打断当前指针事务，原有连线端点重连通过回归。
- Clean / Subtle / Sketch / Rough 四档视觉对照；新元素默认 Sketch，实色、斜线和交叉斜线可切换并保存。
- Canvas 像素检查：同一矩形内部，斜线覆盖约 21.8%、交叉斜线约 36.9%、实色 100%；椭圆边界外没有斜线溢出。撤销恢复相同像素，概览后返回阅读视图恢复原来的斜线图案。
- Markdown 手绘边框平移后路径完全相同；切换 Clean / Sketch 不重建公式 DOM，刷新保留内容和样式。
- 卡片各自建立 stacking context，重叠时下层 SVG 边框不会穿过上层正文；实际点击重叠区域选中上层卡片。
- 真实 Canvas 缓存检查覆盖平移复用、颜色和尺寸失效、LRU 淘汰、16 MiB 像素上限、超大形状的矢量回退，以及删除和 dispose 后释放 Canvas 像素；自由笔移动复用路径，采样点变化使路径失效。

新增组织测试覆盖可选 group ID 的导入校验、扁平合组、选择展开、组内/组外连线、复制引用重建、六向对齐、负间距分布、首尾位置固定与事务撤销；不足所需布局单元的操作保持原场景。

变换测试覆盖四角的固定对角、混合节点与自由端点缩放、组外绑定不变、等比例约束、最小成员尺寸、微小旧节点无跳变、远景重叠手柄取最近角，以及预览、取消和单次历史。

手绘测试覆盖填充字段的严格导入校验、旧文档兼容、种子复现与平移不变性、平滑椭圆、精确箭头端点、极大尺寸的斜线数量上限，以及平滑自由笔在实际曲线上的命中。原始节点坐标与内容不因笔迹生成而改变。

主题测试覆盖全部五套站点 palette、语义色导入校验与往返、HEX 自定义色保持、实色/斜线背景上的 4.5:1 笔迹对比度、淡色填充与深色模式下的自动对比度调整，以及既有站点主题偏好逻辑。

绘图辅助新增 7 项 Node tests：四个方向的等比例与中心绘制、修饰键重算、45° 箭头长度与锚点、缩放后的吸附阈值、最近对齐、排除选区/笔迹/连线及远处行列，以及整组吸附的连线跟随与历史。

真实浏览器操作覆盖 Shift 正方形、Shift+Alt 正圆、指针静止时切换修饰键、Q 连续绘图、Esc 返回选择、45° 箭头、单次撤销与取消；移动吸附参考线通过 Canvas 像素检查，Alt 绕过、80% 缩放坐标、分组整体位移与连线保持绑定均通过。拖动后回到起点不留下预览位移，Alt+Shift 单击的默认图形也保持中心和等比例。标题输入中的 Q 不切换工具锁定；390–1920px 宽度下顶部工具栏不越界或相互重叠。

通过站点 Settings 和 ThemeToggle 验证全部五套 palette：Canvas 缓存颜色、连线标签背景、手绘卡片边框和 Markdown 表格同步更新，自定义 HEX 填充保持原值；切换不会修改白板 JSON 或创建 undo。

编辑引用 Markdown 时跨 Dawn / Moon 切换，Monaco 使用对应站点主题并保留中英文草稿，保存写回测试源文件。Follow device 随模拟系统明暗变化切换，刷新后仍跟随；手动模式也通过立即刷新检查。发现站点主题原先的 2 秒持久化节流可能丢失快速刷新前的选择，已将主题偏好单独改为即时保存，其他状态的节流策略不变。

浏览器 fixture 位于 `tests/fixtures/whiteboard-server.mjs`，创建独立临时目录，使用真实文件 handler，不加载仓库 dotenv。鉴权与 allowed roots 的 HTTP 行为由上述 Node 测试单独覆盖。

## 性能

固定场景见 `tests/fixtures/whiteboard-scene.ts`：597 个形状、199 个文字节点、204 个 Markdown 节点，共 1000 个节点、1000 条连线。阅读视口包含真实公式、代码、表格及 Mermaid；概览使用细节分级。

下表是初版未启用标签的记录；当前 fixture 已为全部形状和连线添加标签，并将节点按每 5 个分成 200 组，800 条组内连线共享对应 group ID。扩展回归结果列在后文。

环境：Linux，AMD EPYC 7763，浏览器报告 16 个逻辑处理器；Headless Chromium 146，1920 × 1080、DPR 1，ANGLE / Vulkan SwiftShader 软件渲染，Vite 开发模式。

脚本 `tests/fixtures/whiteboard-benchmark.mjs` 导出 `benchmarkWhiteboard(page)`。在 fixture 的 `?benchmark` 页面执行；每项先等待富内容及字体就绪，再预热 40 帧、采样 240 帧。数据使用 rAF 帧间隔衡量稳定交互，不代表任意机器、任意节点内容下的性能保证。

| View     | Interaction | Mean FPS | P95 frame (ms) | Max frame (ms) |
| -------- | ----------- | -------: | -------------: | -------------: |
| Reading  | Pan         |     58.8 |           16.8 |           33.4 |
| Reading  | Zoom        |     56.5 |           33.3 |           33.4 |
| Reading  | Drag        |     60.0 |           16.8 |           16.8 |
| Overview | Pan         |     60.0 |           16.7 |           16.8 |
| Overview | Zoom        |     57.8 |           16.8 |           33.4 |

五项均达到平均 >=55 FPS、P95 <=33.4ms 的目标。阅读视口挂载 6–7 个富内容 DOM 卡片，概览不挂载富内容 DOM。页面 warm reload 至内容/字体就绪为 1.18–1.36 秒；未测量无缓存的首次启动时间。

优化依据：初始概览约 32–36 FPS；重复路径提交与栅格化、约 2px 点距的密集网格、空交互层合成是已观测到的开销。最终采用概览 Canvas 位图变换、分级网格和空交互层隐藏；阅读视图保持直接绘制。

### 图编辑扩展回归

同一环境与采样方式，597 个形状和 1000 条连线均携带标签：

| View     | Interaction | Mean FPS | P95 frame (ms) |
| -------- | ----------- | -------: | -------------: |
| Reading  | Pan         |     59.5 |           16.8 |
| Reading  | Zoom        |     59.3 |           16.8 |
| Reading  | Drag        |     60.0 |           16.7 |
| Overview | Pan         |     60.0 |           16.7 |
| Overview | Zoom        |     58.5 |           16.8 |

五项均通过性能目标。内容与字体就绪等待为 0.94–3.86 秒，独立于稳定帧率统计。新增测试覆盖无标签旧文档、标签字段校验、文字裁剪与保留、标签命中范围、端点重连与历史。

### 分组与布局扩展回归

同一环境、标签和采样方式，新增 200 个组（每组 5 个节点、4 条内部连线）。阅读视图拖拽选中 9 个元素，同时移动 5 个真实 Markdown 卡片；其余连线继续跟随绑定节点。

| View     | Interaction | Mean FPS | P95 frame (ms) | Max frame (ms) |
| -------- | ----------- | -------: | -------------: | -------------: |
| Reading  | Pan         |     58.1 |           16.8 |           33.4 |
| Reading  | Zoom        |     57.6 |           16.8 |           33.4 |
| Reading  | Group drag  |     58.5 |           16.8 |           33.4 |
| Overview | Pan         |     60.0 |           16.7 |           16.8 |
| Overview | Zoom        |     55.8 |           33.3 |           50.1 |

五项均达到既定平均帧率与 P95 目标；概览缩放出现一次 50.1ms 最大帧间隔。内容与字体就绪等待为 1.07–1.33 秒。该结果仍仅对应上述固定场景与软件渲染环境。

### 选区变换扩展回归

同一环境和 200 组固定场景，新增阅读视图整组拉伸，5 个 Markdown 卡片同步改变位置和宽高并实时排版。

| View     | Interaction  | Mean FPS | P95 frame (ms) | Max frame (ms) |
| -------- | ------------ | -------: | -------------: | -------------: |
| Reading  | Pan          |     59.3 |           16.7 |           50.1 |
| Reading  | Zoom         |     58.1 |           16.8 |           50.0 |
| Reading  | Group drag   |     59.3 |           16.8 |           66.6 |
| Reading  | Group resize |     57.8 |           16.8 |           33.4 |
| Overview | Pan          |     56.0 |           16.8 |           66.7 |
| Overview | Zoom         |     59.0 |           16.8 |           33.4 |

六项均达到平均 >=55 FPS、P95 <=33.4ms 的目标，仍存在个别较长帧；内容与字体就绪等待为 1.10–1.36 秒。

优化前整组拉伸为 53.1 FPS，阅读缩放为 54.3 FPS。CPU 采样中 `jsxDEV` 占约 31% 样本，Markdown layout 约 0.8–1.0ms/帧；因此将工具栏和底部导航拆为独立 memo 组件，避免几何更新时重复构建不变控件。复测保留 Vite development mode，没有通过切换运行模式降低验证负载。

### 手绘风格回归

固定样本已使用 roughness 2 的双笔迹形状、箭头和 Markdown 边框，597 个形状混合实色、斜线和交叉斜线填充。采样环境、数量和步骤与前文一致。

| View     | Interaction  | Mean FPS | P95 frame (ms) | Max frame (ms) |
| -------- | ------------ | -------: | -------------: | -------------: |
| Reading  | Pan          |     59.5 |           16.7 |           33.4 |
| Reading  | Zoom         |     58.1 |           16.8 |           33.4 |
| Reading  | Group drag   |     60.0 |           16.7 |           16.8 |
| Reading  | Group resize |     56.7 |           33.3 |           50.0 |
| Overview | Pan          |     60.0 |           16.7 |           16.8 |
| Overview | Zoom         |     59.0 |           16.8 |           33.4 |

六项均达到既定平均帧率与 P95 目标；warm reload 至内容和字体就绪为 1.03–1.31 秒。

卡片 stacking context 修正后的定向拉伸复测为 55.8 FPS、P95 33.3ms、最大 33.4ms，仍达到目标。

优化前拖动约 44.7 FPS、拉伸约 40 FPS。对照检查中隐藏 SVG 边框仅改善约 1 FPS，临时改为实色填充改善约 10 FPS，确认反复栅格化斜线是主要开销。最终缓存形状笔迹和填充位图（16 MiB 像素上限，文字独立绘制），并将样式控件 memo 化；保留完整手绘外观和交互。以上仍为 SwiftShader 软件渲染的固定场景结果。

### 站点主题回归

同一 1000 节点 / 1000 连线场景，分别使用 VS Code Light Modern 和 Rosé Pine Moon；设备、软件渲染模式及采样方式同上。

| Palette              | View     | Interaction  | Mean FPS | P95 frame (ms) | Max frame (ms) |
| -------------------- | -------- | ------------ | -------: | -------------: | -------------: |
| VS Code Light Modern | Reading  | Pan          |     59.0 |           16.8 |           50.0 |
| VS Code Light Modern | Reading  | Zoom         |     58.5 |           16.8 |           50.0 |
| VS Code Light Modern | Reading  | Group drag   |     60.0 |           16.8 |           16.8 |
| VS Code Light Modern | Reading  | Group resize |     57.1 |           33.3 |           33.4 |
| VS Code Light Modern | Overview | Pan          |     60.0 |           16.8 |           16.8 |
| VS Code Light Modern | Overview | Zoom         |     59.0 |           16.8 |           50.0 |
| Rosé Pine Moon       | Reading  | Pan          |     59.5 |           16.8 |           33.4 |
| Rosé Pine Moon       | Reading  | Zoom         |     58.1 |           16.8 |           33.4 |
| Rosé Pine Moon       | Reading  | Group drag   |     60.0 |           16.8 |           16.8 |
| Rosé Pine Moon       | Reading  | Group resize |     57.1 |           33.3 |           33.4 |
| Rosé Pine Moon       | Overview | Pan          |     60.0 |           16.7 |           16.8 |
| Rosé Pine Moon       | Overview | Zoom         |     59.3 |           16.8 |           33.3 |

12 项均达到平均 >=55 FPS、P95 <=33.4ms 的目标，仍有少量 50ms 长帧。底部导航只订阅可见缩放百分比，操作时读取最新镜头，避免平移触发无效控件渲染；平移后按钮缩放的中心锚点通过浏览器检查。warm reload 至内容和字体就绪为 1.16–1.43 秒。

### 绘图辅助与控件回归

同一 1000 节点 / 1000 连线、200 组混合场景，VS Code Light Modern，1080p / DPR 1 / Chromium 146 / SwiftShader / Vite development mode；继续使用 40 帧预热和 240 帧采样。移动启用新的对齐吸附，工具栏使用 SVG 图标与快捷键提示。

| View | Interaction | Mean FPS | P95 frame (ms) | Max frame (ms) |
| --- | --- | ---: | ---: | ---: |
| Reading | Pan | 59.5 | 16.8 | 33.4 |
| Reading | Zoom | 58.1 | 16.8 | 33.4 |
| Reading | Group drag | 59.5 | 16.8 | 33.3 |
| Reading | Group resize | 58.3 | 16.8 | 33.4 |
| Overview | Pan | 60.0 | 16.7 | 16.8 |
| Overview | Zoom | 59.3 | 16.8 | 33.4 |

六项均通过既定性能目标；warm reload 至富内容及字体就绪为 1.14–1.37 秒。该结果只对应固定场景，未扩展到任意文档或机器。

### 图层顺序回归

2026-09-11 在 macOS / Apple M5 Pro 上使用 Node 24.16.0，69 项通过，无跳过：

```sh
TMPDIR=/private/tmp node --test tests/whiteboard.test.mjs tests/whiteboard-organization.test.mjs tests/whiteboard-transforms.test.mjs tests/whiteboard-sketch.test.mjs tests/whiteboard-theme.test.mjs tests/whiteboard-drawing.test.mjs tests/whiteboard-stacking.test.mjs tests/site-theme.test.mjs tests/file-access.test.mjs tests/websocket-auth.test.mjs
```

macOS 默认临时目录使用 `/var` 别名，而文件授权返回 `/private/var` 的 canonical 路径，直接运行原文件测试会有 6 项路径相关失败。上述命令指定 canonical 临时目录后全部通过，没有修改文件授权实现或测试。

新增 7 项 focused tests 覆盖稳定重排、连续选区单步移动、三层独立排序、混合分组、128 种选区组合的按钮可用状态、命中顺序、持久化与历史；边界 no-op 保留 redo。

通过已有 Playwright CLI 和 Edge Chromium 153.0.4234.32 验证：

- 四个按钮与 Cmd/Ctrl + `[` / `]`、Shift 组合快捷键，边界禁用状态；Canvas 实际像素与点击后标签编辑器确认前后顺序一致。
- 混合形状、Markdown 和连线的分组、多选；每层成员保持相对顺序，卡片 DOM 顺序与指针目标同步更新。
- 在文档中早于重叠形状的卡片，阅读与 33% 概览均显示在形状上方；概览用 Canvas 像素及截图核对，回到阅读后保持卡片顺序。
- 键盘微调与重排分成两条历史；指针手势、标题输入框和标签编辑器中的快捷键不会改变图层顺序。
- 草稿刷新恢复、导出再导入，以及真实文件 handler 保存成功后重新加载；读取保存文件与导出文件确认元素内容、几何、分组和连接数据完整，仅顺序变化。

继续使用固定 1000 节点 / 1000 连线场景，40 帧预热、240 帧采样。性能环境为 1920×1080、DPR 1、Edge headless、ANGLE Metal Renderer（Apple M5 Pro）、Vite development mode；与前述 Linux / SwiftShader 记录的硬件和渲染模式不同，不作直接性能对比。

| View     | Interaction  | Mean FPS | P95 frame (ms) | Max frame (ms) |
| -------- | ------------ | -------: | -------------: | -------------: |
| Reading  | Pan          |     60.0 |           16.8 |           16.8 |
| Reading  | Zoom         |     60.0 |           16.7 |           16.8 |
| Reading  | Group drag   |     60.0 |           16.7 |           16.8 |
| Reading  | Group resize |     60.0 |           16.7 |           16.8 |
| Overview | Pan          |     60.0 |           16.7 |           16.8 |
| Overview | Zoom         |     60.0 |           16.8 |           16.8 |

六项均达到既定性能目标，warm reload 至富内容和字体就绪为 0.19–0.67 秒。前端 TypeScript 使用 `node node_modules/typescript/bin/tsc -p tsconfig.app.json --ignoreDeprecations 6.0 --pretty false`，前后均为同样的 8 项已有诊断，没有新增；`pnpm format` 完成，保留 54 项已有 lint warnings。

## 静态验证与限制

- `pnpm format` 完成；现有 lint warnings 保留。
- 前端和服务端配置均执行 TypeScript 检查，并使用内存中的修改前源码对比诊断。原有前端 8 项、服务端配置 26 项诊断不变，没有新增诊断；这不等于全项目类型检查通过。
- 原有诊断示例：`src/container/code-editor/CodeEditor.tsx` 的 Monaco option 类型不匹配；服务端 tsconfig 包含客户端 API，产生 DOM 类型诊断。本次未扩展修复范围。
- 外部编辑器不共享本应用的写入队列；revision 检查与原子文件替换不是跨进程的绝对 compare-and-swap。
- 没有新增 package 或修改依赖版本；AI 后续接入。
