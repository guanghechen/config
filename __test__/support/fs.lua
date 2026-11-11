---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.support.fs" ---@type string

local M = {}

---Writes `content` to `path`, creating its directories: a string as its bytes, lines as `writefile` writes them.
---@param path                          string
---@param content                       string|string[]
---@return nil
function M.write(path, content)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  if type(content) == "table" then
    content = #content == 0 and "" or table.concat(content, "\n") .. "\n"
  end
  local fd = assert(vim.uv.fs_open(path, "w", 420))
  local written, err = vim.uv.fs_write(fd, content, 0)
  vim.uv.fs_close(fd)
  assert(written == #content, err or "short write: " .. path)
end

---Reads the bytes of `path`.
---@param path                          string
---@return string
function M.read(path)
  local fd = assert(vim.uv.fs_open(path, "r", 0))
  local stat = assert(vim.uv.fs_fstat(fd))
  local data, err = vim.uv.fs_read(fd, stat.size, 0)
  vim.uv.fs_close(fd)
  return assert(data, err)
end

return M
