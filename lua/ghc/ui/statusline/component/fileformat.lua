local fileformat_text_map = {
  dos = "CRLF",
  mac = "CR",
  unix = "LF",
}

---@type fml.types.ui.nvimbar.IRawComponent
local M = {
  name = "fileformat",
  condition = function()
    return vim.o.columns > 100
  end,
  render = function()
    ---@diagnostic disable-next-line: undefined-field
    local text_encoding = vim.opt.fileencoding:get()
    local text_fileformat = fileformat_text_map[vim.bo.fileformat] or "UNKNOWN"
    local icon_tab = eve.icons.ui.Tab .. " "
    local text_tab = vim.api.nvim_get_option_value("shiftwidth", { scope = "local" })
    local text = text_encoding .. " " .. text_fileformat .. " " .. icon_tab .. text_tab
    local hl_text = eve.nvimbar.txt(text, "f_sl_text")
    local width = vim.fn.strwidth(text) ---@type integer
    return hl_text, width
  end,
}

return M
