---@alias era.m.acp.MessageRole
---| "user"
---| "assistant"
---| "system"

---@alias era.m.acp.ToolStatus
---| "pending"
---| "running"
---| "completed"
---| "error"

---@alias era.m.acp.StreamChunkType
---| "text"
---| "thinking"
---| "thinking_start"
---| "tool_use_start"
---| "tool_use_delta"
---| "tool_use_end"
---| "error"
---| "done"

----------------------------------------------------------------------------------------------------

---@class era.m.acp.IImageContent
---@field public type                   "image"
---@field public data                   string
---@field public mime_type              string
---@field public uri                    ?string

---@class era.m.acp.IAudioContent
---@field public type                   "audio"
---@field public data                   string
---@field public mime_type              string

---@class era.m.acp.IEmbeddedResource
---@field public uri                    string
---@field public text                   ?string
---@field public blob                   ?string
---@field public mime_type              ?string

---@class era.m.acp.IResourceContent
---@field public type                   "resource"
---@field public resource               era.m.acp.IEmbeddedResource

---@class era.m.acp.ITextContent
---@field public type                   "text"
---@field public text                   string

---@alias era.m.acp.IContentBlock
---| era.m.acp.ITextContent
---| era.m.acp.IImageContent
---| era.m.acp.IAudioContent
---| era.m.acp.IResourceContent

---@class era.m.acp.IMessage
---@field public id                     string
---@field public role                   era.m.acp.MessageRole
---@field public content                string|era.m.acp.IContentBlock[]
---@field public tool_calls             ?era.m.acp.IToolCall[]
---@field public timestamp              integer

---@class era.m.acp.IToolCall
---@field public id                     string
---@field public name                   string
---@field public arguments              table
---@field public arguments_json         ?string
---@field public status                 era.m.acp.ToolStatus
---@field public result                 ?string
---@field public error                  ?string
---@field public expanded               ?boolean

---@class era.m.acp.IToolResult
---@field public output                 ?string
---@field public error                  ?string
---@field public is_error               boolean

---@class era.m.acp.IStreamChunk
---@field public type                   era.m.acp.StreamChunkType
---@field public content                ?string
---@field public tool_call_id           ?string
---@field public tool_name              ?string
---@field public tool_arguments_delta   ?string
---@field public error                  ?string

----------------------------------------------------------------------------------------------------

---@class era.m.acp.IRequestOpts
---@field public session                era.m.acp.Session
---@field public cwd                    ?string
---@field public messages               era.m.acp.IMessage[]
---@field public system_prompt          ?string
---@field public abort                  stl.c.Observable
---@field public on_chunk               fun(chunk: era.m.acp.IStreamChunk): nil
---@field public on_done                fun(): nil
---@field public on_error               fun(err: string): nil

---@class era.m.acp.IProvider
---@field public name                   era.m.acp.ProviderName
---@field public config                 era.m.acp.IProviderConfig
---@field public send                   fun(self: era.m.acp.IProvider, opts: era.m.acp.IRequestOpts): fun(): nil

----------------------------------------------------------------------------------------------------

---@alias era.m.acp.PlanPriority
---| "high"
---| "medium"
---| "low"

---@alias era.m.acp.PlanStatus
---| "pending"
---| "in_progress"
---| "completed"

---@class era.m.acp.IPlanEntry
---@field public content                string
---@field public priority               era.m.acp.PlanPriority
---@field public status                 era.m.acp.PlanStatus

---@class era.m.acp.IPlan
---@field public entries                era.m.acp.IPlanEntry[]

---@class era.m.acp.IContextFile
---@field public path                   string
---@field public type                   ?string

----------------------------------------------------------------------------------------------------

---@class era.m.acp.IDiffHunk
---@field public old_start              integer
---@field public old_count              integer
---@field public new_start              integer
---@field public new_count              integer
---@field public deleted                string[]
---@field public added                  string[]
---@field public common                 string[]

return {}
