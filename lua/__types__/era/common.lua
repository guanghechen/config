---@meta

---@alias era.t.T
---| any

---@generic T
---@alias era.t.IEquals
---| fun(x: T, y: T): boolean

---@generic T
---@alias era.t.IFilter
---| fun(element: T, index: integer): boolean

---@generic T
---@alias era.t.INormalize
---| fun(x: T): T

---@generic T
---@alias era.t.IValidate
---| fun(element: T): boolean

---@class era.t.ILspSymbol
---@field public kind                   string
---@field public name                   string
---@field public row                    integer
---@field public col                    integer

---@class era.t.ILocation
---@field public filepath               string
---@field public start_lnum             ?integer
---@field public start_col              ?integer
---@field public end_lnum               ?integer
---@field public end_col                ?integer

---@class era.t.IMatchLocation
---@field public offset                 integer
---@field public lnum                   integer
---@field public col                    integer
---@field public line                   string

---@class era.t.IMatchPoint
---@field public l                      integer
---@field public r                      integer

---@class era.t.IScoredMatch
---@field public order                  integer
---@field public uuid                   string
---@field public score                  integer
---@field public matches                era.t.IMatchPoint[]

---@class era.t.IWinDimension
---@field public width                  integer
---@field public height                 integer
---@field public row                    integer
---@field public col                    integer

---@class era.command.IDefinition
---@field public uuid                   string
---@field public desc                   string
---@field public nargs                  0|1|"?"|nil
---@field public candidates             string[]|nil

---@class era.command.IDefinitionWithCandidates
---@field public uuid                   string
---@field public desc                   string
---@field public nargs                  1|"?"
---@field public candidates             string[]
