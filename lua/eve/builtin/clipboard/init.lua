---see https://github.com/hakonharnes/img-clip.nvim/blob/08a02e14c8c0d42fa7a92c30a98fd04d6993b35d/lua/img-clip/init.lua#L1

local __module_name__ = "eve.builtin.clipboard" ---@type string

local BYTE_DOT = std.byte.BYTES.DOT ---@type integer
local MAX_BASE64_SIZE = 24 * 1024 ---@type number

---@class eve.builtin.clipboard
---@field public get_clipboard          fun(): table|nil
---@field public get_image_as_base64    fun(): string|nil
---@field public has_image              fun(): boolean
---@field public paste_image_from_clipboard fun(filepath_target: string): boolean
local M = {}

if std.env.IS_MAC then
  M = require("eve.builtin.clipboard.mac")
elseif std.env.IS_WSL then
  M = require("eve.builtin.clipboard.wsl")
elseif std.env.IS_NIX then
  M = require("eve.builtin.clipboard.nix")
elseif std.env.IS_WIN then
  M = require("eve.builtin.clipboard.win")
end

---@param alt                           string
---@param src                           string
---@return boolean
function M.insert_markup(alt, src)
  local content = src ---@type string
  local filetype = vim.bo.filetype ---@type string

  if filetype == "markdown" then
    content = string.format("![%s](%s)", alt, src)
  end

  local lines = vim.split(content, "\n", { plain = true }) ---@type string[]
  vim.api.nvim_put(lines, "l", true, true)
  return true
end

---@param filepath_target               string
---@return boolean
function M.paste_image(filepath_target)
  local ok = M.paste_image_from_clipboard(filepath_target)
  if ok then
    local filetype = vim.bo.filetype ---@type string
    if eve.filetype.is_sourcefile(filetype) then
      local filepath_current = vim.api.nvim_buf_get_name(0) ---@type string
      local src = std.path.relative(std.path.dirname(filepath_current), filepath_target, true) ---@type string
      if #src > 1 then
        if string.byte(src, 1, 1) ~= BYTE_DOT then
          src = "." .. std.env.PATH_SEP .. src
        end
        local filename = std.path.basename(filepath_target) ---@type string
        local alt = vim.fn.fnamemodify(filename, ":r") ---@type string

        vim.schedule(function()
          M.insert_markup(alt, src)
        end)
      end
    end
  end
  return ok
end

---@param filepath_source               string
---@return boolean
function M.paste_image_as_base64(filepath_source)
  local filetype = vim.bo.filetype ---@type string
  if eve.filetype.is_not_sourcefile(filetype) then
    std.reporter.warn({
      from = __module_name__,
      subject = "paste_image_as_base64",
      message = "Filetype does not support base64 encoding.",
      details = { filepath_source = filepath_source, filetype = filetype },
    })
    return false
  end

  local base64 = nil ---@type string|nil
  if filepath_source then
    base64 = std.fs.read_file_as_base64({ filepath = filepath_source, silent = false })
  else
    base64 = M.get_image_as_base64()
  end

  if base64 == nil or type(base64) ~= "string" or #base64 < 1 then
    std.reporter.error({
      from = __module_name__,
      subject = "paste_image_as_base64",
      message = "Could not get base64 string.",
      details = { filepath_source = filepath_source, filetype = filetype },
    })
    return false
  end

  -- check if base64 string is too long (max_base64_size is in KB)
  local size_bytes = math.floor((string.len(base64) * 6) / 8)
  if size_bytes > MAX_BASE64_SIZE then
    std.reporter.warn({
      from = __module_name__,
      subject = "paste_image_as_base64",
      message = "Base64 string is too large.",
      details = { size_bytes = size_bytes, MAX_BASE64_SIZE = MAX_BASE64_SIZE },
    })
    return false
  end

  local filename = std.path.basename(filepath_source) ---@type string
  local src = "data:image/png;base64," .. base64
  return M.insert_markup(filename, src)
end

return M
