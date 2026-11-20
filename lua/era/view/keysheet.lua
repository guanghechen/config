---@class era.view.keysheet.ISection
---@field public title                  string
---@field public keymaps                ?stl.t.IKeymap[]
---@field public groups                 ?era.view.keysheet.ISection[] Titled groups the section shows instead of keymaps.
---@field public compact                ?boolean Whether descriptions may truncate to give the section more columns.

---@class era.view.keysheet.IProps
---@field public title                  ?string
---@field public sections               era.view.keysheet.ISection[]
---@field public more                   ?era.view.keysheet.ISection[] Sections that `g?` in the sheet shows and hides.

---@class era.view.keysheet.IBufferProps
---@field public bufnr                  integer
---@field public title                  ?string

---@class era.view.keysheet.IState
---@field protected _disposed           boolean
---@field protected _bufnr              integer|nil
---@field protected _winnr              integer|nil
---@field protected _ns                 integer
---@field protected _title              string
---@field protected _sections           era.view.keysheet.ISection[]
---@field protected _more               era.view.keysheet.ISection[]
---@field protected _expanded           boolean

---@class era.view.keysheet.IItem
---@field public key                    string
---@field public modes                  string
---@field public desc                   string

---A slot of a column: an item, a group title, or neither for the space between groups.
---@class era.view.keysheet.ICell
---@field public item                   ?era.view.keysheet.IItem
---@field public title                  ?string

---@class era.view.Keysheet : era.view.keysheet.IState
local M = {}
M.__index = M

local COLUMN_GAP = 4 ---@type integer
local PADDING_LEFT = 2 ---@type integer
local PADDING_RIGHT = 2 ---@type integer
-- A compact section shows descriptions whole up to DESC_MAX_WIDTH; taller than the sheet, it truncates them down to
-- DESC_MIN_WIDTH to take more columns.
local DESC_MIN_WIDTH = 24 ---@type integer
local DESC_MAX_WIDTH = 48 ---@type integer
local OTHER_GROUP = "other" ---@type string

---Leaves out the scopes that name where a mapping comes from: the title, an unspaced scope such as "picker#result: " or
---"era.fn.find_files: ", and the "Treeview" of inherited tree keys.
---@param desc                          string
---@param title                         string|nil
---@return string
local function unscoped(desc, title)
  local scope = title and "^" .. vim.pesc(title) .. ":%s+" ---@type string|nil
  local previous ---@type string|nil
  while desc ~= previous do
    previous = desc
    desc = desc:gsub("^Treeview:?%s+", ""):gsub("^[%w%.#_%-%(%)]+:%s+", "")
    if scope then
      desc = desc:gsub(scope, "")
    end
  end
  return desc
end

---Whether a mapping with the unscoped description `desc` belongs on a sheet; which-key prefixes and the no-ops that only
---block a fallback do not.
---@param desc                          string
---@return boolean
local function listed(desc)
  return desc ~= "" and desc ~= "wk-trigger" and desc ~= "noop"
end

