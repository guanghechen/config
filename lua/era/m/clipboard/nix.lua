---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.clipboard.nix" ---@type string

---@class era.m.clipboard.nix
local M = {}

local exec = require("era.m.clipboard.exec")

---@return boolean
function M.has_image()
  local cmd = { "xclip", "-selection", "clipboard", "-t", "TARGETS", "-o" } ---@type string[]
  local result = exec.run(__module_name__, "has_image", cmd)
  if result == nil then
    return false
  end

  return (result.stdout or ""):find("image/png") ~= nil
end

---@return string|nil
function M.get_image_as_base64()
  local cmd = { "xclip", "-selection", "clipboard", "-o", "-t", "image/png" } ---@type string[]
  local result = exec.run(__module_name__, "get_image_as_base64", cmd, { text = false })
  if result == nil then
    return nil
  end

  local image = result.stdout or "" ---@type string
  if image == "" then
    stl.reporter.error({
      from = __module_name__,
      subject = "get_image_as_base64",
      message = "Clipboard image is empty.",
      details = { cmd = cmd },
    })
    return nil
  end

  return vim.base64.encode(image)
end

---@param filepath                      string
---@return  boolean
function M.paste_image_from_clipboard(filepath)
  local cmd = {
    "sh",
    "-c",
    'xclip -selection clipboard -o -t image/png > "$1"',
    "sh",
    filepath,
  } ---@type string[]
  ---@type vim.SystemCompleted|nil
  local exec_result = exec.run(__module_name__, "paste_image_from_clipboard", cmd, nil, { filepath = filepath })
  return exec_result ~= nil
end

return M
