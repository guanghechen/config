---@alias era.ai.AgentName
---| "claude"
---| "codex"
---| "copilot"
---| "gemini"

---@alias era.ai.SourceType
---| "tmux"
---| "terminal"

---@alias era.ai.ItemCategory
---| "attached"
---| "same_window"
---| "agent_session"
---| "new_agent"
---| "same_session"
---| "other_tmux"

---@class era.ai.IProc
---@field public pid                    integer
---@field public ppid                   integer
---@field public cmd                    string

---@alias era.ai.IChunk { [1]: string, [2]?: string } A chunk of text with optional highlight group.

---@alias era.ai.ITextLine era.ai.IChunk[] A line composed of chunks.

---@alias era.ai.IText era.ai.ITextLine[] Multiple lines of chunked text.

---@class era.ai.IPromptRenderResult
---@field public text                   string The full prompt text (for sending).
---@field public lines                  era.ai.IText Rich text lines for preview (with highlights).

---@class era.ai.IPrompt
---@field public name                   string
---@field public submit                 boolean If true, submit the content directly rather than only send.
---@field public render                 fun(ctx: era.ai.prompt.ICtx): era.ai.IPromptRenderResult|nil Returns nil if prompt is not available.

---@class era.ai.ISelectItem
---@field public type                   "running"|"new"
---@field public agent                  era.ai.AgentName
---@field public source                 ?era.ai.ISource
---@field public installed              boolean

---@class era.ai.ISource
---@field public id                     string
---@field public type                   era.ai.SourceType
---@field public agent                  era.ai.AgentName
---@field public cwd                    string
---@field public external               boolean
---@field public tmux_pane              ?era.ai.ITmuxPaneInfo

---@class era.ai.IAttachedSource : era.ai.ISource
---@field public attached_at            integer

---@class era.ai.IToolConfig
---@field public cmd                    string
---@field public args                   fun(cwd: string): string[]
---@field public env                    fun(): table<string, string|false>
---@field public proc_pattern           string
---@field public url                    string
---@field public vim_mode               boolean If true, send <Esc>i before text to ensure insert mode.

---@class era.ai.ITmuxPaneInfo
---@field public session_id             string
---@field public session_name           string
---@field public window_id              string
---@field public window_name            string
---@field public pane_id                string
---@field public pane_pid               integer
---@field public pane_cwd               string

return {}
