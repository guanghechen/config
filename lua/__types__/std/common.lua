---@meta

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

---@class std.t.ILspSymbol
---@field public kind                   string
---@field public name                   string
---@field public row                    integer
---@field public col                    integer

---@class std.t.ILocation
---@field public filepath               string
---@field public start_lnum             ?integer
---@field public start_col              ?integer
---@field public end_lnum               ?integer
---@field public end_col                ?integer

---@class std.t.IMatchLocation
---@field public offset                 integer
---@field public lnum                   integer
---@field public col                    integer
---@field public line                   string

---@class std.t.IMatchPoint
---@field public l                      integer
---@field public r                      integer

---@class std.t.IScoredMatch
---@field public order                  integer
---@field public uuid                   string
---@field public score                  integer
---@field public matches                std.t.IMatchPoint[]

---@class std.t.IWinDimension
---@field public width                  integer
---@field public height                 integer
---@field public row                    integer
---@field public col                    integer
