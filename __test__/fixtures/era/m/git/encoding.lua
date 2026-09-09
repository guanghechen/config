---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.fixtures.era.m.git.encoding" ---@type string

local M = {}

M.formats = {
  { name = "utf-8", aliases = { "utf8", "UTF_8" }, astral = true },
  { name = "utf-16", aliases = { "utf16", "utf-16be", "UTF_16BE" }, astral = true },
  { name = "utf-16le", aliases = { "utf16le", "UTF_16LE" }, astral = true },
  { name = "ucs-2", aliases = { "unicode", "ucs2", "ucs-2be", "UCS_2BE" }, astral = false },
  { name = "ucs-2le", aliases = { "ucs2le", "UCS_2LE" }, astral = false },
  { name = "ucs-4", aliases = { "ucs4", "ucs-4be", "utf32", "utf-32", "UTF_32BE" }, astral = true },
  { name = "ucs-4le", aliases = { "ucs4le", "utf32le", "UTF_32LE" }, astral = true },
}

---@param t                             __test__.support.Harness
---@param text                          string UTF-8 text with LF separators
---@param encoding                      string
---@param bomb                          boolean
---@param fileformat                    ?string
---@return string                       Bytes produced by Neovim's file writer, not vim.iconv
---@return integer                      Buffer owned by the test, for subsequent unsaved edits
function M.write(t, text, encoding, bomb, fileformat)
  local path = vim.fn.tempname()
  t:defer(function()
    vim.fn.delete(path)
  end)
  local bufnr = vim.api.nvim_create_buf(false, false)
  t:defer(function()
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)
  vim.api.nvim_buf_set_name(bufnr, path)
  local has_eol = text:sub(-1) == "\n"
  local lines = vim.split(text, "\n", { plain = true })
  if has_eol then
    lines[#lines] = nil
  end
  if #lines == 0 then
    lines[1] = ""
  end
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  for option, value in pairs({
    fileencoding = encoding,
    bomb = bomb,
    fileformat = fileformat or "unix",
    eol = has_eol,
    fixeol = false,
  }) do
    vim.api.nvim_set_option_value(option, value, { buf = bufnr })
  end
  vim.api.nvim_buf_call(bufnr, function()
    vim.cmd("silent noautocmd write!")
  end)
  local file = assert(io.open(path, "rb"))
  local close = t:defer(function()
    file:close()
  end)
  local bytes = assert(file:read("*a"))
  close()
  return bytes, bufnr
end

---@param bytes                         string
---@return string
function M.hex(bytes)
  return (bytes:gsub(".", function(char)
    return string.format("%02x", char:byte())
  end))
end

return M
