# Whiteboard v1 验证记录

## 2026-09-12：属性面板与操作图标

- 扩展同一套 SVG 至属性面板的锁定/隐藏、颜色/线宽、文字、编辑、变换、图层、分组/分布与删除；替换六种几何对齐的 Unicode 符号，并覆盖右键菜单、元素/区域列表、演示、编辑器及导出/文件对话框。
- 浏览器实测单选、多选、连线：直接点击 SVG 完成旋转/翻转、文字样式、锁定/隐藏、标签保存、折点增删/重置、对齐/分布、分组、复制/删除和撤销；区域重命名、步骤排序与演示进退正常。属性面板的操作按钮及字段标签均有 SVG；颜色色块保留颜色预览，手绘/填充保留原有 SVG 样例。
- 明暗主题截图核对；768px 下属性面板宽 232px，390/320px 下宽 184px，无横向溢出。窄屏导出、另存、引用和 Monaco 编辑器按钮保持可用，对话框页脚允许换行，主操作图标继承按钮前景色。
- 119 项 Node 回归通过，无失败/跳过；`pnpm format` 为 0 errors / 54 既有 warnings，前端 TypeScript 保留相同的 8 项既有诊断。没有新增依赖。

## 2026-09-12：文件菜单 SVG 图标

- 新增新建、文件导入/导出、图片导出、另存、添加图片、链接、保存、重新加载和 Markdown 引用 10 个 SVG 路径，复用 Workspace 图标；界面无新增图片资源或依赖。
- 浏览器验证草稿菜单 9 项、文件菜单 11 项都有装饰性 SVG；实际尺寸统一为 18×18px，路径不超出 viewBox，图标与文字两列对齐。320px 下菜单宽 288px，长标签保持单行；明暗主题均检查截图。
- 点击 SVG 本身可触发文件导出、图片导出入口、导入选择器、图片链接工具和源文件保存（HTTP 200）；选择后菜单收起，阅读模式的编辑操作保持禁用。`pnpm format` 为 0 errors / 54 既有 warnings，前端 TypeScript 保留相同的 8 项既有诊断。

## 2026-09-12：单行工具栏

- 文件、绘图、视图三组控件统一位于顶部一行，Hand 前移、Laser 后移；移除按窗口宽度将绘图工具挪到第二排的规则。标题编辑移入文件菜单，680px 以下使用 More tools，响应式判断来自白板自身尺寸。
- Edge / Playwright CLI 验证 1440、1024、1000、999、768、680、679、390、320px：三组顶部均为 12px、控件高度 52px，无重叠或越界。390/320px 的更多工具均可访问，阅读工具仍保持同一行。
- 实测 Hand 平移不修改文档、V/Q 快捷键、标题编辑、菜单 Enter/Esc 与外部点击、更多菜单焦点恢复、视图面板位置、主题/设置和导出入口。119 项 Node 回归通过，无失败或跳过。
- 在 1440px 窗口内将白板单独缩到 1024、768、500、320px，仍按容器宽度保持单行且不越界；标签编辑器打开时工具栏不接收指针操作，关闭后恢复。`pnpm format` 为 0 errors / 54 既有 warnings；前端 TypeScript 保留同样的 8 项既有诊断，无新增。

## 2026-09-12：agent 输入校验修复

- 复现并修复枚举强制转换：`arrange.mode: ["start"]` 曾被接受并执行右对齐，`reorder.order: ["front"]` 曾被当作后移，`shape: ["rectangle"]` 曾通过文档校验。现在按 schema 严格要求字符串，布局 axis 同样拒绝数组。
- 修复空 `nodeId` 被接受为自由端点，以及 `move.delta` 超过 ±10000000、但最终坐标仍合法时被接受的问题；自由端点继续通过省略 `nodeId` 表达。
- 新增 4 项回归，覆盖三种形状、布局/顺序枚举、两端绑定和两轴正负移动边界；扩展真实 CLI 测试，确认无效批次在 dry-run / apply 均失败且文件字节不变，已有文档和 redo 保留。新增用例在修复前复现失败，修复后通过。
- 完整 Node 回归 119 项通过，0 失败/跳过；`pnpm format` 为 0 errors / 54 既有 warnings。直接 TypeScript 检查仍为前端 8 项、Node 配置 26 项既有诊断，没有新增；本轮验证集中于共享校验、store 原子性与真实 CLI 文件操作。

## 2026-09-12：全屏预览交互修复

