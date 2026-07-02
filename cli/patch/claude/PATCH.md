# Claude Code Patch

Runtime patches for Claude Code CLI.

Latest verified on WSL/Linux: Claude Code `2.1.198`

## Patches

### 1. Image Paste

WSL/Linux 剪贴板图片**格式**支持。键绑定（`Ctrl+V` 触发粘贴）已迁出本 patch，改由 `~/.config/claude/keybindings.json`（`ctrl+v: chat:imagePaste`，需 Claude Code v2.1.18+）配置。

| Platform  | Issue                               | Solution                                   |
| --------- | ----------------------------------- | ------------------------------------------ |
| WSL       | Windows 侧复制的图片不在 WSL 剪贴板 | helper 优先读取 Windows 剪贴板             |
| WSL/Linux | `wl-paste` 可能输出 BMP 格式        | 添加 BMP 支持，自动转 PNG (需 ImageMagick) |

### 2. Context Window (manual only)

> 默认 `index.mjs` **不再** patch context window — 新版默认 200K/1M 直接保留。
> 仅在需要时手动运行此脚本。

- Platforms: win / nix / osx / wsl
- Custom: `node patch-context-window.mjs [size]`

## Usage

```bash
# Apply image-paste patches (default flow)
node index.mjs

# (Optional) manually limit context window
node patch-context-window.mjs 144000
```

## Files

| File                       | Description               |
| -------------------------- | ------------------------- |
| `index.mjs`                | Entry point               |
| `patch-image-paste.mjs`    | Image paste patches       |
| `patch-context-window.mjs` | Context window patches    |
| `wsl-image-paste.bash`     | WSL clipboard helper      |
| `util.mjs`                 | Patch utilities           |
| `types.mjs`                | Type definitions (JSDoc)  |

## Dependencies

- WSL/Linux: `imagemagick` (for BMP → PNG conversion)

## Adding Support for New Versions

当 Claude Code 更新后，需要为新版本添加 patch。

### Step 1: 获取版本号

```bash
claude --version
```

### Step 2: 定位可执行文件

```bash
# Linux/macOS/WSL
realpath $(which claude)

# Windows (PowerShell)
where.exe claude
# 新版通常对应 node_modules/@anthropic-ai/claude-code/bin/claude.exe
# 旧版可能对应 node_modules/@anthropic-ai/claude-code/cli.js
```

> **Note**: Claude Code 可能是 `cli.js`（Node.js 文本脚本）或 native binary（ELF / PE，取决于平台和安装分发方式）。
> patch 框架会自动检测文件格式：native binary 用 `latin1` 编码读写以保证二进制字节不变，脚本文件用 `utf-8`。

### Step 3: 搜索需要 patch 的变量名

由于 minified 代码中变量名每版本都不同，需要通过特征模式定位：

```bash
# 对于 ELF 二进制文件，需要加 --text 参数
# Context Window - 搜索默认值 200000
rg --text 'var \w+=200000' /path/to/executable

# Image Paste (WSL/Linux) - 搜索 wl-paste 命令
rg --text 'wl-paste --type image/png' /path/to/executable
```

### Step 4: 添加新版本 patch

在对应的 patch 文件中添加新条目，参考现有 patch 的格式：

```javascript
{
  name: 'patch-name',
  version: 'x.y.z',           // 新版本号
  platform: ['win', 'wsl', 'nix', 'osx'],
  search: /var ABC=\d+/,      // 匹配模式（字符串或正则）
  replace: (content, matches) => replaceAll(content, matches, () => `var ABC=${targetSize}`),
  verify: (text) => text.includes(`var ABC=${targetSize}`),
}
```

**重要**：

1. patches 数组中高版本必须排在前面（降序排列），确保新版本的 patch 优先匹配。

2. Windows 键绑定（`Ctrl+V` 触发图片粘贴）不再由本 patch 处理，改用 `~/.config/claude/keybindings.json`（`ctrl+v: chat:imagePaste`，需 Claude Code v2.1.18+）。本 patch 仅保留 WSL/Linux 剪贴板格式相关条目。

3. WSL/Linux 平台 patch：
   - `checkImage-grep-pattern`（< 2.1.50）: 添加 BMP 格式支持（2.1.50 已内置）
   - `wl-paste-bmp-conversion`: 添加 BMP 到 PNG 转换（magick fallback）

### Step 5: 测试

```bash
node index.mjs
```

确认输出显示 `Patched` 而非 `Pattern not found`。

**WSL/Linux 测试 checklist**：
- [ ] `wsl-image-paste-checkImage` / `wsl-image-paste-saveImage`（或旧版 `checkImage-grep-pattern` / `wl-paste-bmp-conversion`）显示 `Patched` 或 `Already patched`
- [ ] 已配置 `~/.config/claude/keybindings.json`（`ctrl+v: chat:imagePaste`）
- [ ] 在 Claude Code 中按 Ctrl+V 能粘贴剪贴板中的图片（含 Windows 侧 BMP）
