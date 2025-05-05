---@class fml.dressing.winsep.line.highlights
local config = {
  zindex = 1,
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

---@alias fml.dressing.winsep.line.Direction
---| "h" left
---| "k" top
---| "l" right
---| "j" bottom

---@class fml.dressing.winsep.line.IProps
---@field public direction              fml.dressing.winsep.line.Direction
---@field public winhighlight           ?string
---@field public zindex                 ?integer

---@class fml.dressing.winsep.Line
---@field public _cfg                   vim.api.keyset.win_config
---@field public _size                  integer
---@field public _winnr                 integer|nil
---@field public _bufnr                 integer|nil
---@field public _winhighlight          string
---@field public _direction             fml.dressing.winsep.line.Direction
local M = {}
M.__index = M

---@param props                         fml.dressing.winsep.line.IProps
---@return fml.dressing.winsep.Line
function M.new(props)
  local self = setmetatable({}, M)

  local direction = props.direction ---@type fml.dressing.winsep.line.Direction
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
  vim.bo[bufnr].bufhidden = "wipe"
  vim.bo[bufnr].buflisted = false
  vim.bo[bufnr].buftype = "nofile"
  vim.bo[bufnr].filetype = eve.filetype.WINSEP
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].readonly = true

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
  vim.bo[bufnr].modifiable = true
  vim.bo[bufnr].readonly = false
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].readonly = true
end

---@param row                           integer
---@param col                           integer
---@param size                          integer
---@return nil
function M:move(row, col, size)
  local bufnr = self:create_buf_as_needed() ---@type integer
  local cfg = self._cfg ---@type vim.api.keyset.win_config
  local direction = self._direction ---@type fml.dressing.winsep.line.Direction

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

    eve.win.set_type(winnr, eve.win.Types.WINSEP)
    vim.w[winnr][eve.var.Names.WINLINE_DISABLED] = true

    vim.wo[winnr].cursorline = false
    vim.wo[winnr].list = false
    vim.wo[winnr].number = false
    vim.wo[winnr].signcolumn = "no"
    vim.wo[winnr].spell = false
    vim.wo[winnr].wrap = false
  else
    local cfg = self._cfg ---@type vim.api.keyset.win_config
    vim.wo[winnr].winfixbuf = false
    vim.api.nvim_win_set_config(winnr, cfg)
    vim.api.nvim_win_set_buf(winnr, bufnr)
  end

  vim.wo[winnr].winhighlight = winhighlight
  vim.wo[winnr].winfixbuf = true
end

return M
