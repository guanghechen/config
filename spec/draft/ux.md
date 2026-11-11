# Filetree / Explorer 后续讨论

Status: Draft。仅记录跨重启恢复与虚拟资源（VFS）两类未确认范围，不作为当前实现或验收前提。
当前契约见 [Filetree Design](../design/ux/filetree/README.md) 与 [Explorer Design](../design/feat/explorer/README.md)。

## 跨重启恢复

是否恢复 display root、展开、逻辑光标、选区或任务仍需单独决定；
若扩展，必须先定义失效资源、资源替换和未完成 IO 的恢复边界，不能仅保存路径并重放旧任务。

## VFS

- 未来通过 Rust provider 接入；资源不保证具有本地 filepath，也不通过临时落盘来补齐 Git/LSP 能力。
- Capability、资源标识、异步操作与变更通知接口尚未确定。
- 虚拟文件的 buffer 编辑、保存与 LSP/Git 集成需另行设计。
- 与 provider capability 一起确定 Explorer 在能力缺失时的动作与反馈，不要求所有资源转换成本地文件。