---Lists `mapping` of `mode` under `desc` in `keymaps`, or adds its mode to the entry of the same key and description.
---@param keymaps                       stl.t.IKeymap[]
---@param entries                       table<string, stl.t.IKeymap>
---@param mode                          string
---@param mapping                       vim.api.keyset.get_keymap
---@param desc                          string
---@return nil
local function add(keymaps, entries, mode, mapping, desc)
  -- The raw keys keep <C-j> and <C-i> apart from <NL> and <Tab>, which they are mapped apart from.
  local key = vim.fn.keytrans(mapping.lhsraw) ---@type string
  local id = key .. "\0" .. desc ---@type string
  local entry = entries[id]
  if entry then
    entry.modes[#entry.modes + 1] = mode
  else
    entry = { modes = { mode }, key = key, desc = desc, callback = mapping.callback or mapping.rhs or "" }
    entries[id] = entry
    keymaps[#keymaps + 1] = entry
  end
end

---The number a key or a description ends with, and what comes before it.
---@param text                          string
---@return string|nil prefix
---@return integer|nil number
local function numbered(text)
  local prefix, digits = text:match("^(.-)(%d+)$") ---@type string|nil, string|nil
  return prefix, digits and tonumber(digits)
end

---Collapses each run of three or more sorted entries that differ only in a number ending both their key and description,
---such as `<Space>b10` to `<Space>b49` focusing buffers 10 to 49, into one entry for the range.
---@param keymaps                       stl.t.IKeymap[]
---@return stl.t.IKeymap[]
local function collapsed(keymaps)
  local result = {} ---@type stl.t.IKeymap[]
  local index = 1 ---@type integer
  while index <= #keymaps do
    local first = keymaps[index] ---@type stl.t.IKeymap
    local key_prefix, number = numbered(first.key)
    local desc_prefix, desc_number = numbered(first.desc)
    local last = index ---@type integer
    if key_prefix and desc_prefix and number == desc_number then
      local modes = table.concat(first.modes, ",") ---@type string
      while keymaps[last + 1] do
        local entry = keymaps[last + 1] ---@type stl.t.IKeymap
        local next_key_prefix, next_number = numbered(entry.key)
        local next_desc_prefix, next_desc_number = numbered(entry.desc)
        if
          next_key_prefix ~= key_prefix
          or next_desc_prefix ~= desc_prefix
          or next_number ~= number + last + 1 - index
          or next_desc_number ~= next_number
          or table.concat(entry.modes, ",") ~= modes
        then
          break
        end
        last = last + 1
      end
    end
    if last - index >= 2 then
      local final = keymaps[last] ---@type stl.t.IKeymap
      result[#result + 1] = vim.tbl_extend("force", first, {
        key = first.key .. "…" .. final.key:match("%d+$"),
        desc = first.desc .. "…" .. final.desc:match("%d+$"),
      })
    else
      last = index
      result[#result + 1] = first
    end
    index = last + 1
  end
  return result
end

---@param keymaps                       stl.t.IKeymap[]
---@return stl.t.IKeymap[]
local function sorted(keymaps)
  table.sort(keymaps, function(left, right)
    return left.key < right.key or left.key == right.key and table.concat(left.modes) < table.concat(right.modes)
  end)
  return keymaps
end

---Groups entries by the scope their descriptions start with, which names the group in place of the descriptions; the
---entries without one go to a last group.
---@param keymaps                       stl.t.IKeymap[]
---@return era.view.keysheet.ISection[]
local function grouped(keymaps)
  local groups = {} ---@type table<string, stl.t.IKeymap[]>
  for _, entry in ipairs(keymaps) do
    local scope, desc = entry.desc:match("^([%w%.#_%-%(%)]+):%s+(.+)$") ---@type string|nil, string|nil
    local title = scope or OTHER_GROUP ---@type string
    entry.desc = desc or entry.desc
    groups[title] = groups[title] or {}
    table.insert(groups[title], entry)
  end
  local titles = vim.tbl_keys(groups) ---@type string[]
  table.sort(titles, function(left, right)
    return left ~= OTHER_GROUP and (right == OTHER_GROUP or left < right)
  end)
  local result = {} ---@type era.view.keysheet.ISection[]
  for _, title in ipairs(titles) do
    result[#result + 1] = { title = title, keymaps = collapsed(sorted(groups[title])) }
  end
  return result
end

---Whether the mappings of a buffer keep the global mapping of the raw keys `lhs` from taking effect: one maps the same
---keys, or a nowait one maps a start of them.
---@param own                           table<string, boolean> Whether each mapping of the buffer is nowait, by its raw keys.
---@param lhs                           string
---@return boolean
local function shadowed(own, lhs)
  for own_lhs, nowait in pairs(own) do
    if own_lhs == lhs or nowait and vim.startswith(lhs, own_lhs) then
      return true
    end
  end
  return false
end

---@param text                          string
---@param width                         integer
---@return string
local function truncated(text, width)
  if vim.api.nvim_strwidth(text) <= width then
    return text
  end
  local chars = vim.fn.strchars(text) ---@type integer
  local kept = text ---@type string
  while vim.api.nvim_strwidth(kept) > width - 1 do
    chars = chars - 1
    kept = vim.fn.strcharpart(text, 0, chars)
  end
  return kept .. "…"
end

---@param props                         era.view.keysheet.IProps
---@return era.view.Keysheet
function M.new(props)
  local self = setmetatable({}, M)
  self._disposed = false
  self._bufnr = nil
  self._winnr = nil
  self._ns = vim.api.nvim_create_namespace("board_keysheet")
  self._title = props.title or "Keymap Help"
  self._sections = props.sections
  self._more = props.more or {}
  self._expanded = false
  return self
end

---Keysheet of the mappings `bufnr` takes in Normal and Visual mode: its own, without the scopes their descriptions start
---with, and on `g?` in the sheet the global ones it leaves in effect, grouped by those scopes with their numbered runs
---collapsed. Neither lists which-key prefixes, which go on to the global mappings, or the no-ops that only block a
---fallback.
---@param props                         era.view.keysheet.IBufferProps
---@return era.view.Keysheet
function M.for_buffer(props)
  local pane, global = {}, {} ---@type stl.t.IKeymap[], stl.t.IKeymap[]
  local pane_entries, global_entries = {}, {} ---@type table<string, stl.t.IKeymap>, table<string, stl.t.IKeymap>
  for _, mode in ipairs({ "n", "x" }) do
    local own = {} ---@type table<string, boolean>
    for _, mapping in ipairs(vim.api.nvim_buf_get_keymap(props.bufnr, mode)) do
      if mapping.desc ~= "wk-trigger" then
        own[mapping.lhsraw] = mapping.nowait == true or mapping.nowait == 1
      end
      local desc = unscoped(mapping.desc or "", props.title) ---@type string
      if listed(desc) then
        add(pane, pane_entries, mode, mapping, desc)
      end
    end
    for _, mapping in ipairs(vim.api.nvim_get_keymap(mode)) do
      local desc = mapping.desc or "" ---@type string
      if listed(unscoped(desc)) and not shadowed(own, mapping.lhsraw) then
        add(global, global_entries, mode, mapping, desc)
      end
    end
  end
  return M.new({
    title = props.title,
    sections = { { title = "Current pane", keymaps = sorted(pane) } },
    more = { { title = "Global", groups = grouped(global), compact = true } },
  })
end

---@return nil
function M:dispose()
  if self._disposed then
    return
  end
  self._disposed = true
  self:close()
end

---@return boolean
function M:isdisposed()
  return self._disposed
end

---@return boolean
function M:isvisible()
  return self._winnr ~= nil and vim.api.nvim_win_is_valid(self._winnr)
end

---@return nil
function M:close()
  local winnr = self._winnr ---@type integer|nil
  local bufnr = self._bufnr ---@type integer|nil

  self._winnr = nil
  self._bufnr = nil

  if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
    pcall(vim.api.nvim_win_close, winnr, true)
  end

  if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
    pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
  end
end

---@return nil
function M:open()
  if self._disposed then
    return
  end

  if self:isvisible() then
    return
  end

  self:close()

  local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  self._bufnr = bufnr

  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = bufnr })
  vim.api.nvim_set_option_value("buflisted", false, { buf = bufnr })
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = bufnr })
  vim.api.nvim_set_option_value("filetype", "board", { buf = bufnr })
  vim.api.nvim_set_option_value("swapfile", false, { buf = bufnr })

  -- A read-only pane keeps the Insert mode a focus move brought in; the sheet takes its keys in Normal mode.
  if vim.api.nvim_get_mode().mode:match("^[iR]") then
    vim.cmd("stopinsert")
  end
  local winnr = vim.api.nvim_open_win(bufnr, true, {
    zindex = dot.win.resolve_zindex(),
    relative = "editor",
    row = 1,
    col = 1,
    width = vim.o.columns - 2,
    height = vim.o.lines - 4,
    border = "rounded",
    style = "minimal",
    focusable = true,
    title = string.format(" %s %s ", stl.icon.ui.Keyboard, self._title),
    title_pos = "center",
  })
  self._winnr = winnr

  vim.api.nvim_set_option_value("cursorline", true, { win = winnr, scope = "local" })
  vim.api.nvim_set_option_value("number", false, { win = winnr, scope = "local" })
  vim.api.nvim_set_option_value("relativenumber", false, { win = winnr, scope = "local" })
  vim.api.nvim_set_option_value("signcolumn", "no", { win = winnr, scope = "local" })
  vim.api.nvim_set_option_value("spell", false, { win = winnr, scope = "local" })
  vim.api.nvim_set_option_value("winblend", 0, { win = winnr, scope = "local" })
  vim.api.nvim_set_option_value("winfixbuf", true, { win = winnr, scope = "local" })
  vim.api.nvim_set_option_value("wrap", false, { win = winnr, scope = "local" })
  vim.api.nvim_set_option_value(
    "winhighlight",
    table.concat({
      "CursorLine:m_bk_cursorline",
      "FloatBorder:ms_b_bg0",
      "FloatFooter:ms_b_bg0",
      "FloatTitle:ms_b_bg0",
      "Normal:m_bk_normal",
    }, ","),
    { win = winnr, scope = "local" }
  )

  self:__draw__()
  self:__setup_keymaps__(bufnr)