- 修复演示中打开 Mermaid 后按 Esc 会退出演示、却留下预览的问题。预览增加模态语义、初始焦点、Tab / Shift+Tab 循环和关闭后焦点恢复；白板与演示快捷键识别打开的模态窗口。
- 修复首次打开时滚轮监听未绑定，以及 Markdown 图片点击被白板指针捕获截走的问题。图库按钮移入预览的事件和焦点边界，左右位置保持不变。
- Edge 153 / Playwright CLI、1440×1000 实测：首次滚轮缩放从 1 变为 1.1，拖动平移 60×30px；白板镜头不变。预览中的删除、复制、方向键、双击和右键不修改文档或打开白板编辑器/菜单；Esc 只关闭预览，再次 Esc 才退出演示。
- 两张内嵌图片的方向键、左右按钮和焦点循环通过；打开实际 `.whiteboard` 文件后，在预览期间用 revision 保存新版，旧图保持可见并提示源文件变更，关闭预览后自动加载新标题和内容。
- 115 项 Node 回归通过，无失败或跳过；`pnpm format` 为 0 errors / 54 既有 warnings。前端 TypeScript 仍为同样的 8 项既有诊断，没有新增；本次未重跑性能基准。

## 2026-09-12：最终补齐结果（阶段 4–6）

- 最终回归：Node 24.16.0，`TMPDIR=/private/tmp node --test tests/whiteboard*.test.mjs tests/site-theme.test.mjs tests/file-access.test.mjs tests/websocket-auth.test.mjs`，115 项通过，0 失败/跳过。包含区域/步骤引用与原子批次、镜头/双指几何、导出范围与 PNG 上限，以及取消引用搜索后的请求清理与立即重订阅。
- 静态检查：`pnpm format` 为 0 errors / 54 既有 warnings。直接 TypeScript 检查前端 8 项、node 配置 26 项既有诊断，无新增；格式化造成的 lockfile 改动经 YAML 语义比较后恢复。
- 任意顺序：图形覆盖 Markdown、连线覆盖图形、跨类型置底/撤销、命中与列表顺序、被覆盖链接的隔离及恢复均通过；概览像素采样与阅读顺序一致。旧文件按原三层稳定转换，文件刷新基线不产生假冲突。
- 导出：实际下载 SVG/PNG 与复制 PNG，覆盖旋转、斜线、连线路线、空格/中文、公式、Mermaid、代码、表格、引用 Markdown 与透明图片。发现并修复首次栅格化时内嵌字体尚未解码的问题；全新浏览器首次 PNG 与剪贴板公式像素验证通过。选区 2× 输出为 468×411，包含透明与有色像素；隐藏元素不扩张画布。
- 导出异常：缺失图片、无效公式、无效 Mermaid、PNG 尺寸超限均明确失败；取消导出清理临时 DOM 和请求。2000 元素的混合场景成功导出 14,561,922 字节 SVG，约 22.7 秒，包含全部 2000 个元素，额外挂载上限 16。
- 导航/演示：从选区和视口建区、重命名、重复步骤与排序、minimap 聚焦、键盘换页、退出恢复镜头/工具、激光消退、阅读保护、画面外引用正文搜索均通过。使用 Chromium CDP 的真实 touch 事件验证双指同时 pan/zoom、单指继续 pan、取消绘图及历史隔离；编辑草稿期间阅读/演示入口禁用。
- 移动端：390×844 下 13 个工具按钮完整显示为两行，导航面板不覆盖工具栏；命名区域、演示和阅读入口可用，演示控件不超出视口。
- agent：实际 CLI create/inspect/validate、dry-run 不写入、revision apply、锁定修改失败后文件不变均通过；外部批次更新内容和区域后，打开的演示自动刷新并重新聚焦。退出恢复原镜头，外部版本作为新文件基线，不进入本地 undo。

最终性能环境：Apple M5 Pro、Edge headless 153、Metal、1920×1080、DPR 1、Vite development；1000 节点 + 1000 连线，混合富内容、路线、字体和旋转。每项预热 40 帧，采样 240 帧，minimap 开启。编辑视图 pan/zoom/drag/resize/rotate、激光、阅读模式 pan/zoom、全图概览 pan/zoom 共 10 项，平均约 59–60 FPS，全部 P95 16.7–16.8ms；最长单帧 66.7ms。阅读 pan 在空白处启动并核对镜头实际变化，激光确认绘制；不能以富内容点击或空操作代替手势。此前 Elements 打开的 8 项亦达标，仅挂载 23 行。

资源压力样本另验证 1000 个 Markdown 卡片与 1000 个 SVG 图形同时交错挂载，Canvas 数量不随图层数增长。该简单卡片样本用于验证资源分配，不替代上述富内容 FPS 基准。

