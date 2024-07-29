---@alias fml.types.T any

---@generic T
---@alias fml.types.IEquals fun(x: T, y: T): boolean

---@generic T
---@alias fml.types.INormalize fun(x: T): T

---@class fml.types.IKeymapOverridable
---@field public bufnr                  ?integer
---@field public nowait                 ?boolean
---@field public noremap                ?boolean
---@field public silent                 ?boolean

---@class fml.types.IKeymap : fml.types.IKeymapOverridable
---@field public modes                  string[]
---@field public key                    string
---@field public callback               fun(): nil
---@field public desc                   string
