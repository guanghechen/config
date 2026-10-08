---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.bench.explorer.startup_runtime" ---@type string

local active
local M = {}

---@param kind                          string
---@param interval                      integer
---@param ready                         fun(): boolean
---@return nil
local function observe(kind, interval, ready)
  assert(not active, "startup observer is already running")
  local timer = assert(vim.uv.new_timer())
  active = timer
  local checks = 0
  ---@return nil
  local function check()
    if active ~= timer then
      return
    end
    checks = checks + 1
    local ok, done = pcall(ready)
    if not ok or done then
      active = nil
      timer:stop()
      timer:close()
      if ok then
        vim.rpcnotify(1, "explorer_bench_startup", kind, { at = vim.uv.hrtime(), checks = checks })
      else
        vim.rpcnotify(1, "explorer_bench_error", tostring(done))
      end
    end
  end
  timer:start(interval, interval, vim.schedule_wrap(check))
  check()
end

---@return nil
function M.configuration()
  observe("startup", 5, function()
    local input, loader = package.loaded["era.m.input"], package.loaded["era.m.plugin.loader"]
    return input and loader and vim.ui.input == input.open and loader.get_startup_profile().finalized or false
  end)
end

---@param directory                     string
---@param entries                       integer
---@param native                        boolean
---@return nil
function M.open(directory, entries, native)
  vim.cmd.edit(directory .. "/files/file-00000.txt")
  era.widget.explorer.focus()
  M.widget = era.widget.explorer.get_widget()
  observe("first_explorer", 2, function()
    if native then
      local view = M.widget._views[vim.api.nvim_get_current_tabpage()]
      return view
          and view:frame()
          and view:frame():header().row_count == entries
          and not M.widget._session.data._native:is_busy()
          and not view._busy
          and not view._filetree_pending
        or false
    end
    local value = M.widget:get_render_result()
    return value and #value.lines == entries and #value.deferred_file_icons == 0 or false
  end)
end

---@return nil
function M.dispose()
  if active then
    active:stop()
    active:close()
    active = nil
  end
  if M.widget then
    M.widget:dispose()
  end
end

return M
