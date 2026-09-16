# Architecture

This repository manages personal dotfiles and setup for Linux/WSL, macOS, and
Windows. The checkout contains shared tooling and configuration sources;
application configs usually live in sibling worktrees under `~/.config`.

## Read by topic

- [Settings](arch/settings.md): stored preferences, shell loaders, and CLI writes.
- [Themes](arch/theme.md): schemes, templates, app definitions, and lifecycle.
- [Setup](arch/setup.md): platform entrypoints, execution order, and failure rules.
- [Ghostty](arch/ghostty.md): permanent display settings, background selection,
  and state recovery.
- [Zed](arch/zed.md): theme publishing and ownership of its generated settings layer.

## Repository map

| Path                                   | Responsibility                                                  |
| -------------------------------------- | --------------------------------------------------------------- |
| [cli/](../cli)                         | Command entrypoints and orchestration                           |
| [src/env.mjs](../src/env.mjs)          | Platform detection and checkout-relative paths                  |
| [src/setting.mjs](../src/setting.mjs)  | Settings normalization and persistence                          |
| [src/stl/src/](../src/stl/src)         | Shared CLI, serialization, and reporting primitives             |
| [asset/app/](../asset/app)             | App-specific configuration sources and assets                   |
| [asset/theme/](../asset/theme)         | Scheme JSON, app definitions, and templates                     |
| [asset/wallpaper/](../asset/wallpaper) | Image assets                                                    |
| [env/](../env)                         | Checked-in shell defaults/loaders and generated local overrides |
| [setup/](../setup)                     | Platform setup entrypoints and shared helpers                   |

Most app paths derive from the checkout's parent directory in `src/env.mjs`.
Adapters with native path rules, such as Zed, resolve those paths themselves.
Node modules use the subpath imports declared in [package.json](../package.json),
including `#env`, `#setting`, `#stl/*`, and `#util/*`.

## Boundaries

- Settings describe user preferences; changing a stored theme does not itself
  apply that theme to applications.
- Schemes own palettes and shared color roles. App templates own their mappings;
  lifecycle hooks own application-specific writes and reloads.
- Generated app configs are outputs. Edit their source scheme, template, or
  definition and regenerate rather than changing the output by hand.
- Setup coordinates installation and worktree preparation. Shell loaders consume
  static settings without starting Node just to read them.

## Validation and side effects

Run `npm test` from the repository root for the CLI test suite. Theme generation
writes application files; theme application can also reload running programs.
Neither is a read-only check. Their sequencing and failure limits are documented
in [Theme operations](arch/theme.md#operations).

Contributor rules remain in [AGENTS.md](../AGENTS.md). Theme reference provenance
is recorded separately in [VSC Theme References](theme-vsc-references.md).
