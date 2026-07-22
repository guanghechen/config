---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.clipboard.mac" ---@type string

---@class era.m.clipboard.mac
local M = {}

---@param subject                       string
---@param cmd                           string[]
---@param opts                          ?vim.SystemOpts
---@return vim.SystemCompleted|nil
local function run(subject, cmd, opts)
  local ok, result = pcall(function()
    return vim.system(cmd, opts or { text = true }):wait()
  end)
  if ok and result.code == 0 then
    return result
  end

  stl.reporter.error({
    from = __module_name__,
    subject = subject,
    message = "Failed to run command.",
    details = {
      cmd = cmd,
      exit_code = ok and result.code or nil,
      output = ok and result.stdout or nil,
      error = ok and result.stderr or result,
    },
  })
  return nil
end

---@return string|nil
function M.get_image_as_base64()
  local cmd = { "pngpaste", "-b" } ---@type string[]
  local result = run("get_image_as_base64", cmd)
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
  return run("has_image", cmd, { stdout = function() end }) ~= nil
end

---@param filepath                      string
---@return  boolean
function M.paste_image_from_clipboard(filepath)
  local cmd = { "pngpaste", filepath } ---@type string[]
  return run("paste_image_from_clipboard", cmd) ~= nil
end

return M
