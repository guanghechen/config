# Claude Code Patch

Runtime patches for Claude Code CLI.

## Patches

### 1. Image Paste

跨平台图片粘贴支持，统一使用 `Ctrl+V`。

| Platform  | Issue                                                      | Solution                                       |
| --------- | ---------------------------------------------------------- | ---------------------------------------------- |
| Windows   | 默认 `Alt+V` 无效（Windows 不识别 `meta` 修饰键）          | 改用 `Ctrl+V` (`ctrl` 修饰键)                  |
| Windows   | Windows Terminal 不支持 bracketed paste mode               | 在 input handler 中直接检测 `Ctrl+V`           |
| WSL/Linux | `wl-paste` 可能输出 BMP 格式                               | 添加 BMP 支持，自动转 PNG (需 ImageMagick)     |

### 2. Context Window

统一 context window 为 **144K tokens**。

- Platforms: win / nix / osx / wsl
- Default: `144000`
- Custom: `node index.mjs [size]`

## Usage

```bash
# Apply all patches (default 144K context)
node index.mjs

# Custom context window size
node index.mjs 200000
```

## Files

| File                       | Description               |
| -------------------------- | ------------------------- |
| `index.mjs`                | Entry point               |
| `patch-image-paste.mjs`    | Image paste patches       |
| `patch-context-window.mjs` | Context window patches    |
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

### Step 2: 定位 cli.js

```bash
# Linux/macOS/WSL
realpath $(which claude)

# Windows (PowerShell)
where.exe claude
# 然后查看 node_modules/@anthropic-ai/claude-code/cli.js
```

### Step 3: 搜索需要 patch 的变量名

由于 minified 代码中变量名每版本都不同，需要通过特征模式定位：

```bash
# Context Window - 搜索默认值 128000
rg 'var \w+=128000' /path/to/cli.js

# Image Paste (Windows) - 搜索 windows 平台判断 + meta+v 快捷键
rg '==="windows"\?\{displayText:' /path/to/cli.js

# Image Paste (WSL/Linux) - 搜索 wl-paste 命令
rg 'wl-paste --type image/png' /path/to/cli.js
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

### Step 5: 测试

```bash
node index.mjs
```

确认输出显示 `Patched` 而非 `Pattern not found`。
