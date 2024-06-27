local fileformat_text_map = {
  dos = "CRLF",
  mac = "CR",
  unix = "LF",
}

---@type fml.types.core.statusline.IRawComponent
local M = {
  name = "fileformat",
  condition = function()
    return vim.o.columns > 100
  end,
  pieces = {
    {
      hlname = function()
        return "f_sl_text"
      end,
      text = function()
        ---@diagnostic disable-next-line: undefined-field
        local text_encoding = vim.opt.fileencoding:get()
        local text_fileformat = fileformat_text_map[vim.bo.fileformat] or "UNKNOWN"
        local icon_tab = fml.ui.icons.ui.Tab .. " "
        local text_tab = vim.api.nvim_get_option_value("shiftwidth", { scope = "local" })
        return text_encoding .. " " .. text_fileformat .. " " .. icon_tab .. text_tab
      end,
    },
  },
}

return M
