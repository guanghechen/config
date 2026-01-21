---@meta

---@alias stl.t.T
---| any

---@generic T
---@alias stl.t.IEquals
---| fun(x: T, y: T): boolean

---@generic T
---@alias stl.t.IFilter
---| fun(element: T, index: integer): boolean

---@generic T
---@alias stl.t.INormalize
---| fun(x: T): T

---@class stl.t.IHighlight
---@field public lnum                   integer
---@field public coll                   integer
---@field public colr                   integer
---@field public hlname                 string

---@class stl.t.IHighlightInline
---@field public coll                   integer
---@field public colr                   integer
---@field public hlname                 string

---@class stl.t.IKeymapOverridable
---@field public bufnr                  ?integer
---@field public nowait                 ?boolean
---@field public noremap                ?boolean
---@field public silent                 ?boolean
---@field public expr                   ?boolean
---@field public replace_keycodes       ?boolean

---@class stl.t.IKeymap : stl.t.IKeymapOverridable
---@field public disabled               boolean|nil
---@field public modes                  stl.t.VimModeEnum[]
---@field public key                    string
---@field public aliases                string[]|nil
---@field public desc                   string|nil
---@field public callback               string|(fun(): nil)|(fun(): string)
