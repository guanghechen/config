---@alias eve.types.T
---| any

---@generic T
---@alias eve.types.IEquals
---| fun(x: T, y: T): boolean

---@generic T
---@alias eve.types.IFilter
---| fun(element: T, index: integer): boolean

---@generic T
---@alias eve.types.INormalize
---| fun(x: T): T

---@generic T
---@alias eve.types.IValidate
---| fun(element: T): boolean

---@class eve.types.IMatchLocation
---@field public offset                 integer
---@field public lnum                   integer
---@field public col                    integer
---@field public line                   string

---@class eve.types.IMatchPoint
---@field public l                      integer
---@field public r                      integer
