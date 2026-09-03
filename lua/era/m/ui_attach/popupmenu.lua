---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.ui_attach.popupmenu" ---@type string

local states = require("era.m.ui_attach.state")

local nsnrs = dot.var.nsnr ---@type dot.var.nsnr
local BORDER_HORIZONTAL = 2
local BORDER_VERTICAL = 2
local SHARED_BORDER = 1
local MAX_WIDTH = 80
local MIN_WIDTH = 15
local DOC_DELAY_MS = 200
local DOC_MAX_HEIGHT = 12
local DOC_MAX_WIDTH = 60
local DOC_MIN_WIDTH = 20
local FIELD_HIGHLIGHT_PRIORITY = 100
local MIN_LABEL_WIDTH = 8
local SELECTION_HIGHLIGHT_PRIORITY = 50
local SELECTION_MATCH_PRIORITY = 200
local NATIVE_OWNER = "native"
local native_generation = 0
local render_visible_label_highlights ---@type fun(state: era.m.ui_attach.popupmenu.IState)

---@class era.m.ui_attach.popupmenu
local M = {}

---@param timer                         uv.uv_timer_t|nil
local function close_timer(timer)
  if timer ~= nil and not timer:is_closing() then
    timer:stop()
    timer:close()
  end
end

---@param state                         era.m.ui_attach.popupmenu.IState
local function hide_documentation(state)
  close_timer(state.doc_timer)
  state.doc_timer = nil
  state.doc_generation = (state.doc_generation or 0) + 1

  if state.doc_winnr ~= nil and vim.api.nvim_win_is_valid(state.doc_winnr) then
    vim.api.nvim_win_close(state.doc_winnr, true)
  end
  if state.doc_bufnr ~= nil and vim.api.nvim_buf_is_valid(state.doc_bufnr) then
    vim.api.nvim_buf_delete(state.doc_bufnr, { force = true })
  end
  state.doc_winnr = nil
  state.doc_bufnr = nil
end

---@param item_count                    integer
---@param height                        integer
---@param first_line                    integer 1-indexed
---@return { row: integer, height: integer }|nil
function M._resolve_scrollbar(item_count, height, first_line)
  if height <= 0 or item_count <= height then
    return nil
  end

  local thumb_height = math.max(1, math.floor(height * height / item_count + 0.5) - 1) ---@type integer
  local max_row = height - thumb_height ---@type integer
  local max_first_line = item_count - height + 1 ---@type integer
  local clamped_first_line = math.max(1, math.min(first_line, max_first_line)) ---@type integer
  local progress = (clamped_first_line - 1) / (max_first_line - 1) ---@type number
  local row = math.floor(progress * max_row + 0.5) ---@type integer
  return { row = row, height = thumb_height }
end

---@param state                         era.m.ui_attach.popupmenu.IState
local function hide_scrollbar(state)
  local winnr = state.scrollbar_winnr ---@type integer|nil
  state.scrollbar_winnr = nil
  if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
    vim.api.nvim_win_close(winnr, true)
  end
end

---@param state                         era.m.ui_attach.popupmenu.IState
local function dispose_scrollbar(state)
  hide_scrollbar(state)
  local bufnr = state.scrollbar_bufnr ---@type integer|nil
  state.scrollbar_bufnr = nil
  if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end
end

---@param state                         era.m.ui_attach.popupmenu.IState
---@param redraw?                       boolean
local function update_scrollbar(state, redraw)
  local winnr = state.winnr ---@type integer|nil
  local layout = state.layout
  if winnr == nil or not vim.api.nvim_win_is_valid(winnr) or type(layout) ~= "table" then
    hide_scrollbar(state)
    return
  end

  local geometry = M._resolve_scrollbar(#state.items, layout.height, vim.fn.line("w0", winnr))
  if geometry == nil then
    hide_scrollbar(state)
    return
  end

  local bufnr = state.scrollbar_bufnr ---@type integer|nil
  if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
    bufnr = vim.api.nvim_create_buf(false, true)
    state.scrollbar_bufnr = bufnr
    vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = bufnr })
    vim.api.nvim_set_option_value("buflisted", false, { buf = bufnr })
    vim.api.nvim_set_option_value("buftype", "nofile", { buf = bufnr })
    vim.api.nvim_set_option_value("swapfile", false, { buf = bufnr })
  end

  ---@type vim.api.keyset.win_config
  local wincfg = {
    relative = "win",
    win = winnr,
    width = 1,
    height = geometry.height,
    row = geometry.row,
    col = layout.width,
    zindex = dot.var.zindex.POPUPMENU + 2,
    style = "minimal",
    border = "none",
    focusable = false,
    noautocmd = true,
  }
  local scrollbar_winnr = state.scrollbar_winnr ---@type integer|nil
  if scrollbar_winnr == nil or not vim.api.nvim_win_is_valid(scrollbar_winnr) then
    scrollbar_winnr = vim.api.nvim_open_win(bufnr, false, wincfg)
    state.scrollbar_winnr = scrollbar_winnr
    vim.api.nvim_set_option_value("fillchars", "eob: ", { win = scrollbar_winnr, scope = "local" })
    vim.api.nvim_set_option_value(
      "winhighlight",
      "Normal:PmenuThumb,EndOfBuffer:PmenuThumb",
      { win = scrollbar_winnr, scope = "local" }
    )
  else
    vim.api.nvim_win_set_config(scrollbar_winnr, wincfg)
  end
  if redraw ~= false then
    vim.api.nvim__redraw({ win = scrollbar_winnr, flush = true })
  end
