---@meta

---@class std.command.IDefinition
---@field public uuid                   string
---@field public desc                   string
---@field public nargs                  0|1|"?"
---@field public candidates             ?string[]

---@class std.command.IDefinitionWithCandidates
---@field public uuid                   string
---@field public desc                   string
---@field public nargs                  1|"?"
---@field public candidates             string[]
