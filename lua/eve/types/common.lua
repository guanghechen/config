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

---@class eve.t.IMatchLocation
---@field public offset                 integer
---@field public lnum                   integer
---@field public col                    integer
---@field public line                   string

---@class eve.t.IMatchPoint
---@field public l                      integer
---@field public r                      integer
