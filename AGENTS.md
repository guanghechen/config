# AGENTS.md

本仓库是个人 `~/.config` dotfiles。核心子系统之一是**主题(theme)生成系统**:用一套 Handlebars(`.hbs`)模版配合配色方案(scheme),渲染出各应用各自的主题配置文件。

## 主题模版位置(改 app 主题从这里找)

- **配色方案**:`asset/theme/scheme/{theme}.json` —— 每个配色一个文件(如 `catppuccin-mocha.json`、`gruvbox-dark.json`、`tokyonight-night.json` 等)。
- **默认应用模版**:`asset/theme/template/{app}/default.hbs` —— 每个应用必须提供一个 fallback 模版。
- **theme family 模版**:`asset/theme/template/{app}/{family}.hbs` —— 可选;`family` 来自 scheme 的 `theme` 字段(如 `kanagawa`、`catppuccin`)。存在时优先于 `default.hbs`,同一 family 的 variants 共用该模版。
- **渲染器**:`cli/theme/_util.mjs`(`render_template` / `gen_themes_per_app` / `apply_theme_per_app`);CLI 入口 `cli/theme.mjs`;各 app 的输出目录、扩展名等在 `cli/theme/_config.mjs` 定义。

修改通用 app 主题时改 `default.hbs`;只有某个 theme family 确实需要独立映射时才新增或修改 `{family}.hbs`。family 模版是完整模版,不与 `default.hbs` merge 或继承。这些模版会被渲染成对应 app 的主题配置,并写入该 app 的 config 目录。

> **不要手改生成产物**(各 app config 目录下生成的主题文件)—— 每次 `gen`/`apply` 都会被覆盖。

## 渲染流程

`asset/theme/scheme/{theme}.json`(配色)+ `asset/theme/template/{app}/{family}.hbs`(优先)或 `default.hbs`(fallback)→ 渲染 → 写入该 app 的主题配置。

- `gen` / `generate`:对**所有** scheme 渲染,输出到 `app.home/app.themes/{theme}{app.extname}`。
- `apply [theme]`:对**当前(或指定)** scheme 渲染,输出到 `app.home/app.local`(单一 active 主题)。
- `toggle`:在配置的主题间切换。

改完模版后需重新生成再应用:

```sh
node cli/theme.mjs gen      # 生成全部 app × 全部 scheme
node cli/theme.mjs apply    # 应用当前 scheme
# 若已配置 shell 别名:ghc-theme gen && ghc-theme apply
```

## hbs 渲染约定

渲染器很简单:只做 `{{expression}}` 替换,`expression` 是一段**合法的 JavaScript 表达式**;表达式内可访问内置 JS 对象,以及注入的变量:

- 元信息:`name`、`theme`、`variant`、`opposite`、`darken`、`uuid`
- 平台标志:`IS_OSX`、`IS_WIN`、`IS_NIX`、`IS_WSL`
- 配色 palette:`catppuccin`、`gruvbox`、`kanagawa`、`rosepine`、`tokyonight`、`vsc`、`unified`(以及聚合对象 `palette`)
- 工具:`c256`(hex → ansi256 转换)

约定:

1. `default.hbs` 会渲染所有 family,不得假定某个 family palette 存在;优先使用 `unified`,或为 family palette 提供 fallback。`{family}.hbs` 只会渲染对应 family,可以直接使用该 family palette。
2. 表达式求值若抛错,该 `{{...}}` 会原样保留、不被替换(渲染器对每个表达式做了 try/catch),便于定位问题。
