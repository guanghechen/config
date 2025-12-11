---@class ux.ISelectItem
---@field public uuid                   string
---@field public text                   string
---@field public highlights             ark.t.IHighlightInline[]|nil

---@class ux.ISelectProps
---@field public wincfg                 vim.api.keyset.win_config|nil
---@field public keymaps                ark.t.IKeymap[]|nil
---@field public items                  ux.ISelectItem[]
---@field public item_present_uuid      string|nil
---@field public on_select              fun(widget: ux.ISelect, item: ux.ISelectItem|nil): nil

---@class ux.ISelect
---@field public create_buf_as_needed   fun(self: ux.ISelect): integer
---@field public destroy                fun(self: ux.ISelect): nil
---@field public focus                  fun(self: ux.ISelect): integer

---@class ux.Select : ux.ISelect
---@field protected _bufnr              integer|nil
---@field protected _winnr              integer|nil
---@field protected _wincfg             vim.api.keyset.win_config
---@field protected _keymaps            ark.t.IKeymap[]
---@field protected _items              ux.ISelectItem[]
---@field protected _item_index_present integer
---@field protected _on_select          fun(widget: ux.ISelect, item: ux.ISelectItem)
local M = {}
M.__index = M

---@class ux.select.config
local config = {
  winhighlight = table.concat({
    "Cursor:f_us_main_current",
    "CursorColumn:f_us_main_current",
    "CursorLine:f_us_main_current",
    "CursorLineNr:f_us_main_current",
    "FloatBorder:FloatActiveBorder",
    "FloatTitle:FloatActiveTitle",
    "Normal:f_us_main_normal",
  }, ","),
}

---@param props                         ux.ISelectProps
---@return ux.Select
function M.new(props)
  local self = setmetatable({}, M)

  local items = props.items ---@type ux.ISelectItem[]
  local item_present_uuid = props.item_present_uuid ---@type string|nil
  local on_select = props.on_select ---@type fun(widget: ux.ISelect, item: ux.ISelectItem|nil): nil

  local width = 0 ---@type integer
  local item_present_index = 1 ---@type integer

  for index, item in ipairs(items) do
    local w = vim.api.nvim_strwidth(item.text) ---@type integer
    width = width < w and w or width
    item_present_index = item_present_uuid == item.uuid and index or item_present_index
  end

  ---@type vim.api.keyset.win_config
  local wincfg = vim.tbl_extend("force", {
    title = "",
    title_pos = "center",
    width = width + 8,
    height = #items,
    border = "rounded",
    style = "minimal",
    focusable = true,
  }, props.wincfg or {})

  ---@type ark.t.IKeymap[]
  local keymaps = vim.list_extend({
    {
      modes = { "i", "n", "x" },
      key = "<Left>",
      aliases = { "<Right>", "h", "l", "0", "^", "$", "a", "A", "i", "I", "d", "o", "O", "x", "X", "u", "U", "v" },
      desc = "select: noop",
      callback = ark.fn.noop,
    },
    {
      modes = { "i", "n", "x" },
      key = "<C-a>q",
      aliases = { "<D-q>", "<M-q>", "<Esc>" },
      desc = "select: noop",
      callback = function()
        on_select(self, nil)
        self:destroy()
      end,
    },
    {
      modes = { "n", "x" },
      key = "q",
      desc = "select: quit",
      callback = function()
        on_select(self, nil)
        self:destroy()
      end,
    },
    {
      modes = { "i", "n", "x" },
      key = "<LeftMouse>",
      desc = "select: confirm",
      callback = function()
        local winnr = vim.api.nvim_get_current_win() ---@type integer
        ---@diagnostic disable-next-line: invisible
        if self._winnr == winnr then
          local cursor = vim.fn.getmousepos()
          pcall(function()
            vim.api.nvim_win_set_cursor(winnr, { cursor.line, 0 })
          end)
        end
      end,
    },
    {
      modes = { "i", "n", "x" },
      key = "<2-LeftMouse>",
      aliases = { "<cr>", "o" },
      desc = "select: confirm",
      callback = function()
        ---@diagnostic disable-next-line: invisible
        local winnr = self._winnr ---@type integer|nil
        if winnr == nil or not vim.api.nvim_win_is_valid(winnr) then
          self:destroy()
          on_select(self, nil)
          return
        end

        local cursor = vim.api.nvim_win_get_cursor(winnr) ---@type integer[]
        local index = cursor[1] ---@type integer
        local item = items[index] ---@type ux.ISelectItem

        on_select(self, item)
        self:destroy()
      end,
    },
  }, props.keymaps or {})

  self._bufnr = nil ---@type integer|nil
  self._winnr = nil ---@type integer|nil
  self._wincfg = wincfg ---@type vim.api.keyset.win_config
  self._keymaps = keymaps ---@type ark.t.IKeymap[]
  self._items = items ---@type ux.ISelectItem[]
  self._item_index_present = item_present_index ---@type integer
  self._on_select = on_select ---@type fun(item: ux.ISelectItem|nil): nil
  return self
