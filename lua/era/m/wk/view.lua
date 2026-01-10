local S = era.m.wk

----------------------------------------------------------------------------------------------------
-- Constants
----------------------------------------------------------------------------------------------------

local WK_ZINDEX = (dot and dot.var and dot.var.zindex and dot.var.zindex.WK) or 9000 ---@type integer

local nsnr = vim.api.nvim_create_namespace("m_wk") ---@type integer

local PADDING_Y = 1
local PADDING_X = 2
local COL_SPACING = 3
local BOTTOM_OFFSET = 1

----------------------------------------------------------------------------------------------------
-- View
----------------------------------------------------------------------------------------------------

---@class era.m.wk.view
local M = {}

---Format pressed keys for footer display
---@param keys                           string
---@return string
local function format_pressed_keys(keys)
  if not keys or keys == "" then
    return ""
  end

  local parts = S.util.parse_keys(keys)
  for i, part in ipairs(parts) do
    local inner = part:match("^<(.*)>$")
    if inner then
      local term = vim.api.nvim_replace_termcodes(part, true, true, true)
      local resolved = vim.fn.keytrans(term)
      if resolved ~= "" then
        part = resolved
      end
    end
    parts[i] = S.util.format_key(part)
  end
  return table.concat(parts)
end

---Build footer line and highlights
---@return string, table[]
local function build_footer()
  local esc_key = S.util.format_key("<Esc>")
  local esc_desc = "close"
  local bs_key = S.util.format_key("<BS>")
  local bs_desc = "back"
  local pressed_keys = format_pressed_keys(S.state.keys)
  local pressed_gap = pressed_keys ~= "" and "  " or ""
  local footer_gap = "    "
  local esc_block = esc_key .. " " .. esc_desc
  local bs_block = bs_key .. " " .. bs_desc
  local footer_content = (pressed_keys ~= "" and (pressed_keys .. pressed_gap) or "")
    .. esc_block
    .. footer_gap
    .. bs_block
  local footer_pad = math.floor((vim.o.columns - vim.fn.strdisplaywidth(footer_content)) / 2)
  local footer = string.rep(" ", footer_pad) .. footer_content

  local cursor = footer_pad
  local footer_hl = {}

  if pressed_keys ~= "" then
    footer_hl[#footer_hl + 1] = { cursor, cursor + #pressed_keys, "m_wk_pressed" }
    cursor = cursor + #pressed_keys + #pressed_gap
  end

  footer_hl[#footer_hl + 1] = { cursor, cursor + #esc_key, "m_wk_key" }
  footer_hl[#footer_hl + 1] = { cursor + #esc_key + 1, cursor + #esc_key + 1 + #esc_desc, "m_wk_separator" }
  cursor = cursor + #esc_key + 1 + #esc_desc + #footer_gap
  footer_hl[#footer_hl + 1] = { cursor, cursor + #bs_key, "m_wk_key" }
  footer_hl[#footer_hl + 1] = { cursor + #bs_key + 1, cursor + #bs_key + 1 + #bs_desc, "m_wk_separator" }

  return footer, footer_hl
end

---Render which-key window
function M.render()
  M.close()

  local nodes = S.state.expand(S.state.get_available())
  if next(nodes) == nil then
    return
  end

  local items = M.__to_items__(nodes)
  if #items == 0 then
    return
  end

  table.sort(items, function(a, b)
    -- 1. Leaf nodes (direct actions) first, groups (sub-menus) later
    if a.is_group ~= b.is_group then
      return not a.is_group
    end
    -- 2. Alphabetical order
    return a.key < b.key
  end)

  local layout = M.__layout__(items)
  local winnr, bufnr = M.__create_win__(layout)
  S.state.winnr = winnr
  S.state.popup_bufnr = bufnr

  M.__draw__(bufnr, layout)
  vim.cmd.redraw()
end

---Close which-key window
function M.close()
  local winnr = S.state.winnr
  local bufnr = S.state.popup_bufnr

  if winnr and vim.api.nvim_win_is_valid(winnr) then
    vim.api.nvim_win_close(winnr, false)
  end

  if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end

  S.state.winnr = nil
  S.state.popup_bufnr = nil
end

----------------------------------------------------------------------------------------------------
-- Protected
----------------------------------------------------------------------------------------------------

---Create floating window
---@param layout                         era.m.wk.ILayout
---@return integer, integer
function M.__create_win__(layout)
  local width = vim.o.columns
  local height = layout.rows + PADDING_Y * 2 + 1
  local row = vim.o.lines - height - vim.o.cmdheight - BOTTOM_OFFSET
  if row < 0 then
    row = 0
  end

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = bufnr })
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = bufnr })
  vim.api.nvim_set_option_value("swapfile", false, { buf = bufnr })

  local winnr = vim.api.nvim_open_win(bufnr, false, {
    relative = "editor",
    row = row,
    col = 0,
    width = width,
    height = height,
    style = "minimal",
    border = "none",
    zindex = WK_ZINDEX,
  })

  vim.api.nvim_set_option_value("winhighlight", "Normal:m_wk_normal", { win = winnr, scope = "local" })

  return winnr, bufnr
end

---Draw content and highlights
---@param bufnr                          integer
---@param layout                         era.m.wk.ILayout
function M.__draw__(bufnr, layout)
  local lines = {}
  local highlights = {}

  local content_width = layout.content_width
  local padding_x = math.max(PADDING_X, math.floor((vim.o.columns - content_width) / 2))

  -- Top padding
  for _ = 1, PADDING_Y do
    lines[#lines + 1] = ""
  end

  for _, row in ipairs(layout.grid) do
    local line = string.rep(" ", padding_x)
    local row_hl = {}

    for col_idx, item in ipairs(row) do
      -- Column spacing (except first column)
      if col_idx > 1 then
        line = line .. string.rep(" ", COL_SPACING)
      end

      -- Calculate column start position for alignment
      local target_col = padding_x + (col_idx - 1) * (layout.col_width + COL_SPACING)
      local current_width = vim.fn.strdisplaywidth(line)
      if current_width < target_col then
        line = line .. string.rep(" ", target_col - current_width)
      end

      -- Key (right-aligned within key_width)
      local key_padding = layout.key_width - vim.fn.strdisplaywidth(item.key)
      if key_padding > 0 then
        line = line .. string.rep(" ", key_padding)
      end
      local key_start = #line
      line = line .. item.key
      local key_end = #line
      row_hl[#row_hl + 1] = { key_start, key_end, "m_wk_key" }

      -- Separator " → "
      local sep_start = #line
      line = line .. " → "
      local sep_end = #line
      row_hl[#row_hl + 1] = { sep_start, sep_end, "m_wk_separator" }

      -- Icon
      if item.icon and item.icon ~= "" then
        local icon_start = #line
        line = line .. item.icon .. " "
        local icon_end = #line - 1
        row_hl[#row_hl + 1] = { icon_start, icon_end, item.icon_hl or "m_wk_key" }
      end

      -- Description
      local desc_start = #line
      line = line .. item.desc
      local desc_end = #line
      row_hl[#row_hl + 1] = { desc_start, desc_end, item.is_group and "m_wk_group" or "m_wk_desc" }
    end

    lines[#lines + 1] = line
    highlights[#lines] = row_hl
  end

  -- Bottom padding
  for _ = 1, PADDING_Y do
    lines[#lines + 1] = ""
  end

  -- Footer (help line)
  local footer, footer_hl = build_footer()
  lines[#lines + 1] = footer
  highlights[#lines] = footer_hl

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })

  for row_idx, row_hl in pairs(highlights) do
    for _, hl in ipairs(row_hl) do
      vim.api.nvim_buf_set_extmark(bufnr, nsnr, row_idx - 1, hl[1], { end_col = hl[2], hl_group = hl[3] })
    end
  end
end

---Calculate multi-column layout
---@param items                          era.m.wk.IViewItem[]
---@return era.m.wk.ILayout
function M.__layout__(items)
  -- Calculate max widths
  local max_key_w = 0
  local max_desc_w = 0
  for _, item in ipairs(items) do
    max_key_w = math.max(max_key_w, vim.fn.strdisplaywidth(item.key))
    local desc_w = vim.fn.strdisplaywidth(item.desc)
    if item.icon then
      desc_w = desc_w + vim.fn.strdisplaywidth(item.icon)
    end
    max_desc_w = math.max(max_desc_w, desc_w)
  end

  -- Column width: key + " → " + icon + desc
  local col_width = max_key_w + 3 + max_desc_w
  local available_width = vim.o.columns - PADDING_X * 2

  -- Calculate number of columns
  local max_cols = math.max(1, math.floor((available_width + COL_SPACING) / (col_width + COL_SPACING)))
  local num_cols = math.min(max_cols, #items)
  local num_rows = math.ceil(#items / num_cols)
  local content_width = num_cols * col_width + (num_cols - 1) * COL_SPACING

  -- Build grid (column-major order)
  local grid = {}
  for r = 1, num_rows do
    grid[r] = {}
  end

  for i, item in ipairs(items) do
    local col = math.floor((i - 1) / num_rows) + 1
    local row = ((i - 1) % num_rows) + 1
    grid[row][col] = item
  end

  return {
    grid = grid,
    rows = num_rows,
    cols = num_cols,
    col_width = col_width,
    key_width = max_key_w,
    content_width = content_width,
  }
end

---Convert nodes to view items
---@param nodes                          table<string, era.m.wk.INode>
---@return era.m.wk.IViewItem[]
function M.__to_items__(nodes)
  local items = {}
  for key, node in pairs(nodes) do
    -- Skip nodes without description (intermediate nodes)
    if node.desc and node.desc ~= "" then
      local icon, icon_hl = nil, nil
      if node.icon then
        icon = node.icon.icon
        icon_hl = node.icon.hl or (node.icon.color and ("m_wk_icon_" .. node.icon.color)) or "m_wk_key"
      end

      items[#items + 1] = {
        key = S.util.format_key(key),
        desc = node.is_group and ("+" .. node.desc) or node.desc,
        icon = icon,
        icon_hl = icon_hl,
        is_group = node.is_group,
      }
    end
  end
  return items
end

return M
