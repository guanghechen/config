# Platform setup

[Architecture](../arch.md) · [Settings](settings.md) · [Themes](theme.md)

Setup entrypoints prepare runtimes and application worktrees, synchronize local
settings, and apply the selected theme. They install packages and modify the
machine; they are not validation commands for documentation or theme changes.

## Entrypoints

| Platform     | Entrypoint                                                       | Distinction                                                      |
| ------------ | ---------------------------------------------------------------- | ---------------------------------------------------------------- |
| Linux / WSL  | [setup/nix/setup.bash](../../setup/nix/setup.bash)               | Requires `sudo` and `apt`; adds Windows Terminal setup under WSL |
| Remote Linux | [setup/nix-remote/setup.bash](../../setup/nix-remote/setup.bash) | Smaller runtime/app set and `nix-remote` edition                 |
| macOS        | [setup/osx/setup.bash](../../setup/osx/setup.bash)               | Reuses Unix helpers with Homebrew and font adjustments           |
| Windows      | [setup/win/setup.ps1](../../setup/win/setup.ps1)                 | Requires PowerShell 7.4+, Git, winget, Cargo, and rustc          |

## Execution order

1. Check prerequisites, prepare base environment, and clone or fast-forward
   this repository.
2. Bootstrap shell settings and package-manager integration.
3. Prepare the selected runtimes; refresh the shell environment when needed.
4. Ensure Cargo and `kit-repo`, attach the `kit` worktree, set its
   `config.edition`, and run `kit-repo sync` to prepare app worktrees and local
   settings.
5. Run platform config and app installers, require Node, then apply the theme.
   Print the collected result of optional steps.

`kit-repo` setup preserves a local development executable in
`$CARGO_HOME/local/bin`; otherwise it installs the published package into Cargo's
normal `bin`. Entrypoints prefer the local executable (`kit-repo.exe` on Windows)
and fall back to the installed one. Worktree preparation and local-settings sync are fatal:
later stages depend on their output. The sync call remains outside the step
wrapper because `kit-repo` renders its own output.

## Failure and scope rules

Required failures abort immediately. Optional failures are collected, allow
later steps to continue, and make the final summary fail. Environment/app leaves
are generally optional; prerequisite checks and worktree preparation are not.
The entrypoint declares the status of each step.

- [Bash step helper](../../setup/nix/bot/step.bash): ordinary leaf scripts run
  under isolated `bash -e -o pipefail`. Explicit in-place steps are used for
  environment refreshes whose changes must survive in the caller.
- [PowerShell step helper](../../setup/win/bot/step.ps1): steps run in child
  scopes within the setup process, so process environment changes persist.
  PowerShell and native-command errors terminate by default. Required failures
  throw with the original exit code in `Exception.Data["ExitCode"]`; expected
  nonzero probes opt out at their call sites.

Both helpers render flat sections containing independent step trees. The
entrypoints supply icons and labels; the helpers handle indentation, combined
output, and summaries. This presentation does not change failure semantics.

## Environment bootstrap

[setup/nix/bot/env.bash](../../setup/nix/bot/env.bash) sources the checked-in
[settings loader](../../env/setting.bash), then prepares available Homebrew,
Cargo, fnm, and Miniforge paths/hooks. It is sourced, rather than run as a child
process, when its environment changes are needed by later steps.

Windows persists its base environment before repository setup and then sources
[env/setting.ps1](../../env/setting.ps1). Local settings are synchronized later
through the same `kit-repo` stage used on Unix.

Setup behavior is covered by `cli/setup-step*.test.mjs` and
[cli/setup-kit-repo.test.mjs](../../cli/setup-kit-repo.test.mjs). These tests use
fixtures; running the actual setup entrypoints exercises machine mutations.
