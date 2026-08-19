---@alias era.m.ai.AgentName
---| "claude"
---| "codex"
---| "gemini"
---| "opencode"

---@alias era.m.ai.SourceType
---| "tmux"
---| "terminal"

---@alias era.m.ai.ItemCategory
---| "attached"
---| "same_window"
---| "agent_session"
---| "new_agent"
---| "same_session"
---| "other_tmux"

---@class era.m.ai.IProc
---@field public pid                    integer
---@field public ppid                   integer
---@field public cmd                    string

---@alias era.m.ai.IChunk { [1]: string, [2]?: string } A chunk of text with optional highlight group.

---@alias era.m.ai.ITextLine era.m.ai.IChunk[] A line composed of chunks.

---@alias era.m.ai.IText era.m.ai.ITextLine[] Multiple lines of chunked text.

---@class era.m.ai.IPromptRenderResult
---@field public text                   string The full prompt text (for sending).
---@field public lines                  era.m.ai.IText Rich text lines for preview (with highlights).

---@class era.m.ai.IPrompt
---@field public name                   string
---@field public submit                 boolean If true, submit the content directly rather than only send.
---@field public args                   ?table<string, stl.prompt.ArgValue> Variable name to default value mapping, prompts user at runtime.
---@field public render                 fun(ctx: era.m.ai.prompt.ICtx): era.m.ai.IPromptRenderResult|nil Returns nil if prompt is not available.

---@class era.m.ai.ISelectItem
---@field public type                   "running"|"new"
---@field public agent                  era.m.ai.AgentName
---@field public source                 ?era.m.ai.ISource
---@field public installed              boolean

---@class era.m.ai.ISource
---@field public id                     string
---@field public type                   era.m.ai.SourceType
---@field public agent                  era.m.ai.AgentName
---@field public cwd                    string
---@field public external               boolean
---@field public tmux_pane              ?era.m.ai.ITmuxPaneInfo

---@class era.m.ai.IAttachedSource : era.m.ai.ISource
---@field public attached_at            integer

---@class era.m.ai.IToolConfig
---@field public cmd                    string
---@field public args                   fun(cwd: string): string[]
---@field public env                    fun(): table<string, string|false>
---@field public proc_pattern           string
---@field public url                    string
---@field public vim_mode               boolean If true, the input is a modal (vim) editor: enter INSERT before pasting, return to NORMAL before submitting.
---@field public insert_pattern         ?string Lua pattern; presence in the pane capture means the modal editor is in INSERT mode. Enables insert-state verification.
---@field public busy_pattern           ?string Lua pattern (matched per trimmed bottom line); presence means the agent is processing. Enables idle-wait before sending and submit confirmation.

---@class era.m.ai.ITmuxPaneInfo
---@field public session_id             string
---@field public session_name           string
---@field public window_id              string
---@field public window_name            string
---@field public pane_id                string
---@field public pane_pid               integer
---@field public pane_cwd               string

return {}
