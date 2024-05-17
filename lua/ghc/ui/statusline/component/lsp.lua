local context = {
  config = require("ghc.core.context.config"),
}

---@type boolean
local transparency = context.config.transparency:get_snapshot()

--- @class ghc.ui.statusline.component.lsp
local M = {
  name = "ghc_statusline_lsp",
  color = {
    text = {
      fg = "white",
      bg = transparency and "none" or "statusline_bg",
    },
  },
}

function M.condition()
  return not not rawget(vim, "lsp")
end

function M.renderer()
  local color_text = "%#" .. M.name .. "_text#"
  local text = ""

  local bufnr = vim.api.nvim_win_get_buf(vim.g.statusline_winid or 0)
  for _, client in ipairs(vim.lsp.get_active_clients()) do
    if client.attached_buffers[bufnr] and client.name ~= "null-ls" then
      text = "   " .. client.name .. " "
      break
    end
  end

  return color_text .. text
end

return M
