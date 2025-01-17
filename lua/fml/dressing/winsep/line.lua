local ft = require("eve.constant.filetype")

---@class fml.dressing.winsep.line.highlights
local config = {
  h = {
    border = { " ", " ", "╭", "│", "╰", " ", " ", " " },
    winhighlight = table.concat({
      "FloatBorder:f_winsep_left_border",
      "NormalFloat:f_winsep_normal",
    }, ","),
  },
  k = {
    border = { " ", " ", " ", " ", "╮", "─", "╭", " " },
    winhighlight = table.concat({
      "FloatBorder:f_winsep_top_border",
      "NormalFloat:f_winsep_normal",
    }, ","),
  },
  l = {
    border = { "╮", " ", " ", " ", " ", " ", "╯", "│" },
    winhighlight = table.concat({
      "FloatBorder:f_winsep_right_border",
      "NormalFloat:f_winsep_normal",
    }, ","),
  },
  j = {
    border = { "╰", "─", "╯", " ", " ", " ", " ", " " },
    winhighlight = table.concat({
      "FloatBorder:f_winsep_bottom_border",
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
---@field public zindex                 integer
---@field public winhighlight           ?string

---@class fml.dressing.winsep.Line
---@field public _cfg                   vim.api.keyset.win_config
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
  local zindex = props.zindex ---@type integer

  ---@type vim.api.keyset.win_config
  local cfg = {
    relative = "editor",
    zindex = zindex,
    width = 1,
    height = 1,
    row = 0,
    col = 0,
    focusable = false,
    border = "none", -- config[direction].border,
    style = "minimal",
  }

  self._cfg = cfg
  self._winnr = nil
  self._bufnr = nil
  self._direction = direction
  self._winhighlight = winhighlight
  return self
end

---@return nil
function M:hide()
  if self._winnr ~= nil and vim.api.nvim_win_is_valid(self._winnr) then
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
  vim.bo[bufnr].buflisted = false
  vim.bo[bufnr].buftype = "nofile"
  vim.bo[bufnr].filetype = ft.WINSEP
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].modifiable = true
  vim.bo[bufnr].readonly = true

  local winnr = self._winnr ---@type integer|nil
  if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
    vim.api.nvim_win_set_buf(winnr, bufnr)
  end

  self._bufnr = bufnr
  return bufnr, true
end

---@param row                           integer
---@param col                           integer
---@param size                          integer
---@return nil
function M:move(row, col, size)
  local bufnr, new_created = self:create_buf_as_needed() ---@type integer
  local cfg = self._cfg ---@type vim.api.keyset.win_config
  local direction = self._direction ---@type fml.dressing.winsep.line.Direction

  cfg.row = row
  cfg.col = col

  if direction == "h" then
    if not new_created or cfg.height ~= size then
      local lines = { "╭" } ---@type string[]
      for _ = 1, size, 1 do
        lines[#lines + 1] = "│"
      end
      lines[#lines + 1] = "╰"

      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
      cfg.height = size + 2
    end
  elseif direction == "k" then
    if not new_created or cfg.width ~= size then
      local content = "╭" .. string.rep("─", size) .. "╮" ---@type string
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { content })
      cfg.width = size + 2
    end
  elseif direction == "l" then
    if not new_created or cfg.height ~= size then
      local lines = { "╮" } ---@type string[]
      for _ = 1, size, 1 do
        lines[#lines + 1] = "│"
      end
      lines[#lines + 1] = "╯"

      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
      cfg.height = size + 2
    end
  elseif direction == "j" then
    if not new_created or cfg.width ~= size then
      local content = "╰" .. string.rep("─", size) .. "╯" ---@type string
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { content })
      cfg.width = size + 2
    end
  end
end

---@return nil
function M:show()
  local winhighlight = self._winhighlight ---@type string
  local cfg = self._cfg ---@type vim.api.keyset.win_config

  local bufnr = self:create_buf_as_needed() ---@type integer
  local winnr = self._winnr ---@type integer|nil
  if winnr == nil or not vim.api.nvim_win_is_valid(winnr) then
    winnr = vim.api.nvim_open_win(bufnr, false, cfg)
    self._winnr = winnr

    vim.wo[winnr].cursorline = false
    vim.wo[winnr].number = false
    vim.wo[winnr].signcolumn = "no"
    vim.wo[winnr].wrap = false
    vim.wo[winnr].list = false
  else
    vim.wo[winnr].winfixbuf = false
    vim.api.nvim_win_set_config(winnr, cfg)
    vim.api.nvim_win_set_buf(winnr, bufnr)
  end

  vim.wo[winnr].winhighlight = winhighlight
  vim.wo[winnr].winfixbuf = true
end

return M
