local __module_name__ = "eve.fn.rename" ---@type string

---@alias eve.fn.rename
---| function(params: eve.fn.rename.IParams): boolean

---@class eve.fn.rename.IParams
---@field public from                   string
---@field public to                     string
---@field public isdir                  ?boolean
---@field public force                  ?boolean

---@type eve.fn.rename
local function rename(params)
  local from = params.from ---@type string
  local to = params.to ---@type string
  local isdir = params.isdir or false ---@type boolean
  local force = params.force or false ---@type boolean

  if not yoz.path.is_exist(from) then
    ark.reporter.error({
      from = __module_name__,
      subject = "source_not_exist",
      message = string.format("Source path does not exist: %s", from),
    })
    return false
  end

  eve.lsp.on_rename(from, to, function()
    local move_success, move_err = yoz.fs.move({
      old_path = from,
      new_path = to,
      force = force,
    })

    if not move_success then
      local entity_type = isdir and "directory" or "file"
      ark.reporter.error({
        from = __module_name__,
        subject = "rename_failed",
        message = string.format("Failed to rename %s from %s to %s", entity_type, from, to),
        details = move_err and { error = move_err.error } or nil,
      })
      return
    end

    eve.lsp.rename_buf(from, to)
  end)

  return true
end

return rename
