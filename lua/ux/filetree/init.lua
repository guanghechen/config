---@diagnostic disable-next-line: unused-local
local __module_name__ = "ux.filetree" ---@type string

local async = require("ux.treeview.async")
local Treeview = require("ux.treeview")
local Data = require("ux.filetree.data")
local annotations = require("ux.filetree.annotations")

local M = {}

---@param path                          string
---@param options                       ?ux.filetree.IOptions
---@return stl.c.Future
function M.open(path, options)
  local native = (rawget(_G, "yoz") or require("yoz")).ux.filetree
  return async.run(native.open(path)):map(function(value)
    if type(value) ~= "userdata" then
      return value
    end
    local tree = Treeview.from_native(value:treeview(), { on_effect = options and options.on_effect })
    local data = Data.new(value, tree)
    local poll = tree._poll
    local previous, previous_count = setmetatable({}, { __mode = "k" }), 0
    local watch_revision, watch_error, acknowledged
    tree._poll = function(owner)
      local preparing = poll(owner)
      if not preparing then
        local revision = owner:source():revision()
        if acknowledged ~= revision then
          owner._native:acknowledge_publication(revision)
          acknowledged = revision
        end
      end
      local hints, current, changed = {}, setmetatable({}, { __mode = "k" }), false
      for view in pairs(owner._views) do
        local cache = view._decorations
        if not view._closed and view._frame and cache and cache.frame == view._frame:id() then
          local signature = view._header.layout_revision .. ":" .. cache.first .. ":" .. cache.last
          current[view] = signature
          changed = changed or previous[view] ~= signature
          hints[#hints + 1] = { frame = view._frame, first = cache.first, last = cache.last }
        end
      end
      if changed or #hints ~= previous_count then
        local ok, error = pcall(value.watch_visible, value, hints)
        if ok then
          previous, previous_count, watch_error = current, #hints, nil
        elseif watch_error ~= tostring(error) then
          watch_error = tostring(error)
          async.report(error)
        end
      end
      local status = value:watch_status(watch_revision)
      if status then
        watch_revision = status.revision
        if options and options.on_effect then
          local ok, error = pcall(options.on_effect, { kind = "WatchStatus", status = status })
          if not ok then
            async.report(error)
          end
        elseif status.error and next(owner._views) ~= nil then
          stl.reporter.warn({ from = __module_name__, message = status.error.message })
        elseif status.limited and next(owner._views) ~= nil then
          stl.reporter.warn({
            from = __module_name__,
            message = "Some Filetree directories are not watched; refresh them manually",
          })
        end
      end
      local decorating = annotations.poll(owner, value)
      local pending_jobs, running_jobs, finished_jobs = false, false, false
      for job in pairs(data._jobs) do
        local status = job:status()
        if status.terminal then
          data._jobs[job] = nil
          -- The final publication may have arrived after this turn's event drain.
          finished_jobs = true
        else
          pending_jobs = true
          running_jobs = running_jobs or status.cancelling or status.confirmation == nil
        end
      end
      local busy = preparing or decorating or running_jobs or finished_jobs or value:is_busy()
      if
        not busy
        and not pending_jobs
        and not owner._pending_deadlines
        and next(owner._views) == nil
        and next(owner._works) == nil
        and next(owner._pending_reads) == nil
        and next(owner._queries) == nil
      then
        return nil
      end
      return busy
    end
    return data
  end)
end

---@param state                         ux.treeview.State
---@param options                       ?ux.treeview.IViewOptions
---@return ux.filetree.View
function M.attach(state, options)
  local native = assert(state._data._filetree_native, "Filetree views require Filetree data")
  options = vim.tbl_extend("force", options or {}, {
    prepare_frame = function(view, frame, first, last)
      return annotations.prepare(view, native, frame, first, last)
    end,
  })
  local view = Treeview.attach(state, options) ---@type ux.filetree.View
  annotations.attach(view)
  return view
end

return M
