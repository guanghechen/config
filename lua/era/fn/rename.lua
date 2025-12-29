local __module_name__ = "era.fn.rename" ---@type string

---@alias era.fn.rename
---| fun(params: dot.t.IRenameParams): boolean

---@class dot.t.IRenameParams
---@field public from                   string
---@field public to                     string
---@field public isdir                  ?boolean
---@field public force                  ?boolean

---@type era.fn.rename
local function rename(params)
  local from = params.from ---@type string
  local to = params.to ---@type string
  local isdir = params.isdir or false ---@type boolean
  local force = params.force or false ---@type boolean

  if not yoz.path.is_exist(from) then
    stl.reporter.error({
      from = __module_name__,
      subject = "source_not_exist",
      message = string.format("Source path does not exist: %s", from),
    })
    return false
  end

  era.lsp.event.on_rename(from, to, function()
    local move_success, move_err = yoz.fs.move({
      old_path = from,
      new_path = to,
      force = force,
    })

    if not move_success then
      local entity_type = isdir and "directory" or "file"
      stl.reporter.error({
        from = __module_name__,
        subject = "rename_failed",
        message = string.format("Failed to rename %s from %s to %s", entity_type, from, to),
        details = move_err and { error = move_err.error } or nil,
      })
      return
    end

    era.lsp.event.rename_buf(from, to)
  end)

  return true
end

return rename
