---@alias dot.ux.widget.ai.AgentName
---| "claude"
---| "codex"
---| "copilot"
---| "gemini"

---@alias dot.ux.widget.ai.SourceType
---| "tmux"
---| "terminal"

---@alias dot.ux.widget.ai.ItemCategory
---| "attached"
---| "same_window"
---| "agent_session"
---| "new_agent"
---| "same_session"
---| "other_tmux"

---@class dot.ux.widget.ai.IProc
---@field public pid                    integer
---@field public ppid                   integer
---@field public cmd                    string

---@alias dot.ux.widget.ai.IChunk { [1]: string, [2]?: string } A chunk of text with optional highlight group.

---@alias dot.ux.widget.ai.ITextLine dot.ux.widget.ai.IChunk[] A line composed of chunks.

---@alias dot.ux.widget.ai.IText dot.ux.widget.ai.ITextLine[] Multiple lines of chunked text.

---@class dot.ux.widget.ai.IPromptRenderResult
---@field public text                   string The full prompt text (for sending).
---@field public lines                  dot.ux.widget.ai.IText Rich text lines for preview (with highlights).

---@class dot.ux.widget.ai.IPrompt
---@field public name                   string
---@field public submit                 boolean If true, submit the content directly rather than only send.
---@field public render                 fun(ctx: dot.ux.widget.ai.prompt.ICtx): dot.ux.widget.ai.IPromptRenderResult|nil Returns nil if prompt is not available.

---@class dot.ux.widget.ai.ISelectItem
---@field public type                   "running"|"new"
---@field public agent                  dot.ux.widget.ai.AgentName
---@field public source                 ?dot.ux.widget.ai.ISource
---@field public installed              boolean

---@class dot.ux.widget.ai.ISource
---@field public id                     string
---@field public type                   dot.ux.widget.ai.SourceType
---@field public agent                  dot.ux.widget.ai.AgentName
---@field public cwd                    string
---@field public external               boolean
---@field public tmux_pane              ?dot.ux.widget.ai.ITmuxPaneInfo

---@class dot.ux.widget.ai.IAttachedSource : dot.ux.widget.ai.ISource
---@field public attached_at            integer

---@class dot.ux.widget.ai.IToolConfig
---@field public cmd                    string
---@field public args                   fun(cwd: string): string[]
---@field public env                    fun(): table<string, string|false>
---@field public proc_pattern           string
---@field public url                    string
---@field public vim_mode               boolean If true, send <Esc>i before text to ensure insert mode.

---@class dot.ux.widget.ai.ITmuxPaneInfo
---@field public session_id             string
---@field public session_name           string
---@field public window_id              string
---@field public window_name            string
---@field public pane_id                string
---@field public pane_pid               integer
---@field public pane_cwd               string

return {}