SVG 富内容使用 foreignObject；已验证浏览器显示，其他不支持该 SVG 特性的图片工具应使用 PNG。系统字体由查看设备提供，Web 字体和图片嵌入文件。

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

### 能力补齐：图片、文件与 agent 接口

2026-09-11，Node 24.16.0 / macOS，以下 78 项测试通过，无跳过：

```sh
TMPDIR=/private/tmp node --test tests/whiteboard*.test.mjs tests/site-theme.test.mjs tests/file-access.test.mjs tests/websocket-auth.test.mjs
```

新增图片签名/布局、create-only 并发创建、agent 命令与 CLI 测试；既有文件 HTTP 测试扩展创建接口的鉴权、allowed roots、symlink、非法名称、无效内容、重名保护及 workspace 列表可见性。

Edge 153 / Playwright CLI 实际验证：

- 图片选择器、PNG 输入与静态图 WebP 优化、批量输入与单次 undo/redo、图片剪贴板和定位拖入、剪切与恢复。损坏文件或不支持的格式不会留下半批元素；解码期间修改白板会取消旧结果。
- PNG 透明背景和极端宽高比的静态图优化；图片显示区域与节点尺寸一致，不受标题栏/边框挤压。刷新后 data URL 图片正常恢复。
- workspace 列表与 Markdown 文件选择，引用后实际渲染；另存返回 201 并打开 canonical filepath，重名或已存在草稿不会被覆盖。localStorage quota 失败时仍可将当前版本另存为文件并安全离开。
- 外部 CLI 修改已打开文件后自动更新标题、标签与位置；编辑器打开时保留草稿，取消后载入最新文件。有本地修改时保留文档并提示外部版本，旧 revision 保存返回 409。
- 外部文件暂时写成无效 JSON 时保留最后有效场景，修复后自动恢复；显式重新加载可清除冲突并建立新的文件基线。

固定 1000 节点 / 1000 连线场景，Apple M5 Pro / ANGLE Metal / Edge headless / 1920×1080 / DPR 1 / Vite development，仍使用 40 帧预热、240 帧采样：六项 reading/overview 的 pan、zoom、group drag、group resize 均为 60.0 FPS，P95 16.7–16.8ms，最大 16.8ms；富内容与字体就绪为 0.19–0.65 秒。

完整 `pnpm format` 完成，保留 54 项既有 warnings；使用内存中的 HEAD 源码与当前源码对比 TypeScript 诊断，前端仍为 8 项、服务端配置仍为 26 项，无新增诊断。没有新增 package；formatter 对 lockfile 的无关格式化在工作区还原。

### 连线路线、控制点与样式

2026-09-11：新增 7 项 connector tests，全部 85 项回归通过，无跳过。覆盖严格字段校验、曲线/折线命中、路线标签位置、独立箭头、控制点移动/复制/布局/拉伸、事务撤销，以及 agent 切换路线时的控制点重建。

Edge 153 / Playwright CLI 验证曲线控制点拖动与 Esc/undo/redo、折点增删及重置、端点解绑/重连、绑定节点移动、分组微调、复制 remap、草稿恢复和导出/重新导入。Canvas 像素检查中，500 像素长的采样行上实线覆盖 100%、虚线 71.2%、点线 33.2%；虚线/点线箭头沿笔迹采样均为完整不透明像素。

固定 1000 节点 / 1000 连线场景增加 `?benchmark&connectors` 变体，混合 straight/polyline/curve、solid/dashed/dotted 与不同端点箭头。基线与变体各测 reading pan/zoom/group drag/group resize、overview pan/zoom，共 12 项均为 60.0 FPS、P95 16.7–16.8ms、最大 16.8ms。环境仍为 Apple M5 Pro、ANGLE Metal、Edge headless、1920×1080、DPR 1、Vite development；40 帧预热、240 帧采样。富内容与字体就绪为 0.18–0.87 秒。

### 文字样式与自动尺寸

2026-09-11：新增 6 项 typography tests，全部 91 项回归通过，无跳过。覆盖可选字段兼容与校验、词与 grapheme 换行、长单词测量上界、省略号、shape/text 自动尺寸、标签对齐与测量边界、归一化历史、手动拉伸退出 autoSize，以及 agent 尺寸覆盖规则。

通过 Edge 153 / Playwright CLI 验证普通文字和图形/连线标签的字体、字号、粗体与对齐；Monaco 内容修改后尺寸和内容一起 undo/redo；手动拉伸退出自动尺寸并可撤销；中文、emoji、长文本、标签精确命中和刷新恢复。修复了空白单击被当作 1×1 框选误选连线的问题，只有实际拖动才执行框选。

