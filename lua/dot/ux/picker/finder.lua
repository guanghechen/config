---@diagnostic disable: invisible
local __module_name__ = "dot.ux.picker.finder" ---@type string

---@class dot.ux.picker.finder.IWinOpts
---@field public border                 string|string[]
---@field public winhighlight           string
---@field public zindex                 ?integer

----------------------------------------------------------------------------------------------------

---@class dot.ux.picker.IFinderProps
---@field public name                   string
---@field public keymaps                ark.t.IKeymap[]
---@field public input                  ark.c.Observable
---@field public title                  string

---@class dot.ux.picker.Finder
---@field public fullname               string
---@field public keymaps                ark.t.IKeymap[]
---@field public input                  ark.c.Observable
---@field public linecount              ark.c.Observable
---@field public title                  string
---
---@field protected _disposed           boolean
---@field protected _bufnr              integer|nil
---@field protected _winnr              integer|nil
local M = {}
M.__index = M

---@param props                         dot.ux.picker.IFinderProps
---@return dot.ux.picker.Finder
function M.new(props)
  local name = props.name ---@type string
  local fullname = string.format("%s -> %s", name, __module_name__) ---@type string
  local keymaps = props.keymaps ---@type ark.t.IKeymap[]
  local input = props.input ---@type ark.c.Observable
  local linecount = ark.c.Observable.from_value(0) ---@type ark.c.Observable
  local title = string.format(" %s ", vim.trim(props.title)) ---@type string

  local self = setmetatable({}, M)
  self.fullname = fullname
  self.keymaps = keymaps
  self.input = input
  self.linecount = linecount
  self.title = title

  self._disposed = false
  self._bufnr = nil
  self._winnr = nil
  return self
end

---@return nil
function M:dispose()
  if self._disposed then
    return nil
  end
  self._disposed = true

  local fullname = self.fullname ---@type string
  local bufnr = self._bufnr ---@type integer|nil
  local winnr = self._winnr ---@type integer|nil
  local linecount = self.linecount ---@type ark.c.Observable

  self.input = nil
  self.keymaps = nil
  self.linecount = nil
  self.title = nil
  self._bufnr = nil
  self._winnr = nil

  local ok1, error1 = pcall(linecount.dispose, linecount)
  local ok2, error2 = pcall(dot.win.close, winnr)
  local ok3, error3 = pcall(dot.buf.close, bufnr)
  if not (ok1 and ok2 and ok3) then
    ark.reporter.error({
      from = fullname,
      subject = "dispose",
      message = "Failed to dispose",
      details = {
        bufnr = bufnr,
        winnr = winnr,
        error1 = not ok1 and error1 or nil,
        error2 = not ok2 and error2 or nil,
        error3 = not ok3 and error3 or nil,
      },
    })
  end
end

---@return boolean
function M:isdisposed()
  return self._disposed
end

---@return boolean
function M:isfocused()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  return self._winnr == winnr
end

---@return boolean
function M:isvisible()
  local winnr = self._winnr ---@type integer|nil
  if winnr == nil or not vim.api.nvim_win_is_valid(winnr) then
    self._winnr = nil
    return false
  end
  return true
end

---@return integer|nil
function M:get_bufnr()
  return self._bufnr
end

---@return integer|nil
function M:get_winnr()
  return self._winnr
end

----------------------------------------------------------------------------------------------------

---@return integer
---@return boolean
function M:create_buf()
  self:__health__()

  local bufnr = self._bufnr ---@type integer|nil
  if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
    return bufnr, false
  end

  bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  self._bufnr = bufnr

  vim.b[bufnr].miniindentscope_disable = true
  vim.b[bufnr].miniai_disable = true
  vim.b[bufnr].minihipatterns_disable = true
  vim.bo[bufnr].buflisted = false
  vim.bo[bufnr].buftype = "nofile"
  vim.bo[bufnr].filetype = dot.filetype.UX_PICKER_FINDER
  vim.bo[bufnr].swapfile = false

  ark.nvim.bindkeys(self.keymaps, { bufnr = bufnr, nowait = true, noremap = true, silent = true })

  local keyword = self.input:snapshot() ---@type string
  local initial_lines = { keyword } ---@type string[]
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, initial_lines)
  self:__set_prompt__(bufnr)

  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    buffer = bufnr,
    callback = function()
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false) ---@type string[]

      if #lines > 1 then
        local content = table.concat(lines, " ") ---@type string
        self:set_content(content)
        return
      end

      local content = lines[1] or "" ---@type string
      self.input:next(content)
      self.linecount:next(#lines)
      self:__set_prompt__(bufnr)
    end,
  })
  return bufnr, true
end

