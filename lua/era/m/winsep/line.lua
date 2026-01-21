---@class era.m.winsep.line.highlights
local config = {
  zindex = dot.var.zindex.WINSEP,
  h = {
    border = { " ", " ", "╭", "│", "╰", " ", " ", " " },
    winhighlight = table.concat({
      "FloatBorder:f_winsep_border",
      "FloatTitle:f_winsep_title",
      "NormalFloat:f_winsep_normal",
    }, ","),
  },
  k = {
    border = { " ", " ", " ", " ", "╮", "─", "╭", " " },
    winhighlight = table.concat({
      "FloatBorder:f_winsep_border",
      "FloatTitle:f_winsep_title",
      "NormalFloat:f_winsep_normal",
    }, ","),
  },
  l = {
    border = { "╮", " ", " ", " ", " ", " ", "╯", "│" },
    winhighlight = table.concat({
      "FloatBorder:f_winsep_border",
      "FloatTitle:f_winsep_title",
      "NormalFloat:f_winsep_normal",
    }, ","),
  },
  j = {
    border = { "╰", "─", "╯", " ", " ", " ", " ", " " },
    winhighlight = table.concat({
      "FloatBorder:f_winsep_border",
      "FloatTitle:f_winsep_title",
      "NormalFloat:f_winsep_normal",
    }, ","),
  },
}

---@alias era.m.winsep.line.Direction
---| "h" left
---| "k" top
---| "l" right
---| "j" bottom

---@class era.m.winsep.line.IProps
---@field public direction              era.m.winsep.line.Direction
---@field public winhighlight           ?string
---@field public zindex                 ?integer

---@class era.m.winsep.Line
---@field public _cfg                   vim.api.keyset.win_config
---@field public _size                  integer
---@field public _winnr                 integer|nil
---@field public _bufnr                 integer|nil
---@field public _winhighlight          string
---@field public _direction             era.m.winsep.line.Direction
local M = {}
M.__index = M

---@param props                         era.m.winsep.line.IProps
---@return era.m.winsep.Line
function M.new(props)
  local self = setmetatable({}, M)

  local direction = props.direction ---@type era.m.winsep.line.Direction
  local winhighlight = props.winhighlight or config[direction].winhighlight ---@type string
  local zindex = props.zindex or config.zindex ---@type integer

  ---@type vim.api.keyset.win_config
  local cfg = {
    zindex = zindex,
    relative = "editor",
    row = 0,
    col = 0,
    width = 1,
    height = 1,
    border = "none",
    style = "minimal",
    focusable = false,
  }

  self._cfg = cfg
  self._size = 0
  self._winnr = nil
  self._bufnr = nil
  self._direction = direction
  self._winhighlight = winhighlight
  return self
end

---@return nil
function M:hide()
  if self._winnr == nil then
    return
  end

  if vim.api.nvim_win_is_valid(self._winnr) then
    vim.api.nvim_win_close(self._winnr, true)
  end
  self._winnr = nil
end

---@return integer
---@return boolean
function M:create_buf_as_needed()
  if self._bufnr ~= nil and vim.api.nvim_buf_is_valid(self._bufnr) then
    return self._bufnr, false
  end

  local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = bufnr })
  vim.api.nvim_set_option_value("buflisted", false, { buf = bufnr })
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = bufnr })
  vim.api.nvim_set_option_value("filetype", stl.filetype.WINSEP, { buf = bufnr })
  vim.api.nvim_set_option_value("swapfile", false, { buf = bufnr })
  vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })
  vim.api.nvim_set_option_value("readonly", true, { buf = bufnr })

  local winnr = self._winnr ---@type integer|nil
  if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
    vim.api.nvim_win_set_buf(winnr, bufnr)
  end

  self._bufnr = bufnr
  self._size = 0
  return bufnr, true
end

---@param bufnr                         integer
---@param lines                         string[]
---@return nil
function M.set_content(bufnr, lines)
  vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
  vim.api.nvim_set_option_value("readonly", false, { buf = bufnr })
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })
  vim.api.nvim_set_option_value("readonly", true, { buf = bufnr })
end

---@param row                           integer
---@param col                           integer
---@param size                          integer
---@return nil
function M:move(row, col, size)
  local bufnr = self:create_buf_as_needed() ---@type integer
  local cfg = self._cfg ---@type vim.api.keyset.win_config
  local direction = self._direction ---@type era.m.winsep.line.Direction

  cfg.row = row
  cfg.col = col

  if direction == "h" then
    cfg.height = size + 2
    if self._size ~= size then
      local lines = { "╭" } ---@type string[]
      for _ = 1, size, 1 do
        lines[#lines + 1] = "│"
      end
      lines[#lines + 1] = "╰"

      self.set_content(bufnr, lines)
      self._size = size
    end
  elseif direction == "k" then
    cfg.width = size + 2
    if self._size ~= size then
      local content = "╭" .. string.rep("─", size) .. "╮" ---@type string
      local lines = { content } ---@type string[]

      self.set_content(bufnr, lines)
      self._size = size
    end
  elseif direction == "l" then
    cfg.height = size + 2
    if self._size ~= size then
      local lines = { "╮" } ---@type string[]
      for _ = 1, size, 1 do
        lines[#lines + 1] = "│"
      end
      lines[#lines + 1] = "╯"

      self.set_content(bufnr, lines)
      self._size = size
    end
  elseif direction == "j" then
    cfg.width = size + 2
    if self._size ~= size then
      local content = "╰" .. string.rep("─", size) .. "╯" ---@type string
      local lines = { content } ---@type string[]

      self.set_content(bufnr, lines)
      self._size = size
    end
  end
end

---@return nil
function M:show()
  local winhighlight = self._winhighlight ---@type string

  local bufnr = self:create_buf_as_needed() ---@type integer
  local winnr = self._winnr ---@type integer|nil
  if winnr == nil or not vim.api.nvim_win_is_valid(winnr) then
    local cfg = vim.tbl_deep_extend("force", { noautocmd = true }, self._cfg) ---@type vim.api.keyset.win_config
    winnr = vim.api.nvim_open_win(bufnr, false, cfg)
    self._winnr = winnr

    vim.w[winnr].wintype = stl.e.WinTypeEnum.WINSEP
    vim.w[winnr][dot.var.N_WINLINE_DISABLED] = true

    vim.api.nvim_set_option_value("cursorline", false, { win = winnr, scope = "local" })
    vim.api.nvim_set_option_value("list", false, { win = winnr, scope = "local" })
    vim.api.nvim_set_option_value("number", false, { win = winnr, scope = "local" })
    vim.api.nvim_set_option_value("signcolumn", "no", { win = winnr, scope = "local" })
    vim.api.nvim_set_option_value("spell", false, { win = winnr, scope = "local" })
    vim.api.nvim_set_option_value("wrap", false, { win = winnr, scope = "local" })
  else
    local cfg = self._cfg ---@type vim.api.keyset.win_config
    vim.api.nvim_set_option_value("winfixbuf", false, { win = winnr, scope = "local" })
    vim.api.nvim_win_set_config(winnr, cfg)
    vim.api.nvim_win_set_buf(winnr, bufnr)
  end

  vim.api.nvim_set_option_value("winhighlight", winhighlight, { win = winnr, scope = "local" })
  vim.api.nvim_set_option_value("winfixbuf", true, { win = winnr, scope = "local" })
end

return M
