---@type fml.types.core.statusline.IRawComponent
local M = {
  name = "lsp",
  condition = function()
    return not not rawget(vim, "lsp")
  end,
  pieces = {
    {
      hlname = function()
        return "f_sl_text"
      end,
      text = function()
        local bufnr = vim.api.nvim_win_get_buf(vim.g.statusline_winid or 0)
        for _, client in ipairs(vim.lsp.get_clients()) do
          if client.attached_buffers[bufnr] and client.name ~= "null-ls" then
            return "  " .. client.name
          end
        end
        return ""
      end,
    },
  },
}

return M