---@param winopts                       dot.ux.picker.finder.IWinOpts
---@param dimension                     dot.t.IWinDimension
---@return integer
---@return boolean
function M:create_win(winopts, dimension)
  self:__health__()

  local winnr = self._winnr ---@type integer|nil
  if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
    return winnr, false
  end

  local bufnr = self:create_buf() ---@type integer
  local winblend = dot.context.theme.get_float_winblend() ---@type integer
  local wincfg = {
    relative = "editor",
    row = dimension.row,
    col = dimension.col,
    width = dimension.width,
    height = dimension.height,
    border = winopts.border,
    style = "minimal",
    focusable = true,
    noautocmd = true,
    title = self.title,
    title_pos = "center",
    zindex = winopts.zindex,
  }
  winnr = vim.api.nvim_open_win(bufnr, false, wincfg)
  self._winnr = winnr

  dot.win.set_type(winnr, dot.win.Types.PICKER_FINDER)
  vim.wo[winnr].cursorline = false
  vim.wo[winnr].number = false
  vim.wo[winnr].relativenumber = false
  vim.wo[winnr].signcolumn = "yes"
  vim.wo[winnr].spell = false
  vim.wo[winnr].winblend = winblend
  vim.wo[winnr].winfixbuf = true
  vim.wo[winnr].winhighlight = winopts.winhighlight
  vim.wo[winnr].wrap = false
  return winnr, true
end

----------------------------------------------------------------------------------------------------

---@return dot.ux.picker.Finder
function M:focus()
  self:__health__()
  local winnr = self._winnr ---@type integer|nil
  if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) and winnr ~= vim.api.nvim_get_current_win() then
    vim.api.nvim_set_current_win(winnr)
  end
  return self
end

---@return dot.ux.picker.Finder
function M:hide()
  self:__health__()
  local winnr = self._winnr ---@type integer|nil

  self._winnr = nil

  local ok1, error1 = pcall(dot.win.close, winnr)
  if not ok1 then
    ark.reporter.error({
      from = self.fullname,
      subject = "hide",
      message = "Failed to hide",
      details = {
        winnr = winnr,
        error1 = not ok1 and error1 or nil,
      },
    })
  end

  return self
end

---@param dimension                     dot.t.IWinDimension,
---@return dot.ux.picker.Finder
function M:resize(dimension)
  self:__health__()

  local winnr = self._winnr ---@type integer|nil
  if winnr == nil or not vim.api.nvim_win_is_valid(winnr) then
    return self
  end

  local wincfg = vim.api.nvim_win_get_config(winnr) ---@type vim.api.keyset.win_config
  wincfg.row = dimension.row
  wincfg.col = dimension.col
  wincfg.width = dimension.width
  wincfg.height = dimension.height

  local resize = dot.state.maximized.resolve_resize_config(winnr, wincfg) ---@type dot.state.maximized.ResolveResizeResult
  vim.api.nvim_win_set_config(winnr, resize.cfg)
  return self
end

----------------------------------------------------------------------------------------------------

---@param content                       string
---@return nil
function M:set_content(content)
  self:__health__()

  local bufnr = self._bufnr ---@type integer|nil
  if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  if content == self.input:snapshot() then
    return
  end

  local lines = { content } ---@type  string[]
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  self.input:next(content)
  self.linecount:next(#lines)
  self:__set_prompt__(bufnr)

  local winnr = self._winnr ---@type integer|nil
  if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
    local last_col = #lines[1] ---@type integer
    vim.api.nvim_win_set_cursor(winnr, { 1, last_col })
  end
end

---@param title                         string
---@return dot.ux.picker.Finder
function M:set_title(title)
  self:__health__()
  if self.title ~= title then
    self.title = string.format(" %s ", vim.trim(title))

    local winnr = self._winnr ---@type integer|nil
    if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
      local wincfg = vim.api.nvim_win_get_config(winnr) ---@type vim.api.keyset.win_config
      wincfg.title = self.title
      vim.api.nvim_win_set_config(winnr, wincfg)
    end
  end
  return self
end

----------------------------------------------------------------------------------------------------

---@return nil
function M:__health__()
  if self._disposed then
    local message = string.format("[%s] has been disposed.", self.fullname) ---@type string
    error(message)
  end
end

---@param bufnr                         integer
---@return dot.ux.picker.Finder
function M:__set_prompt__(bufnr)
  if vim.api.nvim_buf_is_valid(bufnr) then
    local group = dot.var.sign.GROUP_PICKER_FINDER_PROMPT ---@type string
    local sign = dot.var.sign.PICKER_FINDER_PROMPT ---@type string
    pcall(vim.fn.sign_place, 1, group, sign, bufnr, { lnum = 1, priority = 10 })
  end
  return self
end

return M
