# Agent instructions

This is the Bash counterpart of `../fish`. See [README.md](README.md) for setup and startup behavior.

- Keep shared variable names, helpers and local configuration conventions aligned with fish; preserve Bash-specific startup guards and duplicate-free PATH updates.
- Define overridable defaults in `config.bash` under `## local`, before sourcing local overrides. Compute derived values afterward.
- Use `.bash` files. Match `ghc-*` function names to filenames; prefix private helpers with `_ghc_*`.
- Do not read or copy `local/`; it may contain credentials.
- Check changed scripts with `bash -n` and ShellCheck when available. Validate startup changes with isolated fixtures and stub app hooks, never real user configuration.
