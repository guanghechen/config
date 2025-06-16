local toggle_term = require("fml.action.term.toggle").toggle

---@return string|nil
local function get_lazygit_config_filepath()
  local HOME_LAZYGIT = std.path.locate_app_config_home("lazygit") ---@type string

  ---@type string[]
  local candidate_config_filepaths = {
    std.path.join(HOME_LAZYGIT, "local/theme.yml"),
    std.path.join(HOME_LAZYGIT, "config.yml"),
  }

  for _, config_filepath in ipairs(candidate_config_filepaths) do
    if vim.fn.filereadable(config_filepath) ~= 0 then
      return config_filepath
    end
  end
  return nil
end

---@param name                          string
---@param cwd                           string
---@param args                          ?string[]
---@return nil
local function open_lazygit(name, cwd, args)
  local config_path = get_lazygit_config_filepath() ---@type string|nil
  local cmd = config_path and "lazygit -ucf " .. vim.fn.shellescape(config_path) .. " " .. table.concat(args or {}, " ")
    or "lazygit " .. table.concat(args or {}, " ")

  toggle_term({
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
