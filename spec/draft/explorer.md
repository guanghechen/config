# Explorer 后续交互讨论

Status: Draft。仅保留尚未确认的后续范围，不覆盖 [Explorer Design](../design/feat/explorer.md)。
默认键位、无选区动作、确认/退出、空树目标和 buffer 冲突均已由 Design 定义，不再维护第二份键位表。

## 跨重启恢复

当前只持久化显示偏好与宽度。是否恢复 display root、展开、逻辑光标、选区或任务仍需单独决定；
若扩展，必须先定义失效资源、资源替换和未完成 IO 的恢复边界，不能仅保存路径并重放旧任务。

## 虚拟资源

与 [Filetree 的 VFS 讨论](filetree.md#vfs) 一起确定能力缺失时的动作与反馈，不要求所有资源转换成本地文件。
