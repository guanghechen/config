---@meta

---@alias ark.t.T
---| any

---@generic T
---@alias ark.t.IEquals
---| fun(x: T, y: T): boolean

---@generic T
---@alias ark.t.IFilter
---| fun(element: T, index: integer): boolean

---@generic T
---@alias ark.t.INormalize
---| fun(x: T): T

---@class ark.t.IHighlight
---@field public lnum                   integer
---@field public coll                   integer
---@field public colr                   integer
---@field public hlname                 string

---@class ark.t.IHighlightInline
---@field public coll                   integer
---@field public colr                   integer
---@field public hlname                 string

---@class ark.t.IKeymapOverridable
---@field public bufnr                  ?integer
---@field public nowait                 ?boolean
---@field public noremap                ?boolean
---@field public silent                 ?boolean
---@field public expr                   ?boolean
---@field public replace_keycodes       ?boolean

---@class ark.t.IKeymap : ark.t.IKeymapOverridable
---@field public disabled               boolean|nil
---@field public modes                  ark.e.VimMode[]
---@field public key                    string
---@field public aliases                string[]|nil
---@field public desc                   string|nil
---@field public callback               string|(fun(): nil)|(fun(): string)
