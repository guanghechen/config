# Themes

[Architecture](../arch.md) · [Ghostty](ghostty.md) · [Zed](zed.md)

The theme system combines a scheme with each application's definition and
template. Generated files live in the application config directories, often in
sibling worktrees. Schemes, templates, and lifecycle code are the editable source.

## Source model

| Source                                             | Responsibility                                                       |
| -------------------------------------------------- | -------------------------------------------------------------------- |
| [asset/theme/scheme](../../asset/theme/scheme)     | Scheme identity, appearance, native palettes, and shared color roles |
| [asset/theme/template](../../asset/theme/template) | Per-app definitions and complete templates                           |
| [cli/theme.mjs](../../cli/theme.mjs)               | `gen`, `apply`, and `toggle` orchestration                           |
| [cli/theme/config.mjs](../../cli/theme/config.mjs) | Definition validation and runtime app construction                   |
| [cli/theme/util.mjs](../../cli/theme/util.mjs)     | Scheme loading, template selection, rendering, and file writes       |
| [cli/theme/types.d.ts](../../cli/theme/types.d.ts) | Scheme and lifecycle contracts                                       |

A scheme supplies `theme`, `variant`, `opposite`, `darken`, and `palette`, with
an optional `uuid`. Its full name is `theme-variant`, or `theme` without a
variant. `opposite` names the target variant for one toggle operation.

`palette.<family>` holds native swatches; `palette.unified` holds shared roles
such as `bg0`, `fg0`, and `brightBlue`. The loader resolves named swatch
references in the JSON before rendering. For example,
[catppuccin-mocha.json](../../asset/theme/scheme/catppuccin-mocha.json) defines
`palette.unified.bg0` as `{{base}}` from its native palette.

## Template contract

Every app directory provides `meta.mjs` and `default.hbs`. The renderer selects
`{scheme.theme}.hbs` when present, otherwise `default.hbs`. A family template
replaces the default completely; there is no merge.

The `.hbs` files use Handlebars-style delimiters, but expressions are evaluated
as JavaScript by the local renderer. Bindings include scheme identity,
`darken`, `unified`, family palettes, platform flags, `c256`, and `compositeHex`.

```hbs
background = {{unified.bg0}}
foreground = {{unified.fg0}}
```

Default templates must work across families through `unified` or explicit
fallbacks. Family templates may use their native palette directly. Rendering
errors can leave `{{...}}` in the result rather than aborting the operation;
unresolved output must be treated as a failure during validation.

## App definition

