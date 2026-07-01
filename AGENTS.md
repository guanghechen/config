# Wiki / Troubleshoot 工作目录

## 这个 repo 是什么

个人 wiki 与 troubleshoot 知识库:沉淀参考知识与问题排查记录,同时作为锚点引导 agent 的工作方式。**本仓库开源、公开可见。**

## Agent 工作约定

### 输出优先,按需沉淀

- **默认**:对咨询与调试问题直接给出高质量回答,**不主动创建或修改 repo 内文件**。
- **仅当我显式说"记下来 / 归档 / 存成 wiki"** 时,才把结论落盘,并遵循下方目录与命名规范。
- 沉淀前若目标位置或分类不明确,先问一句再写。

### ⚠️ 隐私与敏感数据(开源仓库,务必小心)

本仓库公开可见。落盘任何内容前必须脱敏,**严禁写入**:

- **密钥类**:API key、token、密码、私钥、连接串。
- **身份类**:真实姓名、邮箱、电话及其他 PII。
- **环境类**:内网 endpoint / 主机名 / IP、公司内部服务名、私有仓库路径。
- **本地信息**:绝对路径中的用户名等不宜公开的信息。

troubleshoot 记录最易带入真实环境信息 —— 一律用占位符替换(如 `<API_KEY>`、`user@example.com`、`10.x.x.x`、`/path/to/project`)。发现疑似敏感串时**先停下确认,不要直接落盘或提交**。

### 目录规范

- `topics/<领域>/` — wiki 参考知识(长期有效、经整理)。领域如 `ai/`、`neovim/`。
- `troubleshoot/` — 问题排查记录,文件名 `YYYY-MM-DD-<slug>.md`。
- `templates/` — 记录模板。
- `README.md` — 索引 / 导航,新增条目时同步一行。

### 记录格式

- Troubleshoot 记录套用 `templates/troubleshoot.md`(frontmatter:`title` / `date` / `tags` / `env` / `status`)。
- Wiki 条目套用 `templates/topic.md`,至少含一级标题与 `tags`。

### 输出风格

- 回答用简体中文,保留英文技术术语;较长回答附 `TL;DR`。
- Markdown 表格与 ASCII 图保持视觉对齐(CJK 记 2 宽,ASCII 记 1 宽)。
