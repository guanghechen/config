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