end

---@return integer
---@return boolean
function M:create_buf_as_needed()
  local bufnr = self._bufnr ---@type integer|nil
  if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
    return bufnr, false
  end

  bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  self._bufnr = bufnr

  local lines = {} ---@type string[]
  for i, item in ipairs(self._items) do
    lines[i] = item.text
  end
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

  local nsnr = dot.var.nsnr.select ---@type integer
  for lnum, item in ipairs(self._items) do
    if item.highlights ~= nil then
      for _, hl in ipairs(item.highlights) do
        local row = lnum - 1 ---@type integer
        vim.hl.range(bufnr, nsnr, hl.hlname, { row, hl.coll }, { row, hl.colr })
      end
    end
  end

  vim.bo[bufnr].bufhidden = "wipe"
  vim.bo[bufnr].buflisted = false
  vim.bo[bufnr].buftype = "nofile"
  vim.bo[bufnr].filetype = dot.filetype.SELECT
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].readonly = true
  ark.nvim.bindkeys(self._keymaps, { bufnr = bufnr, noremap = true, silent = true })

  vim.schedule(function()
    vim.cmd("stopinsert")
  end)
  return bufnr, true
end

---@return integer
---@return boolean
function M:create_win_as_needed()
  local bufnr = self:create_buf_as_needed() ---@type integer
  local winnr = self._winnr ---@type integer|nil
  local winblend = eve.context.theme.get_float_winblend() ---@type integer
  local winnr_new_created = false ---@type boolean

  if winnr == nil or not vim.api.nvim_win_is_valid(winnr) then
    self._wincfg.zindex = era.win.resolve_zindex()
    winnr = vim.api.nvim_open_win(bufnr, true, self._wincfg)
    self._winnr = winnr

    winnr_new_created = true

    era.win.set_type(winnr, era.win.Types.SELECT)
    vim.w[winnr][dot.var.N_WINLINE_DISABLED] = true

    vim.wo[winnr].number = false
    vim.wo[winnr].relativenumber = false
    vim.wo[winnr].signcolumn = "yes"
    vim.wo[winnr].spell = false
    vim.wo[winnr].wrap = false
  else
    vim.wo[winnr].winfixbuf = false
    ---@type era.state.maximized.ResolveResizeResult
    local resize = era.state.maximized.resolve_resize_config(winnr, self._wincfg, { winblend = winblend })
    vim.api.nvim_win_set_config(winnr, resize.cfg)
    vim.api.nvim_win_set_buf(winnr, bufnr)
    winblend = resize.winblend or winblend
  end

  vim.wo[winnr].cursorline = true
  vim.wo[winnr].winblend = winblend
  vim.wo[winnr].winhighlight = config.winhighlight
  vim.wo[winnr].winfixbuf = true
  return winnr, winnr_new_created
end

---@return nil
function M:destroy()
  local winnr = self._winnr ---@type integer|nil
  local bufnr = self._bufnr ---@type integer|nil

  self._winnr = nil
  self._bufnr = nil

  if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
    vim.api.nvim_win_close(winnr, true)
  end
  if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end
end

---@return integer
function M:focus()
  local winnr = self:create_win_as_needed()
  local index = self._item_index_present ---@type integer
  vim.api.nvim_win_set_cursor(winnr, { index, 0 })

  vim.api.nvim_set_current_win(winnr)
  vim.schedule(function()
    if vim.api.nvim_win_is_valid(winnr) then
      vim.api.nvim_set_current_win(winnr)
    end
  end)

  return winnr
end

return M
