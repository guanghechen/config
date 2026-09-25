---@diagnostic disable-next-line: unused-local
local __module_name__ = "ux.treeview.decorations" ---@type string

local namespace = vim.api.nvim_create_namespace("ux.treeview")
local views = {} ---@type table<integer, ux.treeview.View>
local M = {}

---@param frame                         yoz.ux.treeview.Frame
---@param first                         integer
---@param last                          integer
---@return table
function M.prepare(frame, first, last)
  return { frame = frame:id(), first = first, last = last, rows = frame:rows(first + 1, last) }
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
---@return nil
local function decorate(view, first, last)
  local cache = view._decorations
  if not cache or cache.frame ~= view._frame:id() then
    return
  end
  local rows, glyphs = cache.rows, view._glyphs
  for row = math.max(first, cache.first), math.min(last - 1, cache.last - 1) do
    local index = row - cache.first + 1
    local depth = rows.depths[index]
    local tree = view._header.mode == "tree"
    local start = (depth + (tree and 1 or 0)) * view._context.indent
    local guide_highlight = cache.guide_first
        and row >= cache.guide_first
        and row <= cache.guide_last
        and "TreeviewGuideActive"
      or "TreeviewGuide"
    if tree then
      overlay(
        view,
        row,
        start - view._context.indent,
        rows.connector_last[index] and glyphs.last or glyphs.branch,
        guide_highlight
      )
    end
    for _, guide in ipairs(rows.guides[index]) do
      overlay(view, row, guide * view._context.indent, glyphs.guide, guide_highlight)
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
    right[#right + 1] = rows.marked[index]
        and { " " .. (rows.full[index] and glyphs.selected or glyphs.self_selected), "TreeviewSelection" }
      or { "  " }
    vim.api.nvim_buf_set_extmark(view.bufnr, namespace, row, 0, {
      ephemeral = true,
      virt_text = right,
      virt_text_pos = "right_align",
      hl_mode = "combine",
      priority = 70,
    })
  end
end

---@param view                          ux.treeview.View
---@return nil
function M.attach(view)
  views[view.bufnr] = view
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
      local ok, prepared = pcall(M.prepare, view._frame, first, last)
      if not ok then
        view._desynced = true
        vim.schedule(function()
          require("ux.treeview.surface").fail(view, prepared, true)
        end)
        return false
      end
      view._decorations = prepared
    end
    view._decorations.leftcol = vim.fn.getwininfo(winnr)[1].leftcol
    local row = vim.api.nvim_win_get_cursor(winnr)[1] - 1
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
    local ok, error = pcall(decorate, view, first, last + (end_col > 0 and 1 or 0))
    if not ok then
      view._desynced = true
      vim.schedule(function()
        require("ux.treeview.surface").fail(view, error, true)
      end)
      return false
    end
  end,
  on_end = function()
    for _, view in pairs(views) do
      if not view._desynced and view._decorations then
        view._resync_attempted = false
      end
    end
  end,
})

return M
