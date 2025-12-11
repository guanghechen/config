---@meta

---@class era.command.IDefinition
---@field public uuid                   string
---@field public desc                   string
---@field public nargs                  0|1|"?"
---@field public candidates             ?string[]

---@class era.command.IDefinitionWithCandidates
---@field public uuid                   string
---@field public desc                   string
---@field public nargs                  1|"?"
---@field public candidates             string[]
