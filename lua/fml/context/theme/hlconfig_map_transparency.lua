---@type table<string, fml.types.ui.theme.IHighlightConfig>
local hlconfig_map = require("fml.context.theme.hlconfig_map")

---@type table<string, fml.types.ui.theme.IHighlightConfig>
local hlconfig_map_override = {
  ---flash
  FlashBackdrop = { fg = "grey_fg", bg = "none", italic = true },
  FlashCursor = { fg = "red", bg = "grey" },
  FlashLabel = { fg = "white", bg = "grey" },
  FlashMatch = { fg = "cyan", bg = "grey" },
}

return vim.tbl_extend("force", hlconfig_map, hlconfig_map_override)
