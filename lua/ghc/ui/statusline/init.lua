---@class ghc.ui.statusline
local M = {}

---@type fml.types.ui.INvimbar
local statusline = fml.ui.Nvimbar.new({
  component_sep = fml.nvimbar.add_highlight("  ", "f_sl_bg"),
})

statusline
---
    :add("left", require("ghc.ui.statusline.component.username"))
    :add("left", require("ghc.ui.statusline.component.mode"))
    :add("left", require("ghc.ui.statusline.component.git"))
    :add("left", require("ghc.ui.statusline.component.filepath"))
    :add("left", require("ghc.ui.statusline.component.readonly"))
    :add("center", require("ghc.ui.statusline.component.search"))
    :add("center", require("ghc.ui.statusline.component.find_file"))
    :add("center", require("ghc.ui.statusline.component.find_recent"))
    :add("right", require("ghc.ui.statusline.component.cwd"))
    :add("right", require("ghc.ui.statusline.component.filetype"))
    :add("right", require("ghc.ui.statusline.component.lsp"))
    :add("right", require("ghc.ui.statusline.component.copilot"))
    :add("right", require("ghc.ui.statusline.component.fileformat"))
    :add("right", require("ghc.ui.statusline.component.pos"))
    :add("right", require("ghc.ui.statusline.component.noice"))
    :add("right", require("ghc.ui.statusline.component.diagnostics"))

---@return string
function M.render()
  return statusline:render()
end

return M
