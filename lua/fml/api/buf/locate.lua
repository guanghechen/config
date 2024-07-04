local state = require("fml.api.state")

---@class fml.api.buf
local M = require("fml.api.buf.mod")

---@param filepath                      string
---@return integer|nil
function M.locate_by_filepath(filepath)
  local target_filepath = vim.fn.fnamemodify(filepath, ":p") ---@type string
  for bufnr, buf in pairs(state.bufs) do
    if buf.filepath == target_filepath then
      return bufnr
    end
  end

  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      local bufname = vim.api.nvim_buf_get_name(bufnr)
      local buf_filepath = vim.fn.fnamemodify(bufname, ":p")
      if buf_filepath == target_filepath then
        state.schedule_refresh_bufs()
        return bufnr
      end
    end
  end
  return nil
end
