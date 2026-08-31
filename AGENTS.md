# AGENTS.md

本仓库是个人 `~/.config` dotfiles。主题系统通过 scheme 与 Handlebars template 生成各应用配置；详细设计见 `doc/arch.md`。

## Theme sources

- Scheme：`asset/theme/scheme/{theme}.json`
- App definition：`asset/theme/template/{app}/meta.mjs`
- Fallback template：`asset/theme/template/{app}/default.hbs`
- Family template：`asset/theme/template/{app}/{family}.hbs`
- Runtime：`cli/theme.mjs`、`cli/theme/config.mjs`、`cli/theme/util.mjs`

## Rules

1. 不要手改生成产物；修改 scheme、template 或 `meta.mjs` 后重新生成。
2. 通用映射放在 `default.hbs`；仅当 theme family 需要独立映射时使用 `{family}.hbs`。Family template 是完整替代，不与 default merge。
3. 每个 app 必须同时提供 `meta.mjs` 和 `default.hbs`。`meta.mjs` default export 是完整 app definition；顶层不得产生副作用，mutation 仅放在 `on_*` lifecycle function 中。
4. `default.hbs` 必须适用于所有 family，优先使用 `unified` 或显式 fallback；family template 可以直接使用对应 palette。
5. Template expression 是 JavaScript expression；渲染失败时会保留原始 `{{...}}`，不得忽略未解析表达式。

## Validation

```sh
npm test
node cli/theme.mjs gen
node cli/theme.mjs apply
```

`gen` 生成全部 app × scheme；`apply [theme]` 应用当前或指定 theme；`toggle` 切换 opposite theme。
