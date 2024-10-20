---@class t.eve.IHighlight
---@field public lnum                   integer
---@field public coll                   integer
---@field public colr                   integer
---@field public hlname                 string

---@class t.eve.IHighlightInline
---@field public coll                   integer
---@field public colr                   integer
---@field public hlname                 string

---@class t.eve.IKeymapOverridable
---@field public bufnr                  ?integer
---@field public nowait                 ?boolean
---@field public noremap                ?boolean
---@field public silent                 ?boolean

---@class t.eve.IKeymap : t.eve.IKeymapOverridable
---@field public modes                  t.eve.e.VimMode[]
---@field public key                    string
---@field public callback               fun(): nil
---@field public desc                   string|nil

---@class t.eve.IQuickFixItem
---@field public filename               string
---@field public lnum                   ?integer
---@field public col                    ?integer
---@field public text                   ?string
