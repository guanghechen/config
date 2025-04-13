---see https://github.com/hakonharnes/img-clip.nvim/blob/08a02e14c8c0d42fa7a92c30a98fd04d6993b35d/lua/img-clip/init.lua#L1

local __module_name__ = "eve.builtin.clipboard" ---@type string

local MAX_BASE64_SIZE = 24 * 1024 ---@type number

---@class eve.builtin.clipboard
---@field public has_image              fun(): boolean
---@field public get_image_as_base64    fun(): string|nil
---@field public paste_image            fun(filepath: string): boolean
---@field public get_clipboard          fun(): table|nil
local M = {}

if eve.env.IS_MAC then
  M = require("eve.builtin.clipboard.mac")
elseif eve.env.IS_WSL then
  M = require("eve.builtin.clipboard.wsl")
elseif eve.env.IS_NIX then
  M = require("eve.builtin.clipboard.nix")
elseif eve.env.IS_WIN then
  M = require("eve.builtin.clipboard.win")
end

---@param filename                      string
---@param src                           string
---@return boolean
function M.insert_markup(filename, src)
  local content = src ---@type string
  local extname = eve.path.extname(filename) ---@type string
  if extname == ".md" then
    content = string.format("![%s][%s]", filename, src)
  end

  local lines = vim.split(content, "\n")
  if lines[1] and lines[1]:match("^%s*$") then
    table.remove(lines, 1)
  end
  if lines[#lines] and lines[#lines]:match("^%s*$") then
    table.remove(lines)
  end

  vim.api.nvim_put(lines, "l", true, true)
  return true
end

---@param source_filepath               string
---@return boolean
function M.paste_image_as_base64(source_filepath)
  local filetype = vim.bo.filetype ---@type string
  if eve.filetype.is_not_sourcefile(filetype) then
    eve.reporter.warn({
      from = __module_name__,
      subject = "paste_image_as_base64",
      message = "Filetype does not support base64 encoding.",
      details = { source_filepath = source_filepath, filetype = filetype },
    })
    return false
  end

  local base64 = nil ---@type string|nil
  if source_filepath then
    base64 = eve.fs.read_file_as_base64({ filepath = source_filepath, silent = false })
  else
    base64 = M.get_image_as_base64()
  end

  if base64 == nil or type(base64) ~= "string" or #base64 < 1 then
    eve.reporter.error({
      from = __module_name__,
      subject = "paste_image_as_base64",
      message = "Could not get base64 string.",
      details = { source_filepath = source_filepath, filetype = filetype },
    })
    return false
  end

  -- check if base64 string is too long (max_base64_size is in KB)
  local size_bytes = math.floor((string.len(base64) * 6) / 8)
  if size_bytes > MAX_BASE64_SIZE then
    eve.reporter.warn({
      from = __module_name__,
      subject = "paste_image_as_base64",
      message = "Base64 string is too large.",
      details = { size_bytes = size_bytes, MAX_BASE64_SIZE = MAX_BASE64_SIZE },
    })
    return false
  end

  local filename = eve.path.basename(source_filepath) ---@type string
  local src = "data:image/png;base64," .. base64
  return M.insert_markup(filename, src)
end

---@param filepath_source               string
---@param filepath_target               string
---@return boolean
function M.paste_image_from_path(filepath_source, filepath_target)
  local ok = pcall(function()
    eve.fs.copy_file(filepath_source, filepath_target)
  end)
  return ok
end

return M
