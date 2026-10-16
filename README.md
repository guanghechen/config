## Requirements

* conda

  ```fish
  #>>> conda initialize >>>
  # !! Contents within this block are managed by 'conda init' !!
  eval /opt/me/app/anaconda3/bin/conda "shell.fish" "hook" $argv | source
  # <<< conda initialize <<<
  ```

* fnm: https://github.com/Schniz/fnm

  ```fish
  brew install fnm
  fnm install 20
  ```

## Local configuration

Use `local/env.fish` for machine-specific settings. In `config.fish`, follow this initialization order:

1. Define defaults for variables that support local overrides in the `## local` section.
2. Source `local/env.fish` after those defaults.
3. Compute derived values and apply fixed settings in the subsequent sections.

When an existing variable needs to support local overrides, move its default assignment into `## local`, before the `source` block. For example, define `KIT_COPILOT_URL` there and derive the API endpoint URLs after loading local overrides.

## Upstream maintenance

Scripts adapted from external projects include an `Upstream reference` URL in their header. These URLs identify the corresponding upstream source, not a version already synced. Review changes against a specific tag or commit, port relevant changes manually, and record that revision in the change description. Regenerate CLI-generated completions using their documented command.

The `functions/fzf-*.fish` functions are maintained locally, with key bindings in `conf/keymap.fish`; no Fish plugin installation is needed. When syncing from [PatrickF1/fzf.fish](https://github.com/PatrickF1/fzf.fish), preserve local function names and bindings, token expansion without `eval`, and variable selection without reading or previewing variable values. Review upstream helpers and initialization for dependencies before porting changes.

After porting fzf changes, check Fish syntax and verify multi-select, cancellation, paths with spaces or newlines, and multiline history commands.
