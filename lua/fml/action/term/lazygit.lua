---@param name                          string
---@param cwd                           string
---@param args                          ?string[]
---@return nil
local function open_lazygit(name, cwd, args)
  local argv = table.concat(args or {}, " ") ---@type string
  local cmd = #argv > 0 and string.format("lazygit %s", argv) or "lazygit"
  require("fml.action.term.toggle").toggle({
    uuid = "1c2b6245-da30-499a-8e23-8c33b5bd1a77#lazygit",
    name = name,
    cmd = cmd,
    cwd = cwd,
    permanent = true,
  })
end

---@class fml.action.term
local M = {}

---@return nil
function M.lazygit_cwd()
  local cwd = std.path.cwd() ---@type string
  open_lazygit("lazygit_cwd", cwd)
end

---@return nil
function M.lazygit_workspace()
  local cwd = std.path.workspace() ---@type string
  open_lazygit("lazygit_workspace", cwd)
end

---@return nil
function M.lazygit_file_history()
  local cwd = std.path.cwd() ---@type string
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
  local args = { "-f", vim.fn.shellescape(filepath) } ---@type string[]
  open_lazygit("lazygit_file_history", cwd, args)
end

return M
