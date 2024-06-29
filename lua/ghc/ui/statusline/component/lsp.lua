---@return string
local function get_text()
  local bufnr = vim.api.nvim_win_get_buf(vim.g.statusline_winid or 0)
  for _, client in ipairs(vim.lsp.get_clients()) do
    if client.attached_buffers[bufnr] and client.name ~= "null-ls" then
      return "  " .. client.name
    end
  end
  return ""
end

---@type fml.types.ui.nvimbar.IRawComponent
local M = {
  name = "lsp",
  condition = function()
    return not not rawget(vim, "lsp")
  end,
  render = function()
    local text = get_text() ---@type string
    local width = vim.fn.strwidth(text) ---@type integer
    return fml.nvimbar.txt(text, "f_sl_text"), width
  end
}

return M
