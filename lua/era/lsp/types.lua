---@class era.lsp.ISymbolPos
---@field public line                   integer
---@field public character              integer

---@class era.lsp.diagnostic.IBufferDiagnostics
---@field public bufnr                  integer
---@field public error                  integer
---@field public warn                   integer
---@field public info                   integer
---@field public hint                   integer
---@field public total                  integer

---@class era.lsp.diagnostic.IAllDiagnostics
---@field public error                  integer
---@field public warn                   integer
---@field public info                   integer
---@field public hint                   integer
---@field public total                  integer
---@field public buffers                table<integer, era.lsp.diagnostic.IBufferDiagnostics>
