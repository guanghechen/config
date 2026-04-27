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

# Image Paste (Windows) - 搜索 keybinding
rg --text '==="windows"\?"alt\+v":"ctrl\+v"' /path/to/executable

# Image Paste (Windows, 可选) - 某些版本有 displayText/check(meta) 片段
rg --text 'displayText:' /path/to/executable

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

2. Windows 平台 patch 组合随版本变化：
   - 通用必需：`win-image-paste-keybinding`（将 keybinding 从 `alt+v` 改为 `ctrl+v`）
   - 部分版本：`win-image-paste-shortcut`（将 displayText/check 中的 `meta` 改为 `ctrl`）
   - 旧版本（≤ 2.1.29）：`win-image-paste-ctrl-v`（在 `wrappedOnInput` 中添加 Ctrl+V 检测逻辑）

3. WSL/Linux 平台 patch：
   - `checkImage-grep-pattern`（< 2.1.50）: 添加 BMP 格式支持（2.1.50 已内置）
   - `wl-paste-bmp-conversion`: 添加 BMP 到 PNG 转换（magick fallback）

### Step 5: 测试

```bash
node index.mjs
```

确认输出显示 `Patched` 而非 `Pattern not found`。

**Windows 测试 checklist**：
- [ ] `win-image-paste-keybinding` 显示 `Patched` 或 `Already patched`
- [ ] 如版本包含对应 patch，`win-image-paste-shortcut` / `win-image-paste-ctrl-v` 显示 `Patched` 或 `Already patched`
- [ ] 在 Claude Code 中按 Ctrl+V 能粘贴剪贴板中的图片
