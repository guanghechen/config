local __module_name__ = "dot.module.board.keysheet" ---@type string

---@class dot.module.board.keysheet.IProps
---@field public title                  ?string
---@field public keymaps                ark.t.IKeymap[]

---@class dot.module.board.keysheet.IState
---@field protected _disposed           boolean
---@field protected _bufnr              integer|nil
---@field protected _winnr              integer|nil
---@field protected _ns                 integer
---@field protected _title              string
---@field protected _keymaps            ark.t.IKeymap[]

---@class dot.module.board.Keysheet : dot.module.board.keysheet.IState
local M = {}
M.__index = M

local COLUMN_GAP = 4 ---@type integer
local PADDING_LEFT = 2 ---@type integer
local PADDING_RIGHT = 2 ---@type integer

---@param props                         dot.module.board.keysheet.IProps
---@return dot.module.board.Keysheet
function M.new(props)
  local self = setmetatable({}, M)
  self._disposed = false
  self._bufnr = nil
  self._winnr = nil
  self._ns = vim.api.nvim_create_namespace("board_keysheet")
  self._title = props.title or "Keymap Help"
  self._keymaps = props.keymaps
  return self
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

  vim.b[bufnr].miniindentscope_disable = true
  vim.b[bufnr].miniai_disable = true
  vim.b[bufnr].minihipatterns_disable = true
  vim.bo[bufnr].bufhidden = "wipe"
  vim.bo[bufnr].buflisted = false
  vim.bo[bufnr].buftype = "nofile"
  vim.bo[bufnr].filetype = "board"
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].modifiable = true

  local width = vim.o.columns - 2 ---@type integer
  local height = vim.o.lines - 4 ---@type integer
  local lines, highlights = self:__render__(width) ---@type string[], ark.t.IHighlight[]
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].readonly = true

  for _, hl in ipairs(highlights) do
    vim.hl.range(bufnr, self._ns, hl.hlname, { hl.lnum, hl.coll }, { hl.lnum, hl.colr })
  end

  local winblend = dot.context.theme.get_float_winblend() ---@type integer
  local winnr = vim.api.nvim_open_win(bufnr, true, {
    relative = "editor",
    row = 1,
    col = 1,
    width = width,
    height = height,
    border = "rounded",
    style = "minimal",
    focusable = true,
    title = string.format(" %s %s ", dot.icon.ui.Keyboard, self._title),
    title_pos = "center",
  })
  self._winnr = winnr

  vim.wo[winnr].cursorline = true
  vim.wo[winnr].number = false
  vim.wo[winnr].relativenumber = false
  vim.wo[winnr].signcolumn = "no"
  vim.wo[winnr].spell = false
  vim.wo[winnr].winblend = winblend
  vim.wo[winnr].winfixbuf = true
  vim.wo[winnr].wrap = false
  vim.wo[winnr].winhighlight = table.concat({
    "CursorLine:fb_keysheet_cursorline",
    "FloatBorder:ms_b_bg0",
    "FloatTitle:ms_b_bg0",
    "Normal:fb_keysheet_normal",
  }, ",")

  self:__setup_keymaps__(bufnr)
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

---@protected
---@param available_width               integer
---@return string[]
---@return ark.t.IHighlight[]
function M:__render__(available_width)
  local strwidth = vim.api.nvim_strwidth ---@type fun(str: string): integer
  local keymaps = self._keymaps ---@type ark.t.IKeymap[]

  local key_width = 0 ---@type integer
  local mode_width = 0 ---@type integer
  local desc_width = 0 ---@type integer

  ---@class dot.module.board.keysheet.IItem
  ---@field public key                    string
  ---@field public modes                  string
  ---@field public desc                   string

  ---@type dot.module.board.keysheet.IItem[]
  local items = {}
  for _, km in ipairs(keymaps) do
    if km.disabled then
      goto continue
    end

    local key = km.key ---@type string
    local modes = table.concat(km.modes, ",") ---@type string
    local desc = km.desc or "" ---@type string

    key_width = math.max(key_width, strwidth(key))
    mode_width = math.max(mode_width, strwidth(modes))
    desc_width = math.max(desc_width, strwidth(desc))
    items[#items + 1] = { key = key, modes = modes, desc = desc }

    ::continue::
  end

  local item_width = PADDING_LEFT + key_width + 2 + mode_width + 2 + desc_width + PADDING_RIGHT ---@type integer
  local content_width = available_width - PADDING_LEFT - PADDING_RIGHT ---@type integer
  local columns = math.max(1, math.floor((content_width + COLUMN_GAP) / (item_width + COLUMN_GAP))) ---@type integer
  local rows = math.ceil(#items / columns) ---@type integer

  local lines = {} ---@type string[]
  local highlights = {} ---@type ark.t.IHighlight[]

  lines[#lines + 1] = ""

  for row = 1, rows do
    local line_parts = {} ---@type string[]
    ---@type {coll: integer, colr: integer, hlname: string}[]
    local row_highlights = {}
    local current_col = PADDING_LEFT ---@type integer

    for col = 1, columns do
      local idx = (col - 1) * rows + row ---@type integer
      local item = items[idx] ---@type dot.module.board.keysheet.IItem|nil
      if item == nil then
        break
      end

      local key_padding = string.rep(" ", key_width - strwidth(item.key)) ---@type string
      local mode_padding = string.rep(" ", mode_width - strwidth(item.modes)) ---@type string
      local desc_padding = string.rep(" ", desc_width - strwidth(item.desc)) ---@type string

      local part = string.format("%s%s  %s%s  %s%s", item.key, key_padding, item.modes, mode_padding, item.desc, desc_padding)
      line_parts[#line_parts + 1] = part

      row_highlights[#row_highlights + 1] = {
        coll = current_col,
        colr = current_col + #item.key,
        hlname = "fb_keysheet_key",
      }

      row_highlights[#row_highlights + 1] = {
        coll = current_col + key_width + 2,
        colr = current_col + key_width + 2 + #item.modes,
        hlname = "fb_keysheet_mode",
      }

      row_highlights[#row_highlights + 1] = {
        coll = current_col + key_width + 2 + mode_width + 2,
        colr = current_col + key_width + 2 + mode_width + 2 + #item.desc,
        hlname = "fb_keysheet_desc",
      }

      current_col = current_col + item_width - PADDING_LEFT - PADDING_RIGHT + COLUMN_GAP
    end

    local line = string.rep(" ", PADDING_LEFT) .. table.concat(line_parts, string.rep(" ", COLUMN_GAP))
    local lnum = #lines ---@type integer

    for _, hl in ipairs(row_highlights) do
      highlights[#highlights + 1] = {
        lnum = lnum,
        coll = hl.coll,
        colr = hl.colr,
        hlname = hl.hlname,
      }
    end

    lines[#lines + 1] = line
  end

  lines[#lines + 1] = ""

  return lines, highlights
end

---@protected
---@param bufnr                         integer
---@return nil
function M:__setup_keymaps__(bufnr)
  ---@type ark.t.IKeymap[]
  local keymaps = {
    { modes = { "n" }, key = "q", callback = function() self:close() end, desc = "keysheet: close" },
    { modes = { "n" }, key = "<Esc>", callback = function() self:close() end, desc = "keysheet: close" },
  }
  ark.nvim.bindkeys(keymaps, { bufnr = bufnr, noremap = true, silent = true })
end

return M
