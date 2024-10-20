---@type t.fml.ux.nvimbar.IRawComponent
local M = {
  name = "noice",
  condition = function()
    return not not package.loaded["noice"]
  end,
  render = function()
    local status = require("noice").api.status
    local hl_text = "" ---@type string
    local width = 0 ---@type integer

    --    local text_noice_command = status.command.get() ---@type string | nil
    --    if text_noice_command ~= nil and #text_noice_command > 0 then
    --      hl_text = eve.nvimbar.txt(text_noice_command, "f_sl_noice_command")
    --      width = vim.api.nvim_strwidth(text_noice_command)
    --    end

    local text_noice_mode = status.mode.get() or ""
    if text_noice_mode ~= nil and #text_noice_mode > 0 then
      if width > 0 then
        hl_text = hl_text .. eve.nvimbar.txt(" ", "f_sl_bg")
        width = width + 1
      end

      hl_text = hl_text .. eve.nvimbar.txt(text_noice_mode, "f_sl_noice_mode")
      width = width + vim.api.nvim_strwidth(text_noice_mode)
    end
    return hl_text, width
  end,
}

return M
