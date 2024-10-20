---@alias t.eve.T
---| any

---@generic T
---@alias t.eve.IEquals
---| fun(x: T, y: T): boolean

---@generic T
---@alias t.eve.IFilter
---| fun(element: T, index: integer): boolean

---@generic T
---@alias t.eve.INormalize
---| fun(x: T): T

---@generic T
---@alias t.eve.IValidate
---| fun(element: T): boolean

---@class t.eve.IMatchLocation
---@field public offset                 integer
---@field public lnum                   integer
---@field public col                    integer
---@field public line                   string

---@class t.eve.IMatchPoint
---@field public l                      integer
---@field public r                      integer
