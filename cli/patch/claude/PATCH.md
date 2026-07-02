# Claude Code Patch

Runtime patches for Claude Code CLI.

Latest verified on WSL: Claude Code `2.1.198`

## Scope

Only one patch is maintained: **WSL clipboard image format/source**.

- The `Ctrl+V` keybinding (trigger image paste) is **not** patched. Configure it via
  `~/.config/claude/keybindings.json` (`ctrl+v: chat:imagePaste`, requires Claude Code v2.1.18+).
  This applies to both Windows and WSL — neither needs a runtime patch for the keybinding.
- Native Windows and pure Linux (non-WSL) need no patch from here.

## Patch: WSL Clipboard Image

WSL reads the WSLg Wayland clipboard via `xclip`/`wl-paste`, so:

| Issue                                              | Solution                                            |
| -------------------------------------------------- | --------------------------------------------------- |
| Image copied on the Windows side is not in WSL     | Helper reads the Windows clipboard first (powershell)|
| WSLg exposes BMP that bundled libvips cannot decode | Helper converts BMP → PNG (needs ImageMagick)       |

`checkImage` / `saveImage` are rerouted to `wsl-image-paste.bash`, which performs the above.

## Usage

```bash
node index.mjs
```

## Files

| File                    | Description                    |
| ----------------------- | ------------------------------ |
| `index.mjs`             | Entry point                    |
| `patch-image-paste.mjs` | WSL clipboard image patch      |
| `wsl-image-paste.bash`  | WSL clipboard helper           |
| `util.mjs`              | Patch utilities                |
| `types.mjs`             | Type definitions (JSDoc)       |

## Dependencies

- WSL: `imagemagick` (for BMP → PNG conversion)

## Adding Support for New Versions

When Claude Code updates, add a new entry for the new version. The framework matches
`patch.version` against `claude --version` exactly, so a new version needs a new entry.

### Step 1: Get the version

```bash
claude --version
```

### Step 2: Locate the executable

```bash
realpath $(which claude)
```

> **Note**: Claude Code may be `cli.js` (Node.js script) or a native binary (ELF/PE).
> The framework auto-detects: native binaries are read/written as `latin1` (byte-preserving),
> script files as `utf-8`.

### Step 3: Find the pattern to patch

Minified variable names change every release; locate by the surrounding command string.
For an ELF binary add `--text`:

```bash
rg --text 'wl-paste --type image/png' /path/to/executable
```

### Step 4: Add the new-version entry

Copy the existing `wsl-image-paste-checkImage` / `wsl-image-paste-saveImage` entries in
`patch-image-paste.mjs`, bump `version`, and adjust `search` to the new surrounding text if it
changed. Keep entries in descending version order (newest first).

### Step 5: Test

```bash
node index.mjs
```

**WSL checklist**:
- [ ] `wsl-image-paste-checkImage` / `wsl-image-paste-saveImage` show `Patched` or `Already patched`
- [ ] `~/.config/claude/keybindings.json` has `ctrl+v: chat:imagePaste`
- [ ] `Ctrl+V` in Claude Code pastes the clipboard image (including a Windows-side BMP)
