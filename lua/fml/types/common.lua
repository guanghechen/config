
---@alias fml.enums.FileType
---| "file"
---| "directory"
---| "other"

---@alias fml.enums.VimMode
---| "i"
---| "n"
---| "v"
---| "t"

---@alias fml.types.T any

---@generic T
---@alias fml.types.IEquals
---| fun(x: T, y: T): boolean

---@generic T
---@alias fml.types.Validate
---| fun(element: T): boolean

---@generic T
---@alias fml.types.IFilter
---| fun(element: T, index: integer): boolean

---@generic T
---@alias fml.types.INormalize fun(x: T): T

---@class fml.types.IKeymapOverridable
---@field public bufnr                  ?integer
---@field public nowait                 ?boolean
---@field public noremap                ?boolean
---@field public silent                 ?boolean

---@class fml.types.IKeymap : fml.types.IKeymapOverridable
---@field public modes                  fml.enums.VimMode[]
---@field public key                    string
---@field public callback               fun(): nil
---@field public desc                   string|nil

---@class fml.types.IQuickFixItem
---@field public filename               string
---@field public lnum                   ?integer
---@field public col                    ?integer
---@field public text                   ?string
