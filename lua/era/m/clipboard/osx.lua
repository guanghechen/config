---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.clipboard.osx" ---@type string

---@class era.m.clipboard.osx
local M = {}

local exec = require("era.m.clipboard.exec")

---@return string|nil
function M.get_image_as_base64()
  local cmd = { "pngpaste", "-b" } ---@type string[]
  local result = exec.run(__module_name__, "get_image_as_base64", cmd)
  if result == nil then
    return nil
  end

  local output = result.stdout or "" ---@type string
  local encoded = output:gsub("\r\n", ""):gsub("\n", ""):gsub("\r", "")
  return encoded
end

---@return boolean
function M.has_image()
  local cmd = { "pngpaste", "-" } ---@type string[]
  return exec.run(__module_name__, "has_image", cmd, { stdout = function() end }) ~= nil
end

---@param filepath                      string
---@return  boolean
function M.paste_image_from_clipboard(filepath)
  local cmd = { "pngpaste", filepath } ---@type string[]
  return exec.run(__module_name__, "paste_image_from_clipboard", cmd) ~= nil
end

return M
