# 从素材到幻灯片 Image Prompt 的转换方法

将原始素材（文本、数据、概念）转化为高质量的图像生成提示词。

---

## 1. 整体流程架构

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│     Raw     │     │   Content   │     │   Visual    │     │    Image    │
│   Material  │ ──▶ │   Analysis  │ ──▶ │   Design    │ ──▶ │   Prompt    │
│  输入素材   │     │  内容分析   │     │  视觉设计   │     │  生成提示   │
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘
```

---

## 2. 阶段一：内容分析

### 2.1 提取核心信息

| 信息类型     | 提取目标       | 示例                           |
|--------------|----------------|--------------------------------|
| **主题**     | 这页在讲什么？ | "用户从搜索转向寻求建议"       |
| **关键词**   | 2-5 个核心概念 | Search, Companionship, Advice  |
| **关系**     | 概念之间的逻辑 | 对比、因果、递进、并列         |
| **情感基调** | 积极/中性/警示 | 积极、充满希望                 |

### 2.2 确定叙事模式

根据内容逻辑选择合适的叙事结构：

```
内容逻辑            →  叙事模式      →  视觉布局
────────────────────────────────────────────────────────
A 变成 B            →  转变/演变     →  左右对比 + 箭头
多个并列要点        →  列表/枚举     →  垂直堆叠 + 符号
数据趋势            →  图表叙事      →  曲线/柱状涂鸦
问题 → 解决方案     →  挑战-应对     →  上下或对角布局
总结收尾            →  结论强调      →  层级递进 + 口号
```

---

## 3. 阶段二：视觉设计

### 3.1 建立视觉词汇表

为抽象概念选择具象符号：

| 抽象概念 | 视觉符号           | 理由       |
|----------|--------------------|------------|
| 搜索     | 🔍 放大镜          | 通用认知   |
| AI       | 🤖 机器人/齿轮     | 科技感     |
| 情感     | ❤️ 心形            | 普遍象征   |
| 成长     | 📈 上升曲线/植物   | 积极隐喻   |
| 连接     | 🤝 握手/桥梁       | 关系可视化 |
| 想法     | 💡 灯泡/气泡       | 经典符号   |

### 3.2 确定风格一致性

为整个演示文稿建立统一的视觉语言：

```
风格参数：
├── 整体美学：hand-drawn, pen-sketch, doodle
├── 背景材质：textured paper, notebook paper, kraft paper
├── 线条特征：sketchy, loose, imperfect
├── 字体风格：handwritten, script, casual
└── 色彩倾向：monochrome / limited palette / warm tones
```

---

## 4. 阶段三：Prompt 模板化

### 4.1 通用结构模板

```
Generate an image of a [slide type] in [art style] on [background].

Title at [position]: "[TITLE TEXT]".

[MAIN VISUAL CONTENT - 按空间位置描述]

[SUPPORTING TEXT - 说明文字]

[DECORATIVE ELEMENTS - 装饰元素]

Maintain the overall [aesthetic consistency].
```

### 4.2 具体模板示例

**转变型（A → B）：**

```
Generate an image of a hand-drawn slide visualizing [transformation theme].
Title: "[INSIGHT N: Title]".
On the left, draw [symbol for OLD state] with label "[OLD]".
Draw a large sketchy arrow pointing right.
On the right, draw [symbol for NEW state] with [details].
Below, write: "[Key message explaining the shift]".
Keep consistent [style] look.
```

**列表型（要点罗列）：**

```
Generate an image of a [style] slide on [background].
Title: "[TITLE]".
Below, write [N] bullet points with [bullet style]:
"* [Point 1]"
"* [Point 2]"
"* [Point 3]"
At bottom, in [emphasis style]: "[TAGLINE]".
Add [decorative element] in [position].
Maintain [aesthetic].
```

---

## 5. 实现方案

### 方案 A：LLM Pipeline

```
┌────────────────────────────────────────────────────────┐
│                      LLM Pipeline                      │
├────────────────────────────────────────────────────────┤
│                                                        │
│  [输入素材] ──▶ [分析 LLM] ──▶ [结构化中间表示]        │
│                                     │                  │
│                                     ▼                  │
│                             [Prompt 生成 LLM]          │
│                                     │                  │
│                                     ▼                  │
│                             [Image Gen Prompts]        │
│                                                        │
└────────────────────────────────────────────────────────┘
```

**分析 LLM 的 Prompt 示例：**

```
你是一个演示文稿设计专家。分析以下素材，输出结构化 JSON：