end

---@param state                         era.m.ui_attach.popupmenu.IState
---@return nil
local function render_selection(state)
  local bufnr = state.bufnr ---@type integer|nil
  if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  vim.api.nvim_buf_clear_namespace(bufnr, nsnrs.popupmenu_selected, 0, -1)
  local selected = state.selected ---@type integer
  if selected < 0 or selected >= #state.items then
    return
  end

  local line = vim.api.nvim_buf_get_lines(bufnr, selected, selected + 1, false)[1] or "" ---@type string
  vim.api.nvim_buf_set_extmark(bufnr, nsnrs.popupmenu_selected, selected, 0, {
    end_col = #line,
    hl_group = "PmenuSel",
    hl_mode = "combine",
    priority = SELECTION_HIGHLIGHT_PRIORITY,
  })
  local item = state.items[selected + 1]
  local geometry = state.label_geometry and state.label_geometry[selected + 1] or nil
  local highlights = type(item) == "table" and item[7] or nil
  if geometry ~= nil and type(highlights) == "table" then
    for _, highlight in ipairs(highlights) do
      if highlight[3] == "PmenuMatch" then
        local start_col = math.max(0, highlight[1] or 0) ---@type integer
        local end_col = math.min(geometry.visible_bytes, highlight[2] or 0) ---@type integer
        if end_col > start_col then
          vim.api.nvim_buf_set_extmark(bufnr, nsnrs.popupmenu_selected, selected, geometry.start_col + start_col, {
            end_col = geometry.start_col + end_col,
            hl_group = "PmenuMatchSel",
            hl_mode = "combine",
            priority = SELECTION_MATCH_PRIORITY,
          })
        end
      end
    end
  end
  local winnr = state.winnr ---@type integer|nil
  if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
    vim.api.nvim_win_set_cursor(winnr, { selected + 1, 0 })
  end
end

---@param state                         era.m.ui_attach.popupmenu.IState
local function dispose(state)
  hide_documentation(state)
  dispose_scrollbar(state)
  state.doc_enabled = true
  local winnr = state.winnr ---@type integer|nil
  local bufnr = state.bufnr ---@type integer|nil
  state.winnr = nil
  state.bufnr = nil

  if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
    vim.api.nvim_win_close(winnr, true)
  end
  if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end
end

---@param owner                         string
---@param generation?                   integer
---@return boolean
function M.dismiss(owner, generation)
  local state = states.popupmenu
  if state == nil or state.owner ~= owner or generation ~= nil and state.generation ~= generation then
    return false
  end
  states.popupmenu = nil
  dispose(state)
  return true
end

---@param task                          era.m.ui_attach.ITask
---@return nil
---@diagnostic disable-next-line: unused-local
function M.hide(task)
  M.dismiss(NATIVE_OWNER)
end

