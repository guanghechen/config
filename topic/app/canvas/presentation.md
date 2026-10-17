---
title: 无限画布中的 Presentation 与动画设计
tags: [app, infinite-canvas, presentation, animation, design]
updated: 2026-09-18
---

# 无限画布中的 Presentation 与动画设计

**TL;DR**：推荐在现有画布之上增加一层**讲述结构**：`Presentation → Shot → Cue → Animation clip`。Shot 决定看哪里，Cue 决定一次推进展示什么，clip 决定属性如何随时间变化。Frame 是内容容器，可以被 Shot 引用；播放通过临时状态覆盖内容的显示，不逐帧改写文档。

适用于自由白板 / 知识整理应用内的二维 presentation，既支持镜头漫游，也支持固定画面中的逐步展示。以下是候选设计，尚未经过原型或性能验证；基础术语见[无限画布概念设计](README.md)。本文的 Shot 表示讲述画面，避免与已有空间对象集合 Scene 混用。

## 阅读导航

- [讲述模型](presentation/model.md)：Presentation、Shot、Cue、clip 与一个完整的讲述例子。
- [动画机制](presentation/animation.md)：镜头插值、对象动画、初始状态与点击编排。
- [播放与状态](presentation/playback.md)：确定性求值、导航、逻辑时钟、可访问性与验证标准。

## 推荐的第一版

推荐先做：有序 shots、frame / 固定矩形目标、点击 cues、cut / pan-zoom 转场、appear / fade / highlight / connector reveal，以及 Next / Previous / Pause / Jump。保留 clip 时间参数，暂缓通用关键帧编辑器、任意运动路径、物理弹簧、多媒体同步和复杂触发图。