外部文件使用 1×1 宽高提示和 autoSize:true 时，页面按实际字体计算尺寸。CLI 更新文字和字号后自动更新展示；字号输入框存在未提交值时，外部更新延后并保留输入，取消输入后应用新版本。刷新不会把归一化尺寸误判成本地冲突。

基线与 `?benchmark&connectors&typography` 两组 1000 节点 / 1000 连线场景，共 12 项 reading/overview pan/zoom/group drag/group resize 均约 60.0 FPS、P95 16.7–16.8ms、最大 16.8ms。环境为 Apple M5 Pro / ANGLE Metal / Edge headless / 1920×1080 / DPR 1 / Vite development，40 帧预热、240 帧采样。富内容与字体就绪为 0.19–1.71 秒。

### 旋转与翻转

2026-09-11：新增 9 项 pose tests，全部 100 项回归通过，无跳过。覆盖节点姿态校验、局部/世界坐标逆变换、旋转后的命中与边界绑定、整组变换、镜像组合、局部尺寸手柄、直角/任意角度多选拉伸、自动尺寸原点、部分绑定线的旋转轴，以及 store/agent 历史。

Edge 153 / Playwright CLI 验证角度输入、旋转手柄、Shift 15° 吸附、Esc/undo/redo、旋转节点的固定对角拉伸和精确命中；图片/Markdown 的 DOM 镜像与旋转、正向编辑器、混合组旋转、完整撤销及刷新恢复。四象限图片截图核对了旋转后世界水平镜像的像素方向；自动文字在旋转/镜像后修改字号保持局部原点，撤销和刷新不漂移；旋转自由笔只在线路上响应命中。

固定 1000 节点 / 1000 连线场景增加 `?benchmark&connectors&typography&transforms`，在 Node 5 以后混合角度与镜像，并新增 reading group rotation。基线 7 项均为约 60 FPS；变体 reading pan 59.0、zoom 58.3、drag/resize/rotation 60.0，overview pan 60.0、zoom 59.3。14 项 P95 均为 16.7–16.8ms，达到既定目标；变体有少量 50–83.4ms 长帧。旋转项额外确认了选中 Markdown 卡片的实际 CSS 旋转，避免误测空手势。环境仍为 Apple M5 Pro / ANGLE Metal / Edge headless / 1920×1080 / DPR 1 / Vite development，40 帧预热、240 帧采样。

## 静态验证与限制

- `pnpm format` 完成；现有 lint warnings 保留。
- 前端和服务端配置均执行 TypeScript 检查，并使用内存中的修改前源码对比诊断。原有前端 8 项、服务端配置 26 项诊断不变，没有新增诊断；这不等于全项目类型检查通过。
- 原有诊断示例：`src/container/code-editor/CodeEditor.tsx` 的 Monaco option 类型不匹配；服务端 tsconfig 包含客户端 API，产生 DOM 类型诊断。本次未扩展修复范围。
- 外部编辑器不共享本应用的写入队列；revision 检查与原子文件替换不是跨进程的绝对 compare-and-swap。
- 没有新增 package 或修改依赖版本；AI 在外部运行，通过文件与命令接口交互，不内置 provider 或多人协作。


## 2026-09-12：对象保护与组织

- 7 项 protection tests：flags 校验与复制、组保护、连带删除、绑定跟随、agent 显式解锁、擦除路径、隐藏吸附；完整 Node 回归累计 107 项。前端 TypeScript 仍为既有 8 项，formatter 0 errors / 54 既有 warnings；lockfile 仅格式差异按语义比较后恢复。
- Edge 153 实际操作通过：组锁定后的键盘/鼠标/删除保护、快捷键解锁、锁定连线阻止删节点、隐藏节点/卡片与列表恢复、全文搜索、Ctrl-click 重叠轮换、右键选择、复制/定位粘贴、复制锁定状态、单击擦一层、锁定前景不穿透、拖动整组擦除、Esc 与一次 undo。
- 延迟 clipboard 实测：读取期间启动键盘移动会拒绝粘贴；复制期间改变选区会保留原对象并提示重新剪切。源文件在菜单打开时更新只提示，关闭菜单后自动载入。
- M5 Pro / Edge headless 153 / 1920×1080 / DPR1 / Vite dev，1000 节点 + 1000 连线，包含多路线、文字、旋转/镜像；每项预热 40 帧后测 240 帧。Elements 全程打开，仅挂载 23 行。reading pan/zoom/drag/resize/erase/rotate 均约 60 FPS，P95 16.7–16.8ms；overview pan 60 FPS、zoom 59.0 FPS，P95 16.8ms、最长 50.1ms。擦除实测元素从 2000 降至 1989，旋转确认真实作用于卡片。
