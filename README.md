# git-delta

配置由 `../guanghechen/asset/theme/template/git-delta/` 生成：

- `base.conf` 保存公共行为，定义 `base` 和单栏 `unified` feature。
- `theme/*.conf` 只定义各主题的配色 feature。
- `config.conf` 是未跟踪的本机入口，include 公共配置和所选主题，并启用
  `features = base <theme>`。全局 Git 配置继续 include 此文件。

修改公共行为时编辑源目录的 `base.conf`；修改配色时编辑对应的
`*.hbs`，然后重新生成。不要手改生成产物。

在 `guanghechen` 仓库运行 `node cli/theme.mjs gen` 会生成所有应用主题；
`node cli/theme.mjs apply <theme>` 会应用主题到所有已启用的应用。
git-delta 的 apply 会同时发布公共配置、所选主题和入口，因此不要求先运行 gen。
入口通过 include 引用主题，后续 gen 会直接更新当前配色。

临时使用单栏布局：

```sh
git --no-pager diff | DELTA_FEATURES=+unified delta
```

`+` 表示在默认 features 后追加覆盖项。将可覆盖的设置放入 named feature；
直接写在 `[delta]` 下的选项会优先于所有 features。
