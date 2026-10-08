# Filetree 后续接入讨论

Status: Draft。仅保留未定稿的扩展方向，不作为当前实现或验收前提。
当前资源、watch、文件操作、冲突与成功项清理统一见 [Filetree Design](../design/filetree.md)。

## VFS

- 未来通过 Rust provider 接入；资源不保证具有本地 filepath，也不通过临时落盘来补齐 Git/LSP 能力。
- Capability、资源标识、异步操作与变更通知接口尚未确定；现阶段不创建未使用的插件框架。
- 虚拟文件的 buffer 编辑、保存与 LSP/Git 集成需另行设计；加密 DB 等 provider 不扩大当前 filesystem 契约。

## 其他 consumers

Picker、Searcher、Diffview 当前仍使用现有 Lua API。后续迁移需分别确认它们的数据、选择、展示与生命周期需求，
不因 Explorer 已迁移而自动切换。
