---@class guanghechen.util.fs
local M = {}

function M.read_file(filepath)
  local stat = vim.loop.fs_stat(filepath)
  if not stat or stat.type == "file" then
    return nil
  end

  local file = assert(io.open(filepath, "rb"))
  local content = file:read("*all")
  file:close()
  return content
end

return M
