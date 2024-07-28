---@return string
local function get_text()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local tab = fml.api.state.get_tab(tabnr) ---@type fml.types.api.state.ITabItem|nil
  local winnr = tab ~= nil and tab.winnr_cur:snapshot() or 0 ---@type integer
  local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer

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
  end,
}

return M
