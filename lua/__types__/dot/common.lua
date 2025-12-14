---@meta

---@alias dot.t.T
---| any

---@generic T
---@alias dot.t.IEquals
---| fun(x: T, y: T): boolean

---@generic T
---@alias dot.t.IFilter
---| fun(element: T, index: integer): boolean

---@generic T
---@alias dot.t.INormalize
---| fun(x: T): T

---@generic T
---@alias dot.t.IValidate
---| fun(element: T): boolean

---@class dot.t.ILspSymbol
---@field public kind                   string
---@field public name                   string
---@field public row                    integer
---@field public col                    integer

---@class dot.t.ILocation
---@field public filepath               string
---@field public start_lnum             ?integer
---@field public start_col              ?integer
---@field public end_lnum               ?integer
---@field public end_col                ?integer

---@class dot.t.IMatchLocation
---@field public offset                 integer
---@field public lnum                   integer
---@field public col                    integer
---@field public line                   string

---@class dot.t.IMatchPoint
---@field public l                      integer
---@field public r                      integer

---@class dot.t.IScoredMatch
---@field public order                  integer
---@field public uuid                   string
---@field public score                  integer
---@field public matches                dot.t.IMatchPoint[]

---@class dot.t.IWinDimension
---@field public width                  integer
---@field public height                 integer
---@field public row                    integer
---@field public col                    integer

---@class dot.command.IDefinition
---@field public uuid                   string
---@field public desc                   string
---@field public nargs                  0|1|"?"|nil
---@field public candidates             string[]|nil
---@field public execute                fun(self: dot.command.IDefinition, args?: string, silent?: boolean): nil

---@class dot.command.IDefinitionWithCandidates : dot.command.IDefinition
---@field public nargs                  1|"?"
---@field public candidates             string[]

---@class dot.t.IRawWidget
---@field public name                   string
---@field public close                  fun(self: dot.t.IWidget): nil
---@field public focus                  fun(self: dot.t.IWidget): nil
---@field public hide                   fun(self: dot.t.IWidget): nil
---@field public isdisposed             fun(self: dot.t.IWidget): boolean
---@field public isfocused              fun(self: dot.t.IWidget): boolean
---@field public isvisible              fun(self: dot.t.IWidget): boolean
---@field public resize                 fun(self: dot.t.IWidget): nil

---@class dot.t.IWidget
---@field public name                   string
---@field public close                  fun(): nil
---@field public focus                  fun(): nil
---@field public hide                   fun(): nil
---@field public isdisposed             fun(): boolean
---@field public isfocused              fun(): boolean
---@field public isvisible              fun(): boolean
---@field public resize                 fun(): nil