end

---Shows the sections on demand, or hides them again.
---@return nil
function M:toggle_more()
  if #self._more == 0 or not self:isvisible() then
    return
  end
  self._expanded = not self._expanded
  self:__draw__()
end

---@return nil
function M:toggle()
  if self:isvisible() then
    self:close()
  else
    self:open()
  end
end

----------------------------------------------------------------------------------------------------

---The cells of `section` in reading order: its items, or the title and items of each group with a blank cell between
---groups.
---@param section                       era.view.keysheet.ISection
---@return era.view.keysheet.ICell[]
local function cells_of(section)
  local cells = {} ---@type era.view.keysheet.ICell[]
  for _, group in ipairs(section.groups or { section }) do
    if section.groups then
      if #cells > 0 then
        cells[#cells + 1] = {}
      end
      cells[#cells + 1] = { title = group.title }
    end
    for _, km in ipairs(group.keymaps or {}) do
      if not km.disabled then
        cells[#cells + 1] = { item = { key = km.key, modes = table.concat(km.modes, ","), desc = km.desc or "" } }
      end
    end
  end
  return cells
end

---Fills columns of `rows` slots with `cells` in reading order. A group title goes to the next column rather than end
---one, and the next group follows a blank cell in the same column or starts the next one.
---@param cells                         era.view.keysheet.ICell[]
---@param rows                          integer
---@return era.view.keysheet.ICell[][]
local function flow(cells, rows)
  local columns = { {} } ---@type era.view.keysheet.ICell[][]
  for _, cell in ipairs(cells) do
    local column = columns[#columns] ---@type era.view.keysheet.ICell[]
    if cell.item or cell.title then
      if #column > 0 and #column + (cell.title and 2 or 1) > rows then
        column = {}
        columns[#columns + 1] = column
      end
      column[#column + 1] = cell
    elseif #column > 0 then
      if #column + 3 <= rows then
        column[#column + 1] = cell
      else
        columns[#columns + 1] = {}
      end
    end
  end
  return columns
end

---@class era.view.keysheet.IColumnWidths
---@field public key                    integer
---@field public modes                  integer
---@field public desc                   integer The widest description of the column.
---@field public title                  integer

---Flows `cells` into at most `count` columns and measures each column.
---@param cells                         era.view.keysheet.ICell[]
---@param count                         integer
---@param capped                        boolean Whether descriptions count up to DESC_MAX_WIDTH.
---@return era.view.keysheet.ICell[][] columns
---@return integer rows
---@return era.view.keysheet.IColumnWidths[] widths
local function arrange(cells, count, capped)
  local strwidth = vim.api.nvim_strwidth ---@type fun(str: string): integer
  local filled, titled = 0, false ---@type integer, boolean
  for _, cell in ipairs(cells) do
    filled = filled + ((cell.item or cell.title) and 1 or 0)
    titled = titled or cell.title ~= nil
  end
  -- A title keeps its first item under it.
  local rows = math.max(titled and 2 or 1, math.ceil(filled / count)) ---@type integer
  local columns = flow(cells, rows) ---@type era.view.keysheet.ICell[][]
  while #columns > count do
    rows = rows + 1
    columns = flow(cells, rows)
  end

  local widths = {} ---@type era.view.keysheet.IColumnWidths[]
  for index, column in ipairs(columns) do
    local width = { key = 0, modes = 0, desc = 0, title = 0 } ---@type era.view.keysheet.IColumnWidths
    for _, cell in ipairs(column) do
      if cell.item then
        local desc = strwidth(cell.item.desc) ---@type integer
        width.key = math.max(width.key, strwidth(cell.item.key))
        width.modes = math.max(width.modes, strwidth(cell.item.modes))
        width.desc = math.max(width.desc, capped and math.min(desc, DESC_MAX_WIDTH) or desc)
      elseif cell.title then
        width.title = math.max(width.title, strwidth(cell.title))
      end
    end
    widths[index] = width
  end
  return columns, rows, widths
end

---The width of the columns of `widths` side by side, descriptions truncated to `cap`.
---@param widths                        era.view.keysheet.IColumnWidths[]
---@param cap                           number
---@return number
local function total(widths, cap)
  local sum = COLUMN_GAP * (#widths - 1) ---@type number
  for _, width in ipairs(widths) do
    sum = sum + math.max(width.key + 2 + width.modes + 2 + math.min(width.desc, cap), width.title)
  end
  return sum
end

---Lays `cells` out in the most columns that fit `content_width`, each as wide as its own cells. Descriptions stay whole
---unless `floor` lets them truncate, from DESC_MAX_WIDTH down to it, to fit; one column of them truncates to what fits.
---@param cells                         era.view.keysheet.ICell[]
---@param content_width                 integer
---@param floor                         integer|nil
---@return era.view.keysheet.ICell[][] columns
---@return integer rows
---@return era.view.keysheet.IColumnWidths[] widths
---@return number cap The width descriptions truncate to.
local function fit(cells, content_width, floor)
  local most = math.max(1, math.floor((content_width + COLUMN_GAP) / (8 + COLUMN_GAP))) ---@type integer
  for count = math.min(#cells, most), 2, -1 do
    local columns, rows, widths = arrange(cells, count, floor ~= nil)
    if floor == nil then
      if total(widths, math.huge) <= content_width then
        return columns, rows, widths, math.huge
      end
    else
      for cap = DESC_MAX_WIDTH, floor, -1 do
        if total(widths, cap) <= content_width then
          return columns, rows, widths, cap
        end
      end
    end
  end
  local columns, rows, widths = arrange(cells, 1, floor ~= nil)
  local cap = floor and DESC_MAX_WIDTH or math.huge ---@type number
  while floor and cap > 1 and total(widths, cap) > content_width do
    cap = cap - 1
  end
  return columns, rows, widths, cap
end

---Lays `cells` out with whole descriptions; a compact section taller than `height` truncates them for more columns.
---@param cells                         era.view.keysheet.ICell[]
---@param content_width                 integer
---@param height                        integer
---@param compact                       boolean
---@return era.view.keysheet.ICell[][] columns
---@return integer rows
---@return era.view.keysheet.IColumnWidths[] widths
---@return number cap
local function layout(cells, content_width, height, compact)
  if not compact then
    return fit(cells, content_width, nil)
  end
  local columns, rows, widths, cap = fit(cells, content_width, DESC_MAX_WIDTH)
  if rows > height then
    return fit(cells, content_width, DESC_MIN_WIDTH)
  end
  return columns, rows, widths, cap
end

---Appends `section` under its title, its cells flowing down the columns `available_width` holds.
---@param section                       era.view.keysheet.ISection
---@param available_width               integer
---@param available_height              integer
---@param lines                         string[]
---@param highlights                    stl.t.IHighlight[]
---@return nil
local function render_section(section, available_width, available_height, lines, highlights)
  local strwidth = vim.api.nvim_strwidth ---@type fun(str: string): integer
  local cells = cells_of(section) ---@type era.view.keysheet.ICell[]
  if #cells == 0 then
    return
  end
  local content_width = available_width - PADDING_LEFT - PADDING_RIGHT ---@type integer
  local columns, rows, widths, cap = layout(cells, content_width, available_height - 2, section.compact == true)

  highlights[#highlights + 1] = {
    lnum = #lines,
    coll = PADDING_LEFT,
    colr = PADDING_LEFT + #section.title,
    hlname = "m_bk_title",
  }
  lines[#lines + 1] = string.rep(" ", PADDING_LEFT) .. section.title

  for row = 1, rows do
    local lnum = #lines ---@type integer
    local text = string.rep(" ", PADDING_LEFT) ---@type string
    ---@param value                     string
    ---@param width                     integer
    ---@param hlname                    string|nil
    ---@return nil
    local function put(value, width, hlname)
      if hlname then
        highlights[#highlights + 1] = { lnum = lnum, coll = #text, colr = #text + #value, hlname = hlname }
      end
      text = text .. value .. string.rep(" ", width - strwidth(value))
    end
    for index, column in ipairs(columns) do
      if index > 1 then
        text = text .. string.rep(" ", COLUMN_GAP)
      end
      local width = widths[index] ---@type era.view.keysheet.IColumnWidths
      local desc_width = math.min(width.desc, cap) ---@type integer
      local cell_width = math.max(width.key + 2 + width.modes + 2 + desc_width, width.title) ---@type integer
      local cell = column[row] ---@type era.view.keysheet.ICell|nil
      if cell and cell.item then
        put(cell.item.key, width.key + 2, "m_bk_key")
        put(cell.item.modes, width.modes + 2, "m_bk_mode")
        put(truncated(cell.item.desc, desc_width), cell_width - width.key - width.modes - 4, "m_bk_desc")
      elseif cell and cell.title then
        put(cell.title, cell_width, "m_bk_title")
      else
        put("", cell_width, nil)
      end
    end
    lines[#lines + 1] = (text:gsub("%s+$", ""))
  end

  lines[#lines + 1] = ""
end

---Draws the sections the sheet shows into its window, and names in the footer what `g?` turns to.
---@protected
---@return nil
function M:__draw__()
  local bufnr, winnr = assert(self._bufnr), assert(self._winnr) ---@type integer, integer
  local width, height = vim.api.nvim_win_get_width(winnr), vim.api.nvim_win_get_height(winnr) ---@type integer, integer
  local lines, highlights = self:__render__(width, height) ---@type string[], stl.t.IHighlight[]
  vim.api.nvim_set_option_value("readonly", false, { buf = bufnr })
  vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })
  vim.api.nvim_set_option_value("readonly", true, { buf = bufnr })
  vim.api.nvim_buf_clear_namespace(bufnr, self._ns, 0, -1)
  for _, hl in ipairs(highlights) do
    vim.hl.range(bufnr, self._ns, hl.hlname, { hl.lnum, hl.coll }, { hl.lnum, hl.colr })
  end
  vim.api.nvim_win_set_cursor(winnr, { 1, 0 })
  if #self._more > 0 then
    local footer = self._expanded and " g? current pane " or " g? all keys " ---@type string
    vim.api.nvim_win_set_config(winnr, { footer = footer, footer_pos = "center" })
  end
end

---@protected
---@param available_width               integer
---@param available_height              integer
---@return string[]
---@return stl.t.IHighlight[]
function M:__render__(available_width, available_height)
  local lines = { "" } ---@type string[]
  local highlights = {} ---@type stl.t.IHighlight[]
  local sections = self._expanded and vim.list_extend(vim.list_slice(self._sections), self._more) or self._sections
  for _, section in ipairs(sections) do
    render_section(section, available_width, available_height, lines, highlights)
  end
  return lines, highlights
end

---@protected
---@param bufnr                         integer
---@return nil
function M:__setup_keymaps__(bufnr)
  -- stylua: ignore
  ---@type stl.t.IKeymap[]
  local keymaps = {
    { modes = { "n" }, key = "q", callback = function() self:close() end, desc = "keysheet: close" },
    { modes = { "n" }, key = "<Esc>", callback = function() self:close() end, desc = "keysheet: close" },
    { modes = { "n" }, key = "g?", callback = function() self:toggle_more() end, desc = "keysheet: all keys or current pane" },
  }
  stl.nvim.fn.bindkeys(keymaps, { bufnr = bufnr, noremap = true, silent = true })
end

return M