---@param menu_layout                   { row: integer, col: integer, width: integer, height: integer, direction?: "n"|"s" }
---@param desired_width                 integer
---@param desired_height                integer
---@param screen_lines                  integer
---@param last_col                      integer
---@return { row: integer, col: integer, width: integer, height: integer }|nil
function M._resolve_documentation_layout(
  menu_layout,
  desired_width,
  desired_height,
  screen_lines,
  last_col,
  first_row,
  first_col
)
  first_row = first_row or 0
  first_col = first_col or 0
  local row = menu_layout.row ---@type integer
  local menu_right = menu_layout.col + menu_layout.width + BORDER_HORIZONTAL - SHARED_BORDER ---@type integer
  local right_capacity = math.max(0, last_col - menu_right - BORDER_HORIZONTAL) ---@type integer
  local left_capacity = math.max(0, menu_layout.col - first_col - BORDER_HORIZONTAL + SHARED_BORDER) ---@type integer
  local direction = menu_layout.direction or "s" ---@type "n"|"s"
  local side_capacity = direction == "n" and menu_layout.height or math.max(0, screen_lines - row - BORDER_VERTICAL) ---@type integer
  local side_height = math.min(desired_height, side_capacity) ---@type integer
  if side_height > 0 then
    if right_capacity >= desired_width then
      return { row = row, col = menu_right, width = desired_width, height = side_height }
    end
    if left_capacity >= desired_width then
      return {
        row = row,
        col = menu_layout.col - desired_width - BORDER_HORIZONTAL + SHARED_BORDER,
        width = desired_width,
        height = side_height,
      }
    end
  end

  local stacked_width = math.min(desired_width, math.max(0, last_col - menu_layout.col - BORDER_HORIZONTAL)) ---@type integer
  if stacked_width >= DOC_MIN_WIDTH then
    if direction == "n" then
      local capacity = math.max(0, menu_layout.row - first_row - BORDER_VERTICAL) ---@type integer
      local height = math.min(desired_height, capacity) ---@type integer
      if height > 0 then
        return {
          row = menu_layout.row - height - BORDER_VERTICAL,
          col = menu_layout.col,
          width = stacked_width,
          height = height,
        }
      end
    else
      local stacked_row = menu_layout.row + menu_layout.height + BORDER_VERTICAL ---@type integer
      local capacity = math.max(0, screen_lines - stacked_row - BORDER_VERTICAL) ---@type integer
      local height = math.min(desired_height, capacity) ---@type integer
      if height > 0 then
        return { row = stacked_row, col = menu_layout.col, width = stacked_width, height = height }
      end
    end
  end

  local capacity = math.max(right_capacity, left_capacity) ---@type integer
  if capacity < DOC_MIN_WIDTH or side_height <= 0 then
    return nil
  end
  local width = math.min(desired_width, capacity) ---@type integer
  local col = right_capacity >= left_capacity and menu_right
    or menu_layout.col - width - BORDER_HORIZONTAL + SHARED_BORDER ---@type integer
  return { row = row, col = col, width = width, height = side_height }
end

---@param state                         era.m.ui_attach.popupmenu.IState
---@return integer first_row
---@return integer last_row
---@return integer first_col
---@return integer last_col
local function window_bounds(state)
  if state.grid == -1 then
    return 0, vim.o.lines, 0, vim.o.columns
  end
  local position = vim.api.nvim_win_get_position(0) ---@type integer[]
  return position[1],
    position[1] + vim.api.nvim_win_get_height(0),
    position[2],
    position[2] + vim.api.nvim_win_get_width(0)
end

