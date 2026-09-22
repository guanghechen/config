---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.keystroke.textobject.types" ---@type string

---Buffer ranges use zero-based byte columns and an exclusive end.
---Linewise ranges may end at {line_count, 0}, including the last line's newline.
---@alias era.keystroke.textobject.Range { [1]: integer, [2]: integer, [3]: integer, [4]: integer, vis_mode?: string, container?: string, capture?: string }
---@alias era.keystroke.textobject.Kind "a"|"i"

---Spans use one-based byte offsets and an exclusive end, including empty spans.
---@class era.keystroke.textobject.ISpan
---@field public from                   integer
---@field public to                     integer

---@class era.keystroke.textobject.ICandidate
---@field public span                   era.keystroke.textobject.ISpan Search envelope before extracting inner/outer text
---@field public outer                  era.keystroke.textobject.ISpan
---@field public inner                  era.keystroke.textobject.ISpan
---@field public vis_mode               ?string

---@class era.keystroke.textobject.ISource
---@field public lines                  string[]
---@field public text                   string
---@field public starts                 integer[]
---@field public first_row              integer

---@class era.keystroke.textobject.IOptions
---@field public count                  ?integer
---@field public reference              ?era.keystroke.textobject.Range
---@field public prompt                 ?string[]
---@field public operator_pending       ?boolean
---@field public vis_mode               ?string

return {}
