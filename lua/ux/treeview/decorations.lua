---@diagnostic disable-next-line: unused-local
local __module_name__ = "ux.treeview.decorations" ---@type string

local async = require("ux.treeview.async")
local namespace = vim.api.nvim_create_namespace("ux.treeview")
local views = {} ---@type table<integer, ux.treeview.View>
local M = {}

---@param frame                         yoz.ux.treeview.Frame
---@param first                         integer
---@param last                          integer
---@param previous                      ?table
---@return table
function M.prepare(frame, first, last, previous)
  local id = frame:id()
  local batch = previous and previous.frame == id and previous.batch or nil
  if not batch or batch.first > first or batch.last < last or first > last or last - first > 512 then
    local start, finish = first, last
    local overlapping = batch and first < batch.last and last > batch.first
    local limited = overlapping and batch.limited or nil
    if overlapping and not limited and first >= 0 and first <= last and last - first < 512 then
      local missing = math.max(0, batch.first - first) + math.max(0, last - batch.last)
      if missing <= 16 then
        local extra = math.min(8, math.floor((512 - (last - first)) / 2))
        start = math.max(0, first - extra)
        finish = math.min(frame:header().row_count, last + extra)
      end
    end
    local rows
    if (start ~= first or finish ~= last) and start <= first and finish >= last then
      local ok, result = pcall(frame.rows, frame, start + 1, finish)
      if ok then
        rows = result
      else
        limited = true
      end
    end
    if not rows then
      -- Overscan must not make an otherwise valid viewport exceed native read budgets.
      start, finish, rows = first, last, frame:rows(first + 1, last)
    end
    batch = { first = start, last = finish, rows = rows, limited = limited }
  end
  local rows = batch.rows
  if batch.first ~= first or batch.last ~= last then
    rows = { first = first + 1 }
    local offset = first - batch.first
    for name, column in pairs(batch.rows) do
      if name ~= "first" then
        rows[name] = table.move(column, offset + 1, offset + last - first, 1, {})
      end
    end
  end
  return { frame = id, first = first, last = last, rows = rows, batch = batch }
end

---@param view                          ux.treeview.View
---@param row                           integer
---@param first                         integer
---@param last                          integer
---@return table|nil
local function prepare_path(view, row, first, last)
  if view._header.mode ~= "tree" then
    view._guide_path, view._guide_dirty = nil, nil
    return nil
  end
  local dirty = view._guide_dirty
  if dirty then
    dirty.first, dirty.last = math.max(first, dirty.first), math.min(last, dirty.last)
    if dirty.first >= dirty.last then
      view._guide_dirty, dirty = nil, nil
    end
  end
  local path = view._guide_path
  if
    path
    and path.layout == view._header.layout_revision
    and path.row == row
    and row >= first
    and row < last
    and path.first <= first
    and path.last >= last
  then
    return path
  end
  local previous = path
  path = nil
  if row >= first and row < last then
    local segments = view._frame:guide_path(row + 1, first + 1, last)
    path = {
      layout = view._header.layout_revision,
      row = row,
      first = first,
      last = last,
      depths = {},
      connectors = {},
    }
    for _, segment in ipairs(segments) do
      for lnum = segment.first, segment.last do
        path.depths[lnum - first] = segment.depth
      end
      path.connectors[segment.last - first] = true
    end
  end
  for current = first, last - 1 do
    local old_index = previous and current - previous.first + 1
    local new_index = path and current - path.first + 1
    if
      (previous and previous.depths[old_index]) ~= (path and path.depths[new_index])
      or (previous and previous.connectors[old_index]) ~= (path and path.connectors[new_index])
    then
      if dirty then
        dirty.first, dirty.last = math.min(dirty.first, current), math.max(dirty.last, current + 1)
      else
        dirty = { first = current, last = current + 1 }
      end
    end
  end
  -- Preparing an on_win cache does not mean its changed ancestor rows have been drawn.
  view._guide_path, view._guide_dirty = path, dirty
  return path
end

---@param view                          ux.treeview.View
---@return nil
local function redraw_path(view)
  local dirty = view._guide_dirty
  if not dirty or not view:_valid() or view._publishing or view._desynced then
    return
  end
  view._guide_dirty = nil
  local last = math.min(dirty.last, view._header.row_count)
  if dirty.first < last then
    vim.api.nvim__redraw({ win = view.winnr, range = { dirty.first, last } })
  end
end

---@param view                          ux.treeview.View
---@return nil
local function schedule_path(view)
  if not view._guide_dirty or view._guide_redraw_pending then
    return
  end
  view._guide_redraw_pending = true
  vim.schedule(function()
    view._guide_redraw_pending = nil
    redraw_path(view)
  end)
end