{
  "slide_type": "transformation | list | data | conclusion",
  "title": "...",
  "key_concepts": [...],
  "narrative_structure": "A→B | parallel | hierarchy",
  "visual_symbols": [
    {"concept": "...", "symbol": "...", "position": "..."}
  ],
  "main_message": "...",
  "emotional_tone": "..."
}
```

### 方案 B：模板 + 槽位填充

预定义一组高质量模板，通过槽位填充生成：

```python
TEMPLATES = {
    "transformation": """
Generate an image of a hand-drawn slide visualizing a trend shift.
Title at the top: "{title}".
On the left, draw a doodle of {old_symbol} over the word "{old_label}".
Draw a large, sketchy arrow pointing to the right.
On the right side, draw {new_symbol}.
Below this, write: "{key_message}".
Keep the consistent hand-sketched look.
""",

    "conclusion": """
Generate an image of a final concluding slide in a hand-drawn style on textured paper.
Title at the top: "{title}".
Below the title, write bullet points with star doodles:
{bullet_points}
At the bottom, in larger bolder script: "{tagline}".
Add {decoration} in the bottom right corner.
Maintain the pen-sketch aesthetic.
"""
}
```

---

## 6. 质量提升技巧

### 6.1 空间描述要精确

```
❌ 模糊：Add some decorations
✅ 精确：Add a small doodle of X in the bottom right corner
```

### 6.2 层次感要清晰

```
❌ 平铺：Write title, points, and tagline
✅ 层次：Title at top → bullet points below → tagline at very bottom in larger bolder script
```

### 6.3 风格词要统一复现

在每个 prompt 结尾强化风格：

- `Maintain the overall pen-sketch aesthetic`
- `Keep the consistent hand-sketched look`
- `Use the same doodle style throughout`

---

## 7. 完整工作流示例

**输入素材：**

> "我们的研究发现，2024年用户与AI的互动方式发生了根本转变。过去用户把AI当作搜索工具，现在他们期望AI成为生活伙伴，帮助他们处理健康、工作、情感等复杂议题。"

**Step 1 - 分析输出：**

```json
{
  "slide_type": "transformation",
  "title": "INSIGHT: From Tool to Companion",
  "old_state": {"concept": "搜索工具", "symbol": "magnifying glass", "label": "SEARCH"},
  "new_state": {"concept": "生活伙伴", "symbol": "two figures conversing", "details": "speech bubbles with hearts"},
  "key_message": "Users now seek AI as a life partner for health, work, and emotional support",
  "decoration": null
}
```

**Step 2 - 生成 Prompt：**

```
Generate an image of a hand-drawn slide visualizing a behavioral shift.
Title at the top: "INSIGHT: From Tool to Companion".
On the left, draw a simple magnifying glass icon over the word "SEARCH".
Draw a large sketchy arrow pointing to the right.
On the right, draw two stick figures (one with antenna) having a warm conversation, with speech bubbles containing small hearts.
Below the right illustration, write in handwritten text: "Users now seek AI as a life partner for health, work, and emotional support."
Keep the consistent hand-sketched look on textured paper.
```

---

## 8. 总结

| 阶段     | 关键动作                       | 目标            |
|----------|--------------------------------|-----------------|
| **理解** | 提取概念、识别逻辑关系         | 知道「说什么」  |
| **设计** | 选择叙事模式、分配视觉符号     | 知道「怎么说」  |
| **表达** | 精确的空间描述、一致的风格语言 | 让 AI「画出来」 |

核心要义：**将抽象逻辑转化为空间叙事**——不只是描述元素，而是用视觉讲故事。
