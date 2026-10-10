---@diagnostic disable-next-line: unused-local
local __module_name__ = "ux.treeview.surface" ---@type string

local async = require("ux.treeview.async")
local decorations = require("ux.treeview.decorations")
local M = {}

---@param view                          ux.treeview.View
---@param position                      integer[]
---@param block                         boolean
---@return integer[]
local function clamp(view, position, block)
  local row = math.max(1, math.min(position[1], math.max(1, view._header.row_count)))
  local line = vim.api.nvim_buf_get_lines(view.bufnr, row - 1, row, true)[1] or ""
  local col = math.min(position[2], math.max(0, #line - (block and 0 or 1)))
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
    anchor = { mark[2], math.max(0, mark[3] - 1), mark[4] }
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
  local block = saved.visual == "\22"
  if not saved.visual then
    cursor = { view._header.cursor_row or 1, cursor[2] }
  end
  cursor = clamp(view, cursor, block)
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
      local anchor = clamp(view, saved.anchor, block)
      vim.api.nvim_win_set_cursor(view.winnr, anchor)
      vim.cmd.normal({ args = { saved.visual }, bang = true })
      if block then
        -- Restore coladd while block mode is active, then make this endpoint the anchor.
        vim.fn.winrestview({ lnum = anchor[1], col = anchor[2], coladd = saved.anchor[3] })
        vim.cmd.normal({ args = { "o" }, bang = true })
      end
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
  if view._render_guard then
    view._failed_target = view._render_guard.target
  end
  view._busy = false
  view._publishing = false
  view._render_guard = nil
  view._decoration_pending = nil
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
---@param guard                         table
---@return nil
local function retry(view, guard)
  if view._render_guard ~= guard then
    return
  end
  view._busy, view._render_guard = false, nil
  -- Waiting for a usable frame is not a failed recovery attempt.
  if guard.resync then
    view._resync_attempted = false
  end
  async.watch(view._state._data)
end

---@param view                          ux.treeview.View
---@param plan                          yoz.ux.treeview.RenderPlan
---@param header                        table
---@param staging                       table[]
---@param guard                         table
---@return nil
local function publish(view, plan, header, staging, guard)
  if view._closed or not view:_valid() or view._epoch ~= guard.epoch or view._render_guard ~= guard then
    return
  end
  view._busy = false
  local target = plan:target()
  local target_header = target:header()
  if view._submission or (view._gesture and view._header.layout_revision ~= target_header.layout_revision) then
    retry(view, guard)
    return
  end
  if not view._state._native:applicable(target, view._minimum_commit) then
    local current = view._state._native:retarget_plan(plan, view._minimum_commit)
    if not current then
      retry(view, guard)
      return
    end
    plan = current
    header = plan:header()
    target = plan:target()
    target_header = target:header()
  end
  guard.target = target_header.frame_id
  if view._publication ~= guard.publication or view._context ~= guard.context then
    retry(view, guard)
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
    retry(view, guard)
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
  local same_rows = header.mode == "Swap" and previous_frame and target:same_rows(previous_frame)
  local saved = capture(view)
  local prepared
  if target_header.row_count > 0 then
    local height = vim.api.nvim_win_get_height(view.winnr)
    local top = saved.top_node and target:position(saved.top_node) or saved.window.topline
    local cursor = saved.visual and saved.cursor[1] or target_header.cursor_row or 1
    local first = math.max(0, math.min(top - 1, cursor - 1, target_header.row_count - 1))
    first = math.max(first, math.min(cursor, target_header.row_count) - height)
    local last = math.min(first + height + 1, target_header.row_count)
    local staged, cached = guard.decorations, view._decorations
    if staged and staged.frame == target_header.frame_id and staged.first <= first and staged.last >= last then
      prepared = staged
    elseif
      same_rows
      and cached
      and cached.frame == previous_frame:id()
      and cached.first <= first
      and cached.last >= last
    then
      prepared = {
        frame = target_header.frame_id,
        first = cached.first,
        last = cached.last,
        rows = cached.rows,
        batch = cached.batch,
      }
    else
      local ok, result = pcall(decorations.prepare, target, first, last)
      if not ok then
        M.fail(view, result, false)
        return
      end
      prepared = result
    end
    guard.decorations = prepared
  end
  if guard.decoration_revision ~= view._decoration_revision then
    guard.feature = nil
    guard.decoration_revision = view._decoration_revision
  end
  local feature = guard.feature
  if prepared and view._options.prepare_frame then
    if
      not feature
      or feature.frame ~= target_header.frame_id
      or feature.first ~= prepared.first
      or feature.last ~= prepared.last
    then
      view._busy = true
      local decoration_revision = guard.decoration_revision
      view._options
        .prepare_frame(view, target, prepared.first, prepared.last, prepared.rows)
        :finally(function(ok, result)
          if view._closed or view._epoch ~= guard.epoch or view._render_guard ~= guard then
            return
          end
          if view._decoration_revision ~= decoration_revision then
            retry(view, guard)
            return
          end
          if not ok or result ~= false and type(result) ~= "function" then
            M.fail(view, ok and "Frame preparation must return a commit callback or false" or result, false)
            return
          end
          if result == false then
            retry(view, guard)
            return
          end
          guard.feature = {
            frame = target_header.frame_id,
            first = prepared.first,
            last = prepared.last,
            commit = result,
          }
          local published, error = pcall(publish, view, plan, header, staging, guard)
          if not published then
            M.fail(view, error, false)
          end
        end)
      return
    end
  end
  local unchanged = same_rows and not view._decoration_pending
  local selected_glyph, self_selected_glyph = view._glyphs.selected, view._glyphs.self_selected
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
      local feature_unchanged = feature.commit(target)
      unchanged = unchanged and feature_unchanged == true
    end
    if same_rows and (saved.visual or saved.cursor[1] == (target_header.cursor_row or 1)) then
      -- Cursor-only frames keep the already drawn window, including Visual endpoints and virtual columns.
      view._observed_cursor = saved.cursor
    else
      restore(view, saved)
    end
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
  view._render_guard = nil
  view._desynced = false
  if target_header.row_count == 0 then
    view._resync_attempted = false
  end
  view._render_error = nil
  view._failed_target = nil
  view._minimum_commit = nil
  view._decoration_pending = nil
  view._last_plan = header
  view:_cancel_source_timer()
  view._source_after = vim.uv.hrtime() + 8000000
  view._latest = nil
  if view._options.on_frame then
    local notified, error = pcall(view._options.on_frame, target)
    if not notified then
      view:_notify_error(error)
    end
  end
  if not view:_valid() then
    return
  end
  unchanged = unchanged
    and view._glyphs.selected == selected_glyph
    and view._glyphs.self_selected == self_selected_glyph
  if unchanged then
    local cursor = vim.api.nvim_win_get_cursor(view.winnr)
    if cursor[1] ~= saved.cursor[1] then
      decorations.cursor_moved(view, cursor[1] - 1)
    end
  else
    view:_redraw()
  end
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
    if view._closed or view._epoch ~= guard.epoch or view._render_guard ~= guard then
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
    if reset and view._desynced then
      view._resync_attempted = false
      async.watch(view._state._data)
    end
    return
  end
  view._busy = true
  local guard = {
    epoch = view._epoch,
    target = target:id(),
    publication = view._publication,
    context = view._context,
    changedtick = vim.api.nvim_buf_get_changedtick(view.bufnr),
    line_count = vim.api.nvim_buf_line_count(view.bufnr),
    resync = reset and view._desynced,
    decoration_revision = view._decoration_revision,
  }
  view._render_guard = guard
  if guard.resync then
    view._resync_attempted = true
  end
  local base
  if not reset then
    base = view._frame
  end
  local old_context = view._publication and view._publication.context or nil
  async.run(view._native:plan(base, target, view._context, old_context, reset)):finally(function(ok, result)
    if view._closed or view._epoch ~= guard.epoch or view._render_guard ~= guard then
      return
    end
    if not ok or type(result) ~= "userdata" then
      M.fail(view, type(result) == "table" and result.error or result, false)
      return
    end
    local prepared, error = pcall(prepare, view, result, guard)
    if not prepared then
      M.fail(view, error, false)
    end
  end)
end

return M
