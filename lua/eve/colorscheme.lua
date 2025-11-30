local __module_name__ = "eve.colorscheme" ---@type string

---@class IEveColorschemeLoadOptions
---@field public transparency           ?boolean

---@class eve.colorscheme
local M = {}

---@param theme                         std.e.ThemeFullName
---@param opts                          IEveColorschemeLoadOptions|nil
---@return boolean
function M.load(theme, opts)
  if type(theme) ~= "string" or #theme == 0 then
    std.reporter.error({
      from = __module_name__,
      subject = "load",
      message = "Invalid theme name.",
      details = { theme = theme },
    })
    return false
  end

  opts = opts or {} ---@type IEveColorschemeLoadOptions

  local context_theme = eve.context.theme
  local scheme = context_theme.get_scheme(theme) ---@type std.t.theme.IScheme|nil
  if scheme == nil then
    return false
  end

  local transparency = opts.transparency ---@type boolean|nil
  local update_transparency = type(transparency) == "boolean" ---@type boolean
  if not update_transparency then
    transparency = context_theme.transparency:snapshot()
  elseif transparency ~= context_theme.transparency:snapshot() then
    context_theme.transparency:next(transparency, { force = true })
  end

  context_theme.theme:next(theme, { force = true })
  context_theme.reload_theme(true, true)
  return true
end

return M
