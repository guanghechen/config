---@return string
local function get_text()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local tab = fml.api.state.get_tab(tabnr) ---@type fml.types.api.state.ITabItem|nil
  local winnr = tab ~= nil and tab.winnr_cur:snapshot() or 0 ---@type integer
  local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer

  local client_names = {} ---@type string[]
  for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
    if client.attached_buffers[bufnr] and client.name ~= "null-ls" and client.name ~= "copilot" then
      table.insert(client_names, client.name)
    end
  end

  return #client_names > 0 and "  " .. table.concat(client_names, "|") or ""
end

---@type fml.types.ui.nvimbar.IRawComponent
local M = {
  name = "lsp",
  condition = function()
    return not not rawget(vim, "lsp")
  end,
  render = function()
    local text = get_text() ---@type string
    local width = vim.api.nvim_strwidth(text) ---@type integer
    local hl_text = eve.nvimbar.txt(text, "f_sl_text") ---@type string

    local lsp_msg = eve.globals.state.lsp_msg ---@type string
    if lsp_msg ~= "" then
      hl_text = hl_text .. " " .. lsp_msg
      width = width + vim.api.nvim_strwidth(lsp_msg) + 1
    end

    return hl_text, width
  end,
}

return M
