local fs = require("fml.core.fs")

---@class fml.api.buffer
local M = {}

---@param filepath string
---@return integer|nil
function M.find_buf_with_filepath(filepath)
  ---Expand the filepath to get the absolute path.
  local target_filepath = vim.fn.fnamemodify(filepath, ":p") ---@type string
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      local bufname = vim.api.nvim_buf_get_name(bufnr)
      local buf_filepath = vim.fn.fnamemodify(bufname, ":p")
      if buf_filepath == target_filepath then
        return bufnr
      end
    end
  end
  return nil
end

---@param filepath string
---@return string
function M.read_of_load_buf_with_filepath(filepath)
  local target_filepath = vim.fn.fnamemodify(filepath, ":p") ---@type string
  local target_bufnr = M.find_buf_with_filepath(filepath) ---@type integer|nil

  if target_bufnr ~= nil then
    local lines = vim.api.nvim_buf_get_lines(target_bufnr, 0, -1, false) ---@type string[]
    return table.concat(lines, "\n")
  end

  return fs.read_file(target_filepath) or ""
end

return M
