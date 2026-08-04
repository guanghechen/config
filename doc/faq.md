# FAQ

## macOS

### Neovim 运行时崩溃 (Code Signature Invalid)

**症状**：Neovim 启动后运行一段时间突然崩溃（非正常退出），崩溃日志位于 `~/Library/Logs/DiagnosticReports/nvim-*.ips`，显示：

```
Exception Type: EXC_BAD_ACCESS
Signal: SIGKILL (Code Signature Invalid)
Termination Namespace: CODESIGNING
Termination Indicator: Invalid Page
```

**原因**：macOS 运行时代码签名验证失败。原生库（`.so`、`.dylib`）的 adhoc 签名在某些情况下会被 macOS 判定为无效，特别是在系统更新后或库文件被修改后。

涉及的库可能包括：
- `~/.config/nvim/lua/yoz.so`
- `~/.local/share/nvim/treesitter/parser/*.so`
- `~/.local/share/nvim/lazy/*/target/release/*.dylib`（如 blink.pairs、blink.cmp）

**解决方案**：重新对相关原生库进行 adhoc 签名：

```bash
# 重签名 yoz.so
codesign --remove-signature ~/.config/nvim/lua/yoz.so
codesign -s - ~/.config/nvim/lua/yoz.so

# 重签名 treesitter parsers
for f in ~/.local/share/nvim/treesitter/parser/*.so; do
  codesign --remove-signature "$f"
  codesign -s - "$f"
done

# 重签名 lazy 插件的原生库
find ~/.local/share/nvim/lazy -name "*.dylib" -o -name "*.so" | while read f; do
  codesign --remove-signature "$f"
  codesign -s - "$f"
done
```

**注意**：`node rust/script/build.mjs` 会自动签名 `yoz.so`；更新其他原生库后，可能仍需重新执行签名操作。
