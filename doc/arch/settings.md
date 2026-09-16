# Settings

[Architecture](../arch.md) · [Setup](setup.md) · [Themes](theme.md)

The settings layer stores the selected theme and installation preferences in a
format that both the Node CLI and shell setup scripts can consume.

## Ownership and files

- [cli/setting.mjs](../../cli/setting.mjs) parses command-line options.
- [src/setting.mjs](../../src/setting.mjs) owns the `Setting` API: defaults,
  normalization, loading, and saving.
- [src/stl/src/env.mjs](../../src/stl/src/env.mjs) parses and serializes exports.
- [env/setting.bash](../../env/setting.bash) and
  [env/setting.ps1](../../env/setting.ps1) contain checked-in shell defaults and
  load adjacent `setting.local.bash` / `setting.local.ps1` overrides.

`Setting.load()` reads the Bash local file, normalizes known fields, and falls
back to its own platform defaults when needed. It does not read the checked-in
shell defaults or the PowerShell mirror. `save()` merges supported fields and
writes both local formats; unknown exports are not retained. The two writes
are not a transaction, so a write failure can leave the mirrors out of sync.
Export keys are validated against `[A-Z][A-Z0-9_]*` before serialization.

During setup, `kit-repo sync` also publishes local settings. Shell consumers
source the static loaders; reading settings does not require a Node process.

## Stored values

| Export                   | Values / meaning                         |
| ------------------------ | ---------------------------------------- |
| `GHC_EDITION`            | `nix`, `nix-remote`, `osx`, or `win`     |
| `GHC_THEME`              | Full scheme name, e.g. `vsc-dark-modern` |
| `GHC_APP_EDITION_NODE`   | Preferred Node.js major version          |
| `GHC_APP_EDITION_NVIM`   | `latest`, `nightly`, or `manual`         |
| `GHC_APP_EDITION_TMUX`   | `latest`, `nightly`, or `manual`         |
| `GHC_APP_PYTHON_ENV`     | Conda environment name                   |

The runtime platform (`nix`, `wsl`, `osx`, `win`, or `unknown`) is detected by
[src/env.mjs](../../src/env.mjs). It is distinct from the stored setup edition;
for example, WSL uses the `nix` edition by default.

## Usage

Run CLI commands from the repository root:

```sh
node cli/setting.mjs --print
node cli/setting.mjs --print-theme
node cli/setting.mjs --set-node-edition 24
node cli/setting.mjs --set-nvim-edition manual
node cli/setting.mjs --set-tmux-edition latest
node cli/setting.mjs --set-python-env lemon
node cli/setting.mjs --set-theme catppuccin-mocha
```

Setting `GHC_THEME` changes the stored preference. Use the
[theme CLI](theme.md#operations) to render and apply it to applications.

Bash setup sources `env/setting.bash`; PowerShell setup sources
`env/setting.ps1`. Both resolve local overrides relative to the loader file.
