---@alias eve.ux.widget.ai.AgentName
---| "claude"
---| "codex"
---| "copilot"
---| "gemini"

---@alias eve.ux.widget.ai.SourceType
---| "tmux"
---| "terminal"

---@class eve.ux.widget.ai.IProc
---@field public pid                    integer
---@field public ppid                   integer
---@field public cmd                    string

---@alias eve.ux.widget.ai.IChunk { [1]: string, [2]?: string } A chunk of text with optional highlight group.

---@alias eve.ux.widget.ai.ITextLine eve.ux.widget.ai.IChunk[] A line composed of chunks.

---@alias eve.ux.widget.ai.IText eve.ux.widget.ai.ITextLine[] Multiple lines of chunked text.

---@class eve.ux.widget.ai.IPromptRenderResult
---@field public text                   string The full prompt text (for sending).
---@field public lines                  eve.ux.widget.ai.IText Rich text lines for preview (with highlights).

---@class eve.ux.widget.ai.IPrompt
---@field public name                   string
---@field public submit                 boolean If true, submit the content directly rather than only send.
---@field public render                 fun(ctx: eve.ux.widget.ai.prompt.ICtx): eve.ux.widget.ai.IPromptRenderResult|nil Returns nil if prompt is not available.

---@class eve.ux.widget.ai.ISelectItem
---@field public type                   "running"|"new"
---@field public agent                  eve.ux.widget.ai.AgentName
---@field public source                 ?eve.ux.widget.ai.ISource
---@field public installed              boolean

---@class eve.ux.widget.ai.ISource
---@field public id                     string
---@field public type                   eve.ux.widget.ai.SourceType
---@field public agent                  eve.ux.widget.ai.AgentName
---@field public cwd                    string
---@field public external               boolean
---@field public tmux_pane              ?eve.ux.widget.ai.ITmuxPaneInfo

---@class eve.ux.widget.ai.IAttachedSource : eve.ux.widget.ai.ISource
---@field public attached_at            integer

---@class eve.ux.widget.ai.IToolConfig
---@field public cmd                    string
---@field public args                   fun(cwd: string): string[]
---@field public env                    fun(): table<string, string|false>
---@field public proc_pattern           string
---@field public url                    string
---@field public vim_mode               boolean If true, send <Esc>i before text to ensure insert mode.

---@class eve.ux.widget.ai.ITmuxPaneInfo
---@field public session_id             string
---@field public session_name           string
---@field public window_id              string
---@field public window_name            string
---@field public pane_id                string
---@field public pane_pid               integer
---@field public pane_cwd               string

return {}
