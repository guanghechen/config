---@alias dot.module.ai.AgentName
---| "claude"
---| "codex"
---| "copilot"
---| "gemini"

---@alias dot.module.ai.SourceType
---| "tmux"
---| "terminal"

---@alias dot.module.ai.ItemCategory
---| "attached"
---| "same_window"
---| "agent_session"
---| "new_agent"
---| "same_session"
---| "other_tmux"

---@class dot.module.ai.IProc
---@field public pid                    integer
---@field public ppid                   integer
---@field public cmd                    string

---@alias dot.module.ai.IChunk { [1]: string, [2]?: string } A chunk of text with optional highlight group.

---@alias dot.module.ai.ITextLine dot.module.ai.IChunk[] A line composed of chunks.

---@alias dot.module.ai.IText dot.module.ai.ITextLine[] Multiple lines of chunked text.

---@class dot.module.ai.IPromptRenderResult
---@field public text                   string The full prompt text (for sending).
---@field public lines                  dot.module.ai.IText Rich text lines for preview (with highlights).

---@class dot.module.ai.IPrompt
---@field public name                   string
---@field public submit                 boolean If true, submit the content directly rather than only send.
---@field public render                 fun(ctx: dot.module.ai.prompt.ICtx): dot.module.ai.IPromptRenderResult|nil Returns nil if prompt is not available.

---@class dot.module.ai.ISelectItem
---@field public type                   "running"|"new"
---@field public agent                  dot.module.ai.AgentName
---@field public source                 ?dot.module.ai.ISource
---@field public installed              boolean

---@class dot.module.ai.ISource
---@field public id                     string
---@field public type                   dot.module.ai.SourceType
---@field public agent                  dot.module.ai.AgentName
---@field public cwd                    string
---@field public external               boolean
---@field public tmux_pane              ?dot.module.ai.ITmuxPaneInfo

---@class dot.module.ai.IAttachedSource : dot.module.ai.ISource
---@field public attached_at            integer

---@class dot.module.ai.IToolConfig
---@field public cmd                    string
---@field public args                   fun(cwd: string): string[]
---@field public env                    fun(): table<string, string|false>
---@field public proc_pattern           string
---@field public url                    string
---@field public vim_mode               boolean If true, send <Esc>i before text to ensure insert mode.

---@class dot.module.ai.ITmuxPaneInfo
---@field public session_id             string
---@field public session_name           string
---@field public window_id              string
---@field public window_name            string
---@field public pane_id                string
---@field public pane_pid               integer
---@field public pane_cwd               string

return {}