---@param text                          string
---@return string[]
---@return integer
---@return integer[]
---@return { row: integer, group: string }[]
function M._format_documentation(text)
  text = text:gsub("\r\n?", "\n")
  local has_preview = vim.startswith(text, dot.var.CMP_DOCUMENTATION_PREVIEW) ---@type boolean
  if has_preview then
    text = text:sub(#dot.var.CMP_DOCUMENTATION_PREVIEW + 1)
  end
  local sections = vim.split(text, dot.var.CMP_DOCUMENTATION_SEPARATOR, { plain = true }) ---@type string[]
  local lines = {} ---@type string[]
  local desired_width = DOC_MIN_WIDTH ---@type integer
  local dividers = {} ---@type integer[]
  local after_divider = false ---@type boolean

  local highlights = {} ---@type { row: integer, group: string }[]
  local function add_divider()
    while lines[#lines] == "" do
      table.remove(lines)
    end
    lines[#lines + 1] = "---"
    dividers[#dividers + 1] = #lines
    highlights[#highlights + 1] = { row = #lines - 1, group = "NonText" }
    after_divider = true
  end

  for section_index, section in ipairs(sections) do
    if section_index > 1 then
      add_divider()
    end
    local preserve = has_preview and section_index == 1 ---@type boolean
    local raw_lines = vim.split(section, "\n", { plain = true }) ---@type string[]
    for _, line in ipairs(raw_lines) do
      if preserve then
        after_divider = false
        lines[#lines + 1] = line
        desired_width = math.max(desired_width, vim.api.nvim_strwidth(line))
        highlights[#highlights + 1] = { row = #lines - 1, group = "Special" }
      elseif not line:match("^%s*```[%w_-]*%s*$") then
        if line:match("^%s*%-%-%-%s*$") then
          add_divider()
        elseif not (after_divider and line == "") then
          after_divider = false
          lines[#lines + 1] = line
          desired_width = math.max(desired_width, vim.api.nvim_strwidth(line))
        else
          after_divider = true
        end
      end
    end
  end
  return lines, math.min(desired_width, DOC_MAX_WIDTH), dividers, highlights
end

---@param bufnr                         integer
---@param highlights                    { row: integer, group: string }[]
local function render_line_highlights(bufnr, highlights)
  for _, highlight in ipairs(highlights) do
    vim.hl.range(bufnr, nsnrs.popupmenu, highlight.group, { highlight.row, 0 }, { highlight.row, -1 }, {
      priority = FIELD_HIGHLIGHT_PRIORITY,
    })
  end
end

---@param state                         era.m.ui_attach.popupmenu.IState
local function render_documentation(state)
  local item = state.items[state.selected + 1]
  local text = item and item[4] or nil ---@type string|nil
  local menu_layout = state.layout
  if type(text) ~= "string" or vim.trim(text) == "" or type(menu_layout) ~= "table" then
    hide_documentation(state)
    return
  end

  local lines, desired_width, dividers, highlights = M._format_documentation(text)
  local first_row, last_row, first_col, last_col = window_bounds(state)
  local layout = M._resolve_documentation_layout(
    menu_layout,
    desired_width,
    math.min(#lines, DOC_MAX_HEIGHT),
    last_row,
    last_col,
    first_row,
    first_col
  )
  if layout == nil then
    hide_documentation(state)
    return
  end
  for _, index in ipairs(dividers) do
    lines[index] = string.rep("─", layout.width)
  end

  local bufnr = state.doc_bufnr ---@type integer|nil
  if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
    bufnr = vim.api.nvim_create_buf(false, true)
    state.doc_bufnr = bufnr
    vim.b[bufnr][dot.var.N_CMP_DOCUMENTATION] = true
    vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = bufnr })
    vim.api.nvim_set_option_value("buflisted", false, { buf = bufnr })
    vim.api.nvim_set_option_value("buftype", "nofile", { buf = bufnr })
    vim.api.nvim_set_option_value("filetype", "markdown", { buf = bufnr })
    vim.api.nvim_set_option_value("swapfile", false, { buf = bufnr })
  end
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_clear_namespace(bufnr, nsnrs.popupmenu, 0, -1)
  render_line_highlights(bufnr, highlights)

  ---@type vim.api.keyset.win_config
  local wincfg = {
    zindex = dot.var.zindex.POPUPMENU,
    relative = "editor",
    width = layout.width,
    height = layout.height,
    row = layout.row,
    col = layout.col,
    style = "minimal",
    border = "rounded",
    focusable = false,
    noautocmd = true,
  }
  local winnr = state.doc_winnr ---@type integer|nil
  if winnr == nil or not vim.api.nvim_win_is_valid(winnr) then
    winnr = vim.api.nvim_open_win(bufnr, false, wincfg)
    state.doc_winnr = winnr
    vim.api.nvim_set_option_value("conceallevel", 2, { win = winnr, scope = "local" })
    vim.api.nvim_set_option_value("cursorline", false, { win = winnr, scope = "local" })
    vim.api.nvim_set_option_value("number", false, { win = winnr, scope = "local" })
    vim.api.nvim_set_option_value("signcolumn", "no", { win = winnr, scope = "local" })
    vim.api.nvim_set_option_value("spell", false, { win = winnr, scope = "local" })
    vim.api.nvim_set_option_value("wrap", true, { win = winnr, scope = "local" })
    vim.api.nvim_set_option_value(
      "winhighlight",
      "Normal:f_up_normal,FloatBorder:f_cmp_border",
      { win = winnr, scope = "local" }
    )
  else
    vim.api.nvim_win_set_buf(winnr, bufnr)
    vim.api.nvim_win_set_config(winnr, wincfg)
  end
end

---@param state                         era.m.ui_attach.popupmenu.IState
local function schedule_documentation(state)
  hide_documentation(state)
  if state.doc_enabled == false or state.selected < 0 or state.selected >= #state.items then
    return
  end
  local item = state.items[state.selected + 1]
  if type(item) ~= "table" or type(item[4]) ~= "string" or vim.trim(item[4]) == "" then
    return
  end

  local generation = assert(state.doc_generation) ---@type integer
  state.doc_timer = vim.defer_fn(function()
    state.doc_timer = nil
    if states.popupmenu == state and state.doc_generation == generation then
      render_documentation(state)
    end
  end, DOC_DELAY_MS)
end

---@param owner                         string
---@param generation                    integer
---@param selected                      integer
---@param redraw?                       boolean
---@return boolean
function M.select_owned(owner, generation, selected, redraw)
  local state = states.popupmenu
  if state == nil or state.owner ~= owner or state.generation ~= generation then
    return false
  end

  state.selected = selected
  render_selection(state)
  render_visible_label_highlights(state)
  update_scrollbar(state, redraw)
  schedule_documentation(state)
  local winnr = state.winnr ---@type integer|nil
  if redraw ~= false and winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
    vim.api.nvim__redraw({ win = winnr, flush = true })
  end
  return true
end

---@param task                          era.m.ui_attach.ITask
---@return nil
function M.select(task)
  local state = states.popupmenu
  if state == nil or state.owner ~= NATIVE_OWNER then
    return
  end
  local selected = unpack(task.args) ---@type integer
  M.select_owned(NATIVE_OWNER, state.generation, selected)
end

---@param owner                         string
---@param generation                    integer
---@param items                         string[][]
---@param selected                      integer
---@param row                           integer
---@param col                           integer
---@param grid                          integer
---@param resolve_highlights            (fun(indices: integer[]): table<integer, era.m.ui_attach.popupmenu.ILabelHighlight[]>)|nil
function M.present(owner, generation, items, selected, row, col, grid, resolve_highlights)
  local state = states.popupmenu
  if state ~= nil and state.owner ~= owner then
    states.popupmenu = nil
    dispose(state)
    state = nil
  elseif state ~= nil and state.generation ~= generation then
    hide_documentation(state)
    state.generation = generation
  end

  if state == nil then
    ---@type era.m.ui_attach.popupmenu.IState
    states.popupmenu = {
      owner = owner,
      generation = generation,
      items = items,
      selected = selected,
      row = row,
      col = col,
      grid = grid,
      bufnr = nil,
      winnr = nil,
      layout = nil,
      doc_bufnr = nil,
      doc_winnr = nil,
      doc_timer = nil,
      doc_generation = 0,
      doc_enabled = true,
      scrollbar_bufnr = nil,
      scrollbar_winnr = nil,
      resolve_highlights = resolve_highlights,
      highlighted_rows = nil,
      label_geometry = nil,
    }
  else
    state.items = items
    state.selected = selected
    state.row = row
    state.col = col
    state.grid = grid
    state.resolve_highlights = resolve_highlights
  end

  M._show(states.popupmenu)
end

---@param task                          era.m.ui_attach.ITask
---@return nil
function M.show(task)
  local items, selected, row, col, grid = unpack(task.args)
  ---@cast items                        string[][]
  ---@cast selected                     integer
  ---@cast row                          integer
  ---@cast col                          integer
  ---@cast grid                         integer
  local state = states.popupmenu
  if state ~= nil and state.owner ~= NATIVE_OWNER then
    return
  end
  local generation = state ~= nil and state.owner == NATIVE_OWNER and state.generation or nil ---@type integer|nil
  if generation == nil then
    native_generation = native_generation + 1
    generation = native_generation
  end
  M.present(NATIVE_OWNER, generation, items, selected, row, col, grid)
end

---@param owner?                        string
---@param generation?                   integer
---@return boolean
function M.visible(owner, generation)
  local state = states.popupmenu
  return state ~= nil
    and (owner == nil or state.owner == owner)
    and (generation == nil or state.generation == generation)
end

---@return boolean
function M.toggle_documentation()
  local state = states.popupmenu
  if state == nil or state.selected < 0 or state.selected >= #state.items then
    return false
  end

  state.doc_enabled = state.doc_enabled == false
  if state.doc_enabled then
    schedule_documentation(state)
  else
    hide_documentation(state)
  end
  return true
end

---@param direction                     -1|1
---@return boolean
function M.scroll_documentation(direction)
  local state = states.popupmenu
  local winnr = state and state.doc_winnr or nil ---@type integer|nil
  if winnr == nil or not vim.api.nvim_win_is_valid(winnr) then
    return false
  end

  local key = direction < 0 and "<C-b>" or "<C-f>" ---@type string
  local ok = pcall(vim.api.nvim_win_call, winnr, function()
    vim.cmd.normal({ args = { vim.keycode(key) }, bang = true })
  end)
  if ok and vim.api.nvim_win_is_valid(winnr) then
    vim.api.nvim__redraw({ win = winnr, flush = true })
  end
  return ok
end

---@param state                         era.m.ui_attach.popupmenu.IState
---@return integer
---@return integer
function M._resolve_position(state)
  local row = math.floor(state.row or 0) ---@type integer
  local col = math.floor(state.col or 0) ---@type integer

  if state.grid == -1 and type(vim.g.ui_cmdline_pos) == "table" then
    local cmd_pos = vim.g.ui_cmdline_pos ---@type integer[]|nil
    if cmd_pos ~= nil and #cmd_pos >= 2 then
      row = cmd_pos[1] - 1
      local cmdline = states.get_active_cmdline()
      local offset = state.col ---@type integer
      if cmdline ~= nil then
        local text = cmdline.first .. cmdline.second ---@type string
        offset = vim.fn.strdisplaywidth(text:sub(1, state.col))
      end
      col = cmd_pos[2] + offset
    end
  end

  return row, col
end

---@param text                          string
---@param width                         integer
---@return string
---@return integer retained source bytes
local function truncate_end(text, width)
  if width <= 0 then
    return "", 0
  end
  if vim.api.nvim_strwidth(text) <= width then
    return text, #text
  end
  if width <= 1 then
    return "…", 0
  end

  local result = "" ---@type string
  local result_width = 0 ---@type integer
  local chars = vim.fn.strchars(text) ---@type integer
  for index = 0, chars - 1 do
    local char = vim.fn.strcharpart(text, index, 1) ---@type string
    local char_width = vim.api.nvim_strwidth(char) ---@type integer
    if result_width + char_width > width - 1 then
      break
    end
    result = result .. char
    result_width = result_width + char_width
  end
  return result .. "…", #result
end

---@param items                         string[][]
---@param width                         integer|nil
---@return string[]
---@return integer
---@return integer
---@return { row: integer, start_col: integer, end_col: integer, group: string, priority: integer? }[]
---@return { start_col: integer, visible_bytes: integer }[]
function M._format_items(items, width)
  local kind_width = 0 ---@type integer
  local label_width = 0 ---@type integer
  local description_width = 0 ---@type integer
  local source_width = 0 ---@type integer
  local minimum_label_width = 0 ---@type integer
  for _, item in ipairs(items) do
    local word, kind, menu, _, description = unpack(item) ---@type string, string, string, string, string
    if type(kind) == "string" then
      kind_width = math.max(kind_width, vim.api.nvim_strwidth(kind))
    end
    if type(word) == "string" then
      local word_width = vim.api.nvim_strwidth(word) ---@type integer
      label_width = math.max(label_width, word_width)
      minimum_label_width = math.max(minimum_label_width, math.min(word_width, MIN_LABEL_WIDTH))
    end
    if type(description) == "string" then
      description_width = math.max(description_width, vim.api.nvim_strwidth(description))
    end
    if type(menu) == "string" then
      source_width = math.max(source_width, vim.api.nvim_strwidth(menu))
    end
  end

  local label_offset = kind_width > 0 and kind_width + 2 or 1 ---@type integer
  local desired_width = label_offset
    + label_width
    + (description_width > 0 and description_width + 1 or 0)
    + (source_width > 0 and source_width + 1 or 0)
    + 1 ---@type integer
  desired_width = math.max(MIN_WIDTH, desired_width)
  desired_width = math.min(desired_width, MAX_WIDTH)

  local target_width = math.min(width or desired_width, MAX_WIDTH) ---@type integer
  local show_kind = kind_width > 0 and target_width >= kind_width + MIN_LABEL_WIDTH + 3 ---@type boolean
  local prefix_width = show_kind and kind_width + 2 or 1 ---@type integer
  local show_source = source_width > 0 and target_width - prefix_width - source_width - 2 >= minimum_label_width ---@type boolean
  if not show_source then
    source_width = 0
  end
  local content_width = math.max(0, target_width - prefix_width - (show_source and source_width + 1 or 0) - 1) ---@type integer
  local full_label_width = label_width ---@type integer
  local available_description_width = content_width - full_label_width - 1 ---@type integer
  local show_description = description_width > 0 and available_description_width >= 3 ---@type boolean
  if show_description then
    label_width = full_label_width
    description_width = math.min(description_width, available_description_width)
  else
    description_width = 0
    label_width = content_width
  end
  local lines = {} ---@type string[]
  local highlights = {} ---@type { row: integer, start_col: integer, end_col: integer, group: string, priority: integer? }[]
  local label_geometry = {} ---@type { start_col: integer, visible_bytes: integer }[]
  for index, item in ipairs(items) do
    local word, kind, menu, _, description, kind_hlgroup, label_highlights, source_hlgroup = unpack(item) ---@type string, string, string, string, string, string, era.m.ui_attach.popupmenu.ILabelHighlight[], string
    word = type(word) == "string" and word or ""
    kind = type(kind) == "string" and kind or ""
    menu = type(menu) == "string" and menu or ""
    description = type(description) == "string" and description or ""
    kind_hlgroup = type(kind_hlgroup) == "string" and kind_hlgroup or "Function"
    source_hlgroup = type(source_hlgroup) == "string" and source_hlgroup or "NonText"

    local line = " " ---@type string
    if show_kind then
      local start_col = #line ---@type integer
      line = line .. stl.string.pad_end(kind, kind_width, " ")
      if kind ~= "" then
        highlights[#highlights + 1] = {
          row = index - 1,
          start_col = start_col,
          end_col = start_col + #kind,
          group = kind_hlgroup,
        }
      end
      line = line .. " "
    end

    local label_start = #line ---@type integer
    local label, label_bytes = truncate_end(word, label_width) ---@type string, integer
    label_geometry[index] = { start_col = label_start, visible_bytes = label_bytes }
    line = line .. stl.string.pad_end(label, label_width, " ")
    if type(label_highlights) == "table" then
      for _, highlight in ipairs(label_highlights) do
        local start_col = math.max(0, highlight[1] or 0) ---@type integer
        local end_col = math.min(label_bytes, highlight[2] or 0) ---@type integer
        if end_col > start_col then
          highlights[#highlights + 1] = {
            row = index - 1,
            start_col = label_start + start_col,
            end_col = label_start + end_col,
            group = highlight[3] or "PmenuMatch",
            priority = highlight[4],
          }
        end
      end
    end

    if show_description then
      line = line .. " "
      local description_start = #line ---@type integer
      local visible_description = truncate_end(description, description_width) ---@type string
      line = line .. stl.string.pad_end(visible_description, description_width, " ")
      if visible_description ~= "" then
        highlights[#highlights + 1] = {
          row = index - 1,
          start_col = description_start,
          end_col = description_start + #visible_description,
          group = "Comment",
        }
      end
    end

    if show_source then
      line = line .. " "
      local source_start = #line ---@type integer
      line = line .. stl.string.pad_end(menu, source_width, " ")
      highlights[#highlights + 1] = {
        row = index - 1,
        start_col = source_start,
        end_col = source_start + #menu,
        group = source_hlgroup,
      }
    end
    line = line .. " "
    lines[index] = stl.string.pad_end(line, target_width, " ")
  end
  return lines, desired_width, label_offset, highlights, label_geometry
end

---@param bufnr                         integer
---@param highlights                    { row: integer, start_col: integer, end_col: integer, group: string, priority: integer? }[]
local function render_item_highlights(bufnr, highlights)
  for _, highlight in ipairs(highlights) do
    vim.api.nvim_buf_set_extmark(bufnr, nsnrs.popupmenu, highlight.row, highlight.start_col, {
      end_col = highlight.end_col,
      hl_group = highlight.group,
      hl_mode = "combine",
      priority = highlight.priority or FIELD_HIGHLIGHT_PRIORITY,
    })
  end
end

---@param bufnr                         integer
---@param row                           integer 0-indexed
---@param geometry                      { start_col: integer, visible_bytes: integer }
---@param highlights                    era.m.ui_attach.popupmenu.ILabelHighlight[]
local function render_label_highlights(bufnr, row, geometry, highlights)
  for _, highlight in ipairs(highlights) do
    local start_col = math.max(0, highlight[1] or 0) ---@type integer
    local end_col = math.min(geometry.visible_bytes, highlight[2] or 0) ---@type integer
    if end_col > start_col then
      vim.api.nvim_buf_set_extmark(bufnr, nsnrs.popupmenu, row, geometry.start_col + start_col, {
        end_col = geometry.start_col + end_col,
        hl_group = highlight[3] or "PmenuMatch",
        hl_mode = "combine",
        priority = highlight[4] or FIELD_HIGHLIGHT_PRIORITY,
      })
    end
  end
end

render_visible_label_highlights = function(state)
  local resolve = state.resolve_highlights
  local geometry = state.label_geometry
  local bufnr = state.bufnr
  local winnr = state.winnr
  if
    resolve == nil
    or geometry == nil
    or bufnr == nil
    or not vim.api.nvim_buf_is_valid(bufnr)
    or winnr == nil
    or not vim.api.nvim_win_is_valid(winnr)
  then
    return
  end

  state.highlighted_rows = state.highlighted_rows or {}
  local first = math.max(1, vim.fn.line("w0", winnr)) ---@type integer
  local last = math.min(#state.items, vim.fn.line("w$", winnr)) ---@type integer
  local indices = {} ---@type integer[]
  for index = first, last do
    if state.highlighted_rows[index] ~= true then
      indices[#indices + 1] = index
    end
  end
  if #indices == 0 then
    return
  end

  local resolved = resolve(indices)
  for _, index in ipairs(indices) do
    state.highlighted_rows[index] = true
    local row_geometry = geometry[index]
    if row_geometry ~= nil then
      render_label_highlights(bufnr, index - 1, row_geometry, resolved[index] or {})
    end
  end
end

---@param anchor_row                    integer
---@param anchor_col                    integer
---@param item_count                    integer
---@param desired_width                 integer
---@param label_offset                  integer
---@param screen_lines                  integer
---@param last_col                      integer
---@param max_height                    integer
---@return { row: integer, col: integer, width: integer, height: integer, direction: "n"|"s" }|nil
function M._resolve_layout(
  anchor_row,
  anchor_col,
  item_count,
  desired_width,
  label_offset,
  screen_lines,
  last_col,
  max_height,
  first_row,
  first_col
)
  first_row = first_row or 0
  first_col = first_col or 0
  local desired_height = math.min(item_count, max_height) ---@type integer
  local south_capacity = math.max(0, screen_lines - anchor_row - 1 - BORDER_VERTICAL) ---@type integer
  local north_capacity = math.max(0, anchor_row - first_row - BORDER_VERTICAL) ---@type integer
  local direction = "s" ---@type "n"|"s"
  if south_capacity < desired_height and north_capacity > south_capacity then
    direction = "n"
  end

  local capacity = direction == "s" and south_capacity or north_capacity ---@type integer
  local height = math.min(desired_height, capacity) ---@type integer
  if height <= 0 then
    return nil
  end

  local horizontal_capacity = last_col - first_col - BORDER_HORIZONTAL ---@type integer
  if horizontal_capacity <= 0 then
    return nil
  end
  local width = math.min(desired_width, horizontal_capacity) ---@type integer
  local max_col = math.max(first_col, last_col - width - BORDER_HORIZONTAL) ---@type integer
  local col = math.max(first_col, math.min(anchor_col - label_offset - 1, max_col)) ---@type integer
  local row = direction == "s" and anchor_row + 1 or anchor_row - height - BORDER_VERTICAL ---@type integer
  return { row = row, col = col, width = width, height = height, direction = direction }
end

---@param selected                      integer
---@param word                          string
---@param text                          string
function M.update_documentation(selected, word, text)
  local state = states.popupmenu
  local item = state and state.items[selected + 1] or nil
  if state == nil or state.selected ~= selected or type(item) ~= "table" or item[1] ~= word or vim.trim(text) == "" then
    return
  end

  item[4] = text
  if state.doc_winnr ~= nil and vim.api.nvim_win_is_valid(state.doc_winnr) then
    render_documentation(state)
  elseif state.doc_timer == nil then
    schedule_documentation(state)
  end
end

---@param owner                         string
---@param generation                    integer
---@param selected                      integer
---@param word                          string
---@param text                          string
function M.update_owned_documentation(owner, generation, selected, word, text)
  local state = states.popupmenu
  if state == nil or state.owner ~= owner or state.generation ~= generation then
    return
  end
  M.update_documentation(selected, word, text)
end

---@param state                         era.m.ui_attach.popupmenu.IState
---@return nil
function M._show(state)
  local lines, desired_width, label_offset, highlights, label_geometry = M._format_items(state.items)
  local anchor_row, anchor_col = M._resolve_position(state)
  local first_row, last_row, first_col, last_col = window_bounds(state)
  local layout = M._resolve_layout(
    anchor_row,
    anchor_col,
    #state.items,
    desired_width,
    label_offset,
    last_row,
    last_col,
    vim.o.pumheight,
    first_row,
    first_col
  )
  if layout == nil then
    M.dismiss(state.owner, state.generation)
    return
  end
  state.layout = layout

  local bufnr = state.bufnr ---@type integer|nil
  if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
    bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
    state.bufnr = bufnr

    vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = bufnr })
    vim.api.nvim_set_option_value("buflisted", false, { buf = bufnr })
    vim.api.nvim_set_option_value("buftype", "nofile", { buf = bufnr })
    vim.api.nvim_set_option_value("filetype", stl.filetype.UX_POPUPMENU, { buf = bufnr })
    vim.api.nvim_set_option_value("swapfile", false, { buf = bufnr })
  end

  if layout.width ~= desired_width then
    local fitted_lines, _fitted_width, _fitted_offset, fitted_highlights, fitted_geometry =
      M._format_items(state.items, layout.width)
    lines = fitted_lines
    highlights = fitted_highlights
    label_geometry = fitted_geometry
  end
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

  ---@type vim.api.keyset.win_config
  local wincfg = {
    zindex = dot.var.zindex.POPUPMENU,
    relative = "editor",
    width = layout.width,
    height = layout.height,
    row = layout.row,
    col = layout.col,
    style = "minimal",
    border = "rounded",
    focusable = false,
  }

  local winnr = state.winnr ---@type integer|nil
  if winnr == nil or not vim.api.nvim_win_is_valid(winnr) then
    wincfg.noautocmd = true
    winnr = vim.api.nvim_open_win(bufnr, false, wincfg)
    state.winnr = winnr

    vim.w[winnr].wintype = stl.e.WinTypeEnum.POPUPMENU
    vim.w[winnr][dot.var.N_WINLINE_DISABLED] = true

    vim.api.nvim_set_option_value("cursorline", false, { win = winnr, scope = "local" })
    vim.api.nvim_set_option_value("list", false, { win = winnr, scope = "local" })
    vim.api.nvim_set_option_value("number", false, { win = winnr, scope = "local" })
    vim.api.nvim_set_option_value("scrolloff", 2, { win = winnr, scope = "local" })
    vim.api.nvim_set_option_value("signcolumn", "no", { win = winnr, scope = "local" })
    vim.api.nvim_set_option_value("spell", false, { win = winnr, scope = "local" })
    vim.api.nvim_set_option_value("wrap", false, { win = winnr, scope = "local" })
    vim.api.nvim_set_option_value(
      "winhighlight",
      "Normal:f_up_normal,FloatBorder:f_cmp_border,CursorLine:f_up_normal",
      { win = winnr, scope = "local" }
    )
  else
    vim.api.nvim_win_set_buf(winnr, bufnr)
    vim.api.nvim_win_set_config(winnr, wincfg)
  end

  vim.api.nvim_buf_clear_namespace(bufnr, nsnrs.popupmenu, 0, -1)
  render_item_highlights(bufnr, highlights)
  state.label_geometry = label_geometry
  state.highlighted_rows = {}
  render_selection(state)
  render_visible_label_highlights(state)
  update_scrollbar(state)
  schedule_documentation(state)

  vim.api.nvim__redraw({ win = winnr, flush = true })
end

return M