`meta.mjs` default-exports the complete definition. The app name comes from its
directory. Imports must not mutate state; mutations belong in lifecycle hooks.
See [Alacritty's definition](../../asset/theme/template/alacritty/meta.mjs) for
a small example.

| Field      | Meaning                                                            |
| ---------- | ------------------------------------------------------------------ |
| `location` | Absolute application config directory                              |
| `active`   | Eligibility predicate: `env`, `file`, `directory`, or nested `all` |
| `themes`   | Relative directory for generated themes, or `null`                 |
| `extname`  | Generated filename suffix                                          |
| `local`    | Selected config path, or `null` for hook-only application          |

`on_render` replaces rendering, `on_prepare` validates an application,
`on_apply` replaces the default selected-file write, and `on_after_apply` /
`on_after_gen` run after the respective operation. Hooks own app-specific
integration, including reloads and additional generated files.

## Operations

Run from the repository root:

| Command                             | Behavior                                                                            |
| ----------------------------------- | ----------------------------------------------------------------------------------- |
| `node cli/theme.mjs gen`            | Render every eligible app × scheme and run each app's `on_after_gen`                |
| `node cli/theme.mjs apply [theme]`  | Apply the given or stored theme, run app hooks, then save the selection on success  |
| `node cli/theme.mjs toggle [theme]` | Resolve one `opposite` transition and apply it; a scheme without one stays selected |

Apply first prepares all eligible apps. If any preparation fails, it does not
start the apply phase. Once preparation succeeds, app writes run concurrently.
There is no cross-app rollback: a failure may leave some applications updated.
An individual adapter can provide stronger guarantees, as
[Ghostty](ghostty.md#state-and-recovery) does for its own files.

These commands have side effects. `gen` writes files and can run post-generation
work such as cache rebuilds. `apply` can signal running applications, invoke a
Neovim helper, and reload the tmux theme when `TMUX` is present. Use isolated
fixtures for tests that must not affect the current desktop or terminal sessions.

## Palette decisions

Native terminal ANSI colors and shared app accents are separate concerns. Keep
upstream swatches in the family palette; put cross-app readability adjustments
in `unified`. App-only values belong in the app template.

Gemini's ordinary message and input fills are controlled by the user preference
`ui.useBackgroundColor = false` in `~/.gemini/settings.json`, independently of
the selected theme. Keep its RGB background palette because it also supplies
contrast and state colors. Theme apply only touches the settings file to prompt
a reload; it never rewrites user preferences or creates a missing settings file.

OpenCode 1.18.4 also uses the root `background` as attachment badge foreground.
Keep that value RGB so File/Directory labels remain visible. It also uses
`backgroundMenu` for clickable tool-block hover, so keep its RGB value or its
fallback to `backgroundElement`. Panel and ordinary diff-context backgrounds
use `none`; root and menu surfaces retain fills because these tokens also serve
as attachment foreground and hover feedback.

- **Rosé Pine:** retain the native ANSI mapping and use `unified.fg1` for
  ordinary terminal text. Dawn uses deeper ink and accents; neutral selections
  and diff fills retain readable foregrounds.
- **Catppuccin:** preserve official swatches and Latte's reversed neutral ANSI
  slots. Body text, secondary text, mauve, and pink have distinct shared roles.
- **Kanagawa:** preserve Wave, Dragon, and Lotus ANSI mappings. Shared UI roles
  carry the readability adjustments without changing the native palette.
- **Tokyo Night:** retain official ANSI colors, including HSLuv-derived bright
  swatches. Shared roles tune secondary text and Day's contrast.
- **VSC:** complete `vsc.hbs` templates own their mappings through `vsc.*`.
  Sources and app-port references are recorded in
  [VSC Theme References](../theme-vsc-references.md); Zed's separate mapping is
  described in [its adapter document](zed.md).

## Kit STT

`asset/theme/template/kit/` 为 Kit STT 生成深浅色配对 JSON。`default.hbs` 使用 unified
颜色角色，`vsc.hbs` 保留 VSC app 独立映射约定。`meta.mjs` 将当前 scheme 与明确声明的 family 深浅色配对渲染为同一文件的
`light` / `dark`；保留所选 variant，另一种外观使用配对表。`opposite` 可以是同为深色的
循环切换，因此不用于推断 brightness。未知 family 或配对外观不正确时明确报错。`gen` 写入
`~/.config/kit/.theme/<scheme>.json`，`apply` 原子替换 `.theme/local.json`。
文件包含 `version: 1` 及两个 palette；每个 palette 都包含 `background`、`foreground`、
`muted`、`accent`、`recording`、`error`、`border` 的 `#RRGGBB` 值。应用专用的颜色映射
放在 template 中，保证文字在浮层背景上的对比度。STT 的 `desktop.theme.file` 指向
`../.theme/local.json`，`mode` 为 `dark`、`light` 或跟随系统的 `device`。
应用主题只发布 palette，不重启 STT 或修改其 config；浮层下一次显示时读取新 palette。

## Validation

`npm test` covers scheme loading, template resolution, application ordering,
and adapter contracts. After changing schemes, templates, or app definitions,
regenerate the affected outputs and check for unresolved expressions and the
target application's config errors. Application reload and visual validation
are separate from successful file generation.
