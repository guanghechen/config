---@class ghc.types.command.replace.main.ILineMeta
---@field public filepath             ?string current line indicate the filepath
---@field public lnum                 ?integer current line indicate the filepath
---@field public key                  ?ghc.enums.command.replace.StateKey

---@class ghc.command.replace.main
---@field private CFG_NAME_LEN          integer
---@field private cursor_row            integer
---@field private cursor_col            integer
---@field private printer               fml.ui.Printer
local M = {}

M.CFG_NAME_LEN = 7
M.cursor_row = 6
M.cursor_col = 21
M.printer = fml.ui.Printer.new({ bufnr = 0, nsnr = 0 })

---@param line                          string
---@param highlights                    ?fml.ui.printer.ILineHighlight[]
---@param meta                          ?ghc.types.command.replace.main.ILineMeta
---@return nil
function M.internal_print(line, highlights, meta)
  M.printer:print(line, highlights, meta)
end

return M
