# Filetree 后续接入讨论

Status: Draft。仅保留未定稿的扩展方向，不作为当前实现或验收前提。
当前资源、watch、文件操作、冲突与成功项清理见 [Filetree Design](../design/filetree.md)；
已接入的 consumers 与 records 路径见 [Treeview 设计](../../doc/spec/treeview/README.md)。

## VFS

- 未来通过 Rust provider 接入；资源不保证具有本地 filepath，也不通过临时落盘来补齐 Git/LSP 能力。
- Capability、资源标识、异步操作与变更通知接口尚未确定；现阶段不创建未使用的插件框架。
- 虚拟文件的 buffer 编辑、保存与 LSP/Git 集成需另行设计；加密 DB 等 provider 不扩大当前 filesystem 契约。
