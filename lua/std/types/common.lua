---@alias std.t.T
---| any

---@generic T
---@alias std.t.IEquals
---| fun(x: T, y: T): boolean

---@generic T
---@alias std.t.IFilter
---| fun(element: T, index: integer): boolean

---@generic T
---@alias std.t.INormalize
---| fun(x: T): T

---@generic T
---@alias std.t.IValidate
---| fun(element: T): boolean

---@class std.t.IHighlight
---@field public lnum                   integer
---@field public coll                   integer
---@field public colr                   integer
---@field public hlname                 string

---@class std.t.IHighlightInline
---@field public coll                   integer
---@field public colr                   integer
---@field public hlname                 string

---@class std.t.IKeymapOverridable
---@field public bufnr                  ?integer
---@field public nowait                 ?boolean
---@field public noremap                ?boolean
---@field public silent                 ?boolean

---@class std.t.IKeymap : std.t.IKeymapOverridable
---@field public disabled               boolean|nil
---@field public modes                  std.e.VimMode[]
---@field public key                    string
---@field public aliases                string[]|nil
---@field public desc                   string|nil
---@field public callback               fun(): nil

---@class std.t.ILspSymbol
---@field public kind                   string
---@field public name                   string
---@field public row                    integer
---@field public col                    integer

---@class std.t.IMatchLocation
---@field public offset                 integer
---@field public lnum                   integer
---@field public col                    integer
---@field public line                   string

---@class std.t.IMatchPoint
---@field public l                      integer
---@field public r                      integer

---@class std.t.IQuickFixItem
---@field public filename               string
---@field public lnum                   ?integer
---@field public col                    ?integer
---@field public text                   ?string

---@class std.t.IScoredMatch
---@field public order                  integer
---@field public uuid                   string
---@field public score                  integer
---@field public matches                std.t.IMatchPoint[]