---@param view                          ux.treeview.View
---@param row                           integer 0-based cursor row.
---@return nil
function M.cursor_moved(view, row)
  if view._header.mode ~= "tree" then
    return
  end
  local previous = view._guide_path
  if
    not previous
    or previous.layout ~= view._header.layout_revision
    or row < previous.first
    or row >= previous.last
  then
    view:_redraw()
    return
  end
  local ok, path = pcall(prepare_path, view, row, previous.first, previous.last)
  if not ok then
    view._desynced = true
    vim.schedule(function()
      require("ux.treeview.surface").fail(view, path, true)
    end)
    return
  end
  schedule_path(view)
end

---@param view                          ux.treeview.View
---@param row                           integer
---@param col                           integer
---@param text                          string
---@param highlight                     string
---@return nil
local function overlay(view, row, col, text, highlight)
  -- virt_text_hide also hides overlays in Visual selections.
  if col < view._decorations.leftcol then
    return
  end
  vim.api.nvim_buf_set_extmark(view.bufnr, namespace, row, col, {
    ephemeral = true,
    virt_text = { { text, highlight } },
    virt_text_pos = "overlay",
    hl_mode = "combine",
    priority = 120,
  })
end

---@param view                          ux.treeview.View
---@param first                         integer
---@param last                          integer
---@return integer|nil first
---@return integer|nil last
local function decorate(view, first, last)
  local cache = view._decorations
  if not cache or cache.frame ~= view._frame:id() then
    return
  end
  local rows, glyphs = cache.rows, view._glyphs
  local selected_width = vim.fn.strdisplaywidth(glyphs.selected)
  local self_selected_width = vim.fn.strdisplaywidth(glyphs.self_selected)
  local mark_width = math.max(selected_width, self_selected_width)
  local selected = " " .. glyphs.selected .. string.rep(" ", mark_width - selected_width)
  local self_selected = " " .. glyphs.self_selected .. string.rep(" ", mark_width - self_selected_width)
  local unselected = string.rep(" ", mark_width + 1)
  local path = view._guide_path
  local indent = view._context.indent
  local guide_width = vim.fn.strdisplaywidth(glyphs.guide)
  first, last = math.max(first, cache.first), math.min(last, cache.last)
  for row = first, last - 1 do
    local index = row - cache.first + 1
    local depth = rows.depths[index]
    local tree = view._header.mode == "tree"
    local start = (depth + (tree and 1 or 0)) * indent
    local guide_highlight = cache.guide_first
        and row >= cache.guide_first
        and row <= cache.guide_last
        and "TreeviewGuideActive"
      or "TreeviewGuide"
    local path_index = path and row - path.first + 1
    local path_depth = path and path.depths[path_index]
    if tree then
      local guides, chunks = rows.guides[index], {}
      local first_col, next_col
      -- Native guides are deepest-first; append visible cells from left to right, then the connector.
      for at = #guides, 0, -1 do
        local level = at == 0 and depth or guides[at]
        local col = level * indent
        if col >= cache.leftcol and col < cache.rightcol then
          first_col = first_col or col
          if next_col and next_col < col then
            chunks[#chunks + 1] = { string.rep(" ", col - next_col) }
          end
          local on_path = level == path_depth
          local highlight = on_path and "TreeviewGuidePath" or guide_highlight
          if at == 0 then
            local path_turn = on_path and path.connectors[path_index]
            local text = (path_turn or rows.connector_last[index]) and glyphs.last or glyphs.branch
            if on_path and not path_turn then
              -- A cell has one foreground; a straight stem leaves the side branch untinted.
              local split = vim.str_byteindex(text, "utf-32", 1, false)
              chunks[#chunks + 1] = { glyphs.guide, highlight }
              chunks[#chunks + 1] = { text:sub(split + 1), guide_highlight }
            else
              chunks[#chunks + 1] = { text, highlight }
            end
          else
            chunks[#chunks + 1] = { glyphs.guide, highlight }
            next_col = col + guide_width
          end
        end
      end
      if first_col then
        vim.api.nvim_buf_set_extmark(view.bufnr, namespace, row, first_col, {
          ephemeral = true,
          virt_text = chunks,
          virt_text_pos = "overlay",
          hl_mode = "combine",
          priority = 120,
        })
      end
    end
    local icon = rows.icons[index]
    local highlight = rows.highlights[index] or "TreeviewLabel"
    if rows.load_states[index] == "loading" then
      icon = glyphs.loading
    elseif rows.load_states[index] == "error" then
      icon, highlight = glyphs.error, "TreeviewError"
    elseif not icon then
      icon = rows.can_expand[index] and (rows.expanded[index] and glyphs.expanded or glyphs.collapsed) or glyphs.leaf
    end
    if icon and icon ~= "" then
      overlay(view, row, start, icon, highlight)
    end
    vim.api.nvim_buf_set_extmark(view.bufnr, namespace, row, start + view._context.slots, {
      ephemeral = true,
      end_col = start + view._context.slots + #rows.labels[index],
      hl_group = highlight,
      priority = 80,
    })
    for _, match in ipairs(rows.matches[index]) do
      vim.api.nvim_buf_set_extmark(view.bufnr, namespace, row, start + view._context.slots + match[1], {
        ephemeral = true,
        end_col = start + view._context.slots + match[2],
        hl_group = "TreeviewMatch",
        priority = 150,
      })
    end
    local right = {}
    if rows.right_texts[index] then
      right[#right + 1] = { rows.right_texts[index], "TreeviewRightText" }
    end
    right[#right + 1] = rows.marked[index] and { rows.full[index] and selected or self_selected, "TreeviewSelection" }
      or { unselected }
    vim.api.nvim_buf_set_extmark(view.bufnr, namespace, row, 0, {
      ephemeral = true,
      virt_text = right,
      virt_text_pos = "right_align",
      hl_mode = "combine",
      priority = 70,
    })
  end
  return first, last
end

---@param view                          ux.treeview.View
---@return nil
function M.attach(view)
  views[view.bufnr] = view
end

---@param bufnr                         integer
---@return boolean
function M.attached(bufnr)
  return views[bufnr] ~= nil
end

---@param view                          ux.treeview.View
---@return nil
function M.detach(view)
  if views[view.bufnr] == view then
    views[view.bufnr] = nil
  end
end

---@return nil
local function highlights()
  vim.api.nvim_set_hl(0, "TreeviewGuidePath", { fg = "#f5a9b8", default = true })
  for name, link in pairs({
    TreeviewLabel = "Normal",
    TreeviewGuide = "NonText",
    TreeviewGuideActive = "TreeviewGuide",
    TreeviewSelection = "DiagnosticOk",
    TreeviewError = "DiagnosticError",
    TreeviewMatch = "Search",
    TreeviewRightText = "Comment",
  }) do
    vim.api.nvim_set_hl(0, name, { link = link, default = true })
  end
end

highlights()
vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("UxTreeviewHighlights", { clear = true }),
  callback = function()
    highlights()
    for _, view in pairs(views) do
      view._decorations = nil
      view:_redraw()
    end
  end,
})

vim.api.nvim_set_decoration_provider(namespace, {
  on_win = function(_, winnr, bufnr, first, last)
    local view = views[bufnr]
    if not view or view.winnr ~= winnr or view._desynced or view._publishing or not view._frame then
      return false
    end
    first, last = math.max(0, first), math.min(last + 1, view._header.row_count)
    if first >= last then
      return false
    end
    local cache = view._decorations
    if not cache or cache.frame ~= view._frame:id() or cache.first > first or cache.last < last then
      local ok, prepared = pcall(M.prepare, view._frame, first, last, cache)
      if not ok then
        view._desynced = true
        vim.schedule(function()
          require("ux.treeview.surface").fail(view, prepared, true)
        end)
        return false
      end
      view._decorations = prepared
      -- Viewport changes can require annotations and watch hints without a native frame change.
      if view._options.prepare_frame then
        if not view._failed_target then
          view:refresh_decorations()
        end
      else
        vim.schedule(function()
          if not view._closed then
            async.watch(view._state._data)
          end
        end)
      end
    end
    local window = vim.fn.getwininfo(winnr)[1]
    view._decorations.leftcol = window.leftcol
    view._decorations.rightcol = window.leftcol + window.width - window.textoff
    local row = vim.api.nvim_win_get_cursor(winnr)[1] - 1
    local ok, path = pcall(prepare_path, view, row, first, last)
    if not ok then
      view._desynced = true
      vim.schedule(function()
        require("ux.treeview.surface").fail(view, path, true)
      end)
      return false
    end
    local active = vim.api.nvim_get_option_value("cursorline", { win = winnr })
    local guide_first, guide_last = active and row or nil, active and row or nil
    if vim.api.nvim_get_current_win() == winnr then
      local mode = vim.api.nvim_get_mode().mode:sub(1, 1)
      if mode == "v" or mode == "V" or mode == "\022" then
        local anchor = vim.fn.getpos("v")[2] - 1
        guide_first, guide_last = math.min(anchor, row), math.max(anchor, row)
      end
    end
    view._decorations.guide_first, view._decorations.guide_last = guide_first, guide_last
    return true
  end,
  on_range = function(_, winnr, bufnr, first, _, last, end_col)
    local view = views[bufnr]
    if not view or view.winnr ~= winnr or view._desynced or view._publishing then
      return false
    end
    local ok, painted_first, painted_last = pcall(decorate, view, first, last + (end_col > 0 and 1 or 0))
    if not ok then
      view._desynced = true
      vim.schedule(function()
        require("ux.treeview.surface").fail(view, painted_first, true)
      end)
      return false
    end
    local dirty = view._guide_dirty
    if dirty and painted_first and painted_last > painted_first then
      if painted_first <= dirty.first then
        dirty.first = math.max(dirty.first, painted_last)
      end
      if painted_last >= dirty.last then
        dirty.last = math.min(dirty.last, painted_first)
      end
      if dirty.first >= dirty.last then
        view._guide_dirty = nil
      end
    end
  end,
  on_end = function()
    for _, view in pairs(views) do
      if not view._closed and not view._desynced and view._decorations then
        view._resync_attempted = false
        schedule_path(view)
      end
    end
  end,
})

return M
