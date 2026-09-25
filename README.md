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
