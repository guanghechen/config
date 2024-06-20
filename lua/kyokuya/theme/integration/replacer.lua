---@param highlighter kyokuya.theme.Highlighter
---@return nil
local function integrate_theme_replacer(highlighter)
  highlighter
    :register("kyokuya_invisible", { fg = "none", bg = "none" })
    :register("kyokuya_replace_cfg_name", { fg = "blue", bg = "none", bold = true })
    :register("kyokuya_replace_cfg_value", { fg = "yellow", bg = "none" })
    :register("kyokuya_replace_cfg_search_pattern", { fg = "diff_delete_hl", bg = "none" })
    :register("kyokuya_replace_cfg_replace_pattern", { fg = "diff_add_hl", bg = "none" })
end

return integrate_theme_replacer
