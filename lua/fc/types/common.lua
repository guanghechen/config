---@alias fc.types.T
---| any

---@generic T
---@alias fc.types.IEquals
---| fun(x: T, y: T): boolean

---@generic T
---@alias fc.types.IFilter
---| fun(element: T, index: integer): boolean

---@generic T
---@alias fc.types.INormalize
---| fun(x: T): T

---@generic T
---@alias fc.types.IValidate
---| fun(element: T): boolean

---@class fc.types.IMatchLocation
---@field public offset                 integer
---@field public lnum                   integer
---@field public col                    integer
---@field public line                   string

---@class fc.types.IMatchPoint
---@field public l                      integer
---@field public r                      integer
