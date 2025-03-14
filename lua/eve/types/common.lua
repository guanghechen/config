---@alias eve.t.T
---| any

---@generic T
---@alias eve.t.IEquals
---| fun(x: T, y: T): boolean

---@generic T
---@alias eve.t.IFilter
---| fun(element: T, index: integer): boolean

---@generic T
---@alias eve.t.INormalize
---| fun(x: T): T

---@generic T
---@alias eve.t.IValidate
---| fun(element: T): boolean

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
---@field public disabled               boolean|nil
---@field public modes                  eve.e.VimMode[]
---@field public key                    string
---@field public aliases                string[]|nil
---@field public callback               fun(): nil
---@field public desc                   string|nil

---@class eve.t.IMatchLocation
---@field public offset                 integer
---@field public lnum                   integer
---@field public col                    integer
---@field public line                   string

---@class eve.t.IMatchPoint
---@field public l                      integer
---@field public r                      integer

---@class eve.t.IQuickFixItem
---@field public filename               string
---@field public lnum                   ?integer
---@field public col                    ?integer
---@field public text                   ?string
