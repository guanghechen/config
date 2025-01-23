---@class eve.t.IHighlight
---@field public lnum                   integer
---@field public coll                   integer
---@field public colr                   integer
---@field public hlname                 string

---@class eve.t.IHighlightInline
---@field public coll                   integer
---@field public colr                   integer
---@field public hlname                 string

---@class eve.t.IKeymapOverridable
---@field public bufnr                  ?integer
---@field public nowait                 ?boolean
---@field public noremap                ?boolean
---@field public silent                 ?boolean

---@class eve.t.IKeymap : eve.t.IKeymapOverridable
---@field public modes                  eve.e.VimMode[]
---@field public key                    string
---@field public aliases                string[]|nil
---@field public callback               fun(): nil
---@field public desc                   string|nil
---@field public active                 boolean|nil

---@class eve.t.IQuickFixItem
---@field public filename               string
---@field public lnum                   ?integer
---@field public col                    ?integer
---@field public text                   ?string
