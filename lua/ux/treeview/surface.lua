---@diagnostic disable-next-line: unused-local
local __module_name__ = "ux.treeview.surface" ---@type string

local async = require("ux.treeview.async")
local decorations = require("ux.treeview.decorations")
local M = {}

---@param view                          ux.treeview.View
---@param position                      integer[]
---@return integer[]
local function clamp(view, position)
  local row = math.max(1, math.min(position[1], math.max(1, view._header.row_count)))
  local line = vim.api.nvim_buf_get_lines(view.bufnr, row - 1, row, true)[1] or ""
  local col = math.min(position[2], math.max(0, #line - 1))
  while col > 0 do
    local byte = line:byte(col + 1)
    if not byte or byte < 128 or byte >= 192 then
      break
    end
    col = col - 1
  end
  return { row, col }
end

---@param view                          ux.treeview.View
---@return table
local function capture(view)
  local cursor = vim.api.nvim_win_get_cursor(view.winnr)
  local window = vim.api.nvim_win_call(view.winnr, vim.fn.winsaveview)
  local visual = view:_visual_mode()
  local anchor
  if visual then
    local mark = vim.fn.getpos("v")
    anchor = { mark[2], math.max(0, mark[3] - 1) }
  end
  return {
    cursor = cursor,
    window = window,
    visual = visual,
    anchor = anchor,
    top_node = view._frame and view._frame:node_at(window.topline) or nil,
  }
end

---@param view                          ux.treeview.View
---@param saved                         table
---@return nil
local function restore(view, saved)
  local cursor = saved.cursor
  if not saved.visual then
    cursor = { view._header.cursor_row or 1, cursor[2] }
  end
  cursor = clamp(view, cursor)
  if saved.top_node then
    saved.window.topline = view._frame:position(saved.top_node) or saved.window.topline
  end
  saved.window.topline = math.max(1, math.min(saved.window.topline, math.max(1, view._header.row_count)))
  saved.window.lnum = cursor[1]
  saved.window.col = cursor[2]
  saved.window.skipcol = 0
  vim.api.nvim_win_call(view.winnr, function()
    if saved.visual then
      vim.cmd.normal({ args = { vim.keycode("<Esc>") }, bang = true })
      vim.api.nvim_win_set_cursor(view.winnr, clamp(view, saved.anchor))
      vim.cmd.normal({ args = { saved.visual }, bang = true })
    end
    vim.api.nvim_win_set_cursor(view.winnr, cursor)
    vim.fn.winrestview(saved.window)
  end)
  view._observed_cursor = vim.api.nvim_win_get_cursor(view.winnr)
end

---@param view                          ux.treeview.View
---@param error                         any
---@param desynced                      boolean
---@return nil
function M.fail(view, error, desynced)
  view._busy = false
  view._publishing = false
  if view._closed then
    return
  end
  view._render_error = error
  view._desynced = view._desynced or desynced
  view._decorations = nil
  if view._desynced then
    view._gesture = nil
  end
  view:_notify_error(error)
  if view._desynced and not view._resync_attempted then
    view._resync_attempted = true
    vim.schedule(function()
      if not view._closed and view:_valid() then
        view._failed_target = nil
        M.request(view, view._native:snapshot(), true)
      end
    end)
  end
end

---@param view                          ux.treeview.View
---@param plan                          yoz.ux.treeview.RenderPlan
---@param header                        table
---@param staging                       table[]
---@param guard                         table
---@return nil
local function publish(view, plan, header, staging, guard)
  view._busy = false
  if view._closed or not view:_valid() or view._epoch ~= guard.epoch then
    return
  end
  local target = plan:target()
  local target_header = target:header()
  if view._submission or (view._gesture and view._header.layout_revision ~= target_header.layout_revision) then
    return
  end
  if not view._state._native:applicable(target, view._minimum_commit) then
    local current = view._state._native:retarget_plan(plan, view._minimum_commit)
    if not current then
      return
    end
    plan = current
    header = plan:header()
    target = plan:target()
    target_header = target:header()
  end
  if view._publication ~= guard.publication or view._context ~= guard.context then
    return
  end
  if
    vim.api.nvim_buf_get_changedtick(view.bufnr) ~= guard.changedtick
    or vim.api.nvim_buf_line_count(view.bufnr) ~= guard.line_count
  then
    M.fail(view, "Treeview buffer changed while preparing a frame", true)
    return
  end
  if header.mode ~= "Reset" and view._desynced then
    return
  end
  if header.mode ~= "Reset" and guard.line_count ~= math.max(1, guard.publication.row_count) then
    M.fail(view, "Treeview publication extent changed", true)
    return
  end
  for index, splice in ipairs(header.splices) do
    if splice[1] > splice[2] or splice[3] > splice[4] or #staging[index] ~= splice[4] - splice[3] then
      M.fail(view, "Invalid Treeview render staging", false)
      return
    end
  end
  local previous_frame, previous_header = view._frame, view._header
  local saved = capture(view)
  local prepared
  if target_header.row_count > 0 then
    local height = vim.api.nvim_win_get_height(view.winnr)
    local top = saved.top_node and target:position(saved.top_node) or saved.window.topline
    local cursor = saved.visual and saved.cursor[1] or target_header.cursor_row or 1
    local first = math.max(0, math.min(top - 1, cursor - 1, target_header.row_count - 1))
    first = math.max(first, math.min(cursor, target_header.row_count) - height)
    local ok, result = pcall(decorations.prepare, target, first, math.min(first + height + 1, target_header.row_count))
    if not ok then
      view._failed_target = target:id()
      M.fail(view, result, false)
      return
    end
    prepared = result
  end
  local feature = guard.feature
  if prepared and view._options.prepare_frame then
    if
      not feature
      or feature.data ~= target_header.data_revision
      or feature.layout ~= target_header.layout_revision
      or feature.first ~= prepared.first
      or feature.last ~= prepared.last
    then
      view._busy = true
      view._options.prepare_frame(view, target, prepared.first, prepared.last):finally(function(ok, result)
        if view._closed or view._epoch ~= guard.epoch then
          return
        end
        if not ok or result ~= false and type(result) ~= "function" then
          view._failed_target = target:id()
          M.fail(view, ok and "Frame preparation must return a commit callback or false" or result, false)
          return
        end
        if result == false then
          view._busy = false
          return
        end
        guard.feature = {
          data = target_header.data_revision,
          layout = target_header.layout_revision,
          first = prepared.first,
          last = prepared.last,
          commit = result,
        }
        local published, error = pcall(publish, view, plan, header, staging, guard)
        if not published then
          view._failed_target = target:id()
          M.fail(view, error, false)
        end
      end)
      return
    end
  end
  view._publishing = true
  local ok, error = pcall(function()
    if header.mode ~= "Swap" then
      vim.api.nvim_set_option_value("modifiable", true, { buf = view.bufnr })
      for index = #header.splices, 1, -1 do
        local splice = header.splices[index]
        local first, last = splice[1], splice[2]
        if header.mode == "Reset" then
          first, last = 0, -1
        end
        vim.api.nvim_buf_set_lines(view.bufnr, first, last, true, staging[index])
      end
      vim.api.nvim_set_option_value("modifiable", false, { buf = view.bufnr })
    end
    view._frame, view._header = target, target_header
    view._decorations = prepared
    if feature and prepared then
      feature.commit(target)
    end
    restore(view, saved)
  end)
  if not ok then
    view._frame, view._header = previous_frame, previous_header
    if vim.api.nvim_buf_is_valid(view.bufnr) then
      pcall(vim.api.nvim_set_option_value, "modifiable", false, { buf = view.bufnr })
    end
    M.fail(view, error, true)
    return
  end
  view._publication = {
    frame_id = header.target,
    row_count = header.row_count,
    changedtick = vim.api.nvim_buf_get_changedtick(view.bufnr),
    context = view._context,
  }
  view._publishing = false
  view._desynced = false
  if target_header.row_count == 0 then
    view._resync_attempted = false
  end
  view._render_error = nil
  view._failed_target = nil
  view._minimum_commit = nil
  view._last_plan = header
  if view._gesture then
    view._gesture.frame = target
  end
  view._latest = nil
  if view._options.on_frame then
    local notified, error = pcall(view._options.on_frame, target)
    if not notified then
      view:_notify_error(error)
    end
  end
  view:_redraw()
end

---@param view                          ux.treeview.View
---@param plan                          yoz.ux.treeview.RenderPlan
---@param guard                         table
---@return nil
local function prepare(view, plan, guard)
  local header = plan:header()
  if header.text_bytes > 64 * 1024 * 1024 then
    error("Treeview staging exceeded 64 MiB")
  end
  local staging = {}
  local index, row = 1, nil
  for at = 1, #header.splices do
    staging[at] = {}
  end
  local step
  ---@return nil
  step = function()
    if view._closed or view._epoch ~= guard.epoch then
      view._busy = false
      return
    end
    local started = vim.uv.hrtime()
    while index <= #header.splices do
      local splice = header.splices[index]
      row = row or splice[3]
      if row == splice[4] then
        index, row = index + 1, nil
      else
        local lines, next_row = plan:lines(row, math.min(row + 512, splice[4]), 64 * 1024)
        if next_row == row then
          error("Treeview text transfer made no progress")
        end
        table.move(lines, 1, #lines, #staging[index] + 1, staging[index])
        row = next_row
      end
      if vim.uv.hrtime() - started >= 2 * 1000 * 1000 then
        vim.schedule(function()
          local ok, error = pcall(step)
          if not ok then
            M.fail(view, error, false)
          end
        end)
        return
      end
    end
    publish(view, plan, header, staging, guard)
  end
  step()
end

---@param view                          ux.treeview.View
---@param target                        yoz.ux.treeview.Frame
---@param reset                         boolean
---@return nil
function M.request(view, target, reset)
  if view._busy or view._closed or not view:_valid() then
    return
  end
  if not view._state._native:applicable(target, view._minimum_commit) then
    return
  end
  view._busy = true
  local guard = {
    epoch = view._epoch,
    publication = view._publication,
    context = view._context,
    changedtick = vim.api.nvim_buf_get_changedtick(view.bufnr),
    line_count = vim.api.nvim_buf_line_count(view.bufnr),
  }
  local base
  if not reset then
    base = view._frame
  end
  local old_context = view._publication and view._publication.context or nil
  async.run(view._native:plan(base, target, view._context, old_context, reset)):finally(function(ok, result)
    if view._closed or view._epoch ~= guard.epoch then
      return
    end
    if not ok or type(result) ~= "userdata" then
      view._failed_target = target:id()
      M.fail(view, type(result) == "table" and result.error or result, false)
      return
    end
    local prepared, error = pcall(prepare, view, result, guard)
    if not prepared then
      view._failed_target = target:id()
      M.fail(view, error, false)
    end
  end)
end

return M
