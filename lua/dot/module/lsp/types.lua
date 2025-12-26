---@class dot.t.ISymbolPos
---@field public line                   integer
---@field public character              integer

---@class dot.module.lsp.diagnostic.IBufferDiagnostics
---@field public bufnr                  integer
---@field public error                  integer
---@field public warn                   integer
---@field public info                   integer
---@field public hint                   integer
---@field public total                  integer

---@class dot.module.lsp.diagnostic.IAllDiagnostics
---@field public error                  integer
---@field public warn                   integer
---@field public info                   integer
---@field public hint                   integer
---@field public total                  integer
---@field public buffers                table<integer, dot.module.lsp.diagnostic.IBufferDiagnostics>
