local state = require("eve.state")

---@return string
local function get_text()
  local winnr = eve.locations.get_current_winnr() or 0 ---@type integer
  local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer

  local client_names = {} ---@type string[]
  for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
    if client.attached_buffers[bufnr] and client.name ~= "null-ls" and client.name ~= "copilot" then
      table.insert(client_names, client.name)
    end
  end

  return #client_names > 0 and "  " .. table.concat(client_names, "|") or ""
end

---@type fml.t.ux.nvimbar.IRawComponent
local M = {
  name = "lsp",
  condition = function()
    return not not rawget(vim, "lsp")
  end,
  render = function()
    local text = get_text() ---@type string
    local width = vim.api.nvim_strwidth(text) ---@type integer
    local hl_text = eve.nvim.txt(text, "f_sl_text") ---@type string

    local lsp_msg = state.state.status.lsp_msg:snapshot() ---@type string
    if lsp_msg ~= "" then
      hl_text = eve.nvim.txt(lsp_msg, "f_sl_text") .. " " .. hl_text
      width = width + vim.api.nvim_strwidth(lsp_msg) + 1
    end

    return hl_text, width
  end,
}

return M
