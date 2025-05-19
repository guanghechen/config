---@diagnostic disable: invisible
local __module_name__ = "eve.ux.picker.preview" ---@type string

---@alias eve.ux.picker.preview.IDraw
---| fun(bufnr: integer): eve.ux.picker.preview.IDrawResult

---@alias eve.ux.picker.preview.IOnDrawed
---| fun(bufnr: integer): nil

---@class eve.ux.picker.preview.IDrawResult
---@field public cursorline             boolean
---@field public number                 boolean
---@field public title                  string
---@field public wrap                   boolean
---@field public lnum                   ?integer
---@field public col                    ?integer

---@class eve.ux.picker.preview.IWinOpts
---@field public border                 string|string[]
---@field public winhighlight           string

----------------------------------------------------------------------------------------------------

---@class eve.ux.IPickerPreviewProps
---@field public name                   string
---@field public draw                   eve.ux.picker.preview.IDraw
---@field public keymaps                std.t.IKeymap[]
---@field public on_drawed              ?eve.ux.picker.preview.IOnDrawed

---@class eve.ux.PickerPreview
---@field public name                   string
---@field public keymaps                std.t.IKeymap[]
---@field protected _disposed           boolean
---@field protected _bufnr              integer|nil
---@field protected _winnr              integer|nil
---@field protected _last_result        eve.ux.picker.preview.IDrawResult|nil
---@field protected _scheduler_content  std.collection.Scheduler
local M = {}
M.__index = M

---@param props                         eve.ux.IPickerPreviewProps
---@return eve.ux.PickerPreview
function M.new(props)
  local name = props.name ---@type string
  local draw = props.draw ---@type eve.ux.picker.preview.IDraw
  local keymaps = props.keymaps ---@type std.t.IKeymap[]
  local on_drawed = props.on_drawed or std.fn.noop ---@type eve.ux.picker.preview.IOnDrawed

  local self = setmetatable({}, M)

  local scheduler_content = std.Scheduler.new({
    name = name,
    mode = "debounce",
    delay = 128,
    timeout = 0,
    silent = std.fn.falsy,
    value = std.Observable.from_value(true),
    task = function()
      local bufnr = self._bufnr ---@type integer|nil
      if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
        return
      end

      vim.bo[bufnr].modifiable = true
      vim.bo[bufnr].readonly = false
      local ok, result = pcall(draw, bufnr) ---@type boolean, eve.ux.picker.preview.IDrawResult
      vim.bo[bufnr].modifiable = false
      vim.bo[bufnr].readonly = true

      if not ok then
        std.reporter.error({
          from = string.format("%s | %s", name, __module_name__),
          subject = "draw",
          message = "Failed to draw",
          details = {
            bufnr = bufnr,
            error = result,
          },
        })
        return
      end

      self._last_result = result
      self:__update_winopts__()

      local on_drawed_ok, on_drawed_result = pcall(on_drawed, bufnr)
      if not on_drawed_ok then
        std.reporter.error({
          from = string.format("%s | %s", name, __module_name__),
          subject = "on_drawed",
          message = "Failed to call on_drawed",
          details = {
            bufnr = bufnr,
            error = on_drawed_result,
            title = result.title,
          },
        })
      end
    end,
  })

  self.name = name
  self.keymaps = keymaps

  self._disposed = false
  self._bufnr = nil
  self._winnr = nil
  self._scheduler_content = scheduler_content
  return self
end

---@return nil
function M:dispose()
  if self._disposed then
    return nil
  end
  self._disposed = true

  local name = self.name ---@type string
  local bufnr = self._bufnr ---@type integer|nil
  local winnr = self._winnr ---@type integer|nil
  local scheduler_content = self._scheduler_content ---@type std.collection.Scheduler
  vim.schedule(function()
    local ok1, error1 = pcall(eve.win.close, winnr)
    local ok2, error2 = pcall(eve.buf.close, bufnr)
    local ok3, error3 = pcall(scheduler_content.dispose, scheduler_content)
    if not (ok1 and ok2) then
      std.reporter.error({
        from = string.format("%s | %s", name, __module_name__),
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
  end)

  self._bufnr = nil
  self._winnr = nil
  self._last_result = nil
  self._scheduler_content = nil
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
  vim.bo[bufnr].filetype = eve.filetype.UX_PICKER_PREVIEW
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].readonly = true

  eve.nvim.bindkeys(self.keymaps, { bufnr = bufnr, nowait = true, noremap = true, silent = true })
  return bufnr, true
end

---@param winopts                       eve.ux.picker.preview.IWinOpts
---@param dimension                     std.t.IWinDimension
---@return integer
---@return boolean
function M:create_win(winopts, dimension)
  self:__health__()

  local winnr = self._winnr ---@type integer|nil
  if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
    return winnr, false
  end

  local result = self._last_result ---@type eve.ux.picker.preview.IDrawResult|nil
  local bufnr = self:create_buf() ---@type integer
  local winblend = eve.context.theme.get_float_winblend() ---@type integer
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
    title = result and result.title or nil,
    title_pos = result and result.title and "center" or nil,
  }
  winnr = vim.api.nvim_open_win(bufnr, false, wincfg)
  self._winnr = winnr

  eve.win.set_type(winnr, eve.win.Types.PICKER_PREVIEW)
  vim.wo[winnr].list = true
  vim.wo[winnr].listchars = string.format(
    "eol:%s,lead:%s,nbsp:%s,space:%s,trail:%s",
    eve.icon.listchars.eol,
    eve.icon.listchars.lead,
    eve.icon.listchars.nbsp,
    eve.icon.listchars.space,
    eve.icon.listchars.trail
  )
  vim.wo[winnr].cursorline = result ~= nil and result.cursorline == true
  vim.wo[winnr].number = result ~= nil and result.number == true
  vim.wo[winnr].relativenumber = false
  vim.wo[winnr].spell = false
  vim.wo[winnr].signcolumn = "yes"
  vim.wo[winnr].winblend = winblend
  vim.wo[winnr].winfixbuf = true
  vim.wo[winnr].winhighlight = winopts.winhighlight
  vim.wo[winnr].wrap = result ~= nil and result.wrap == true

  if result ~= nil and result.lnum ~= nil then
    pcall(vim.api.nvim_win_set_cursor, winnr, { result.lnum, result.col or 0 })
  end
  return winnr, true
end

----------------------------------------------------------------------------------------------------

---@return eve.ux.PickerPreview
function M:focus()
  self:__health__()
  local winnr = self._winnr ---@type integer|nil
  if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) and winnr ~= vim.api.nvim_get_current_win() then
    vim.api.nvim_set_current_win(winnr)
  end
  return self
end

---@return eve.ux.PickerPreview
function M:hide()
  self:__health__()
  local winnr = self._winnr ---@type integer|nil
  local bufnr = self._bufnr ---@type integer|nil

  local ok1, error1 = pcall(eve.win.close, winnr)
  local ok2, error2 = pcall(eve.buf.close, bufnr)
  if not (ok1 and ok2) then
    std.reporter.error({
      from = string.format("%s | %s", self.name, __module_name__),
      subject = "hide",
      message = "Failed to hide",
      details = {
        bufnr = bufnr,
        winnr = winnr,
        error1 = not ok1 and error1 or nil,
        error2 = not ok2 and error2 or nil,
      },
    })
  end

  self._winnr = nil
  self._bufnr = nil
  return self
end

---@param dimension                     std.t.IWinDimension,
---@return eve.ux.PickerPreview
function M:resize(dimension)
  self:__health__()

  local winnr = self._winnr ---@type integer|nil
  if winnr == nil or not vim.api.nvim_win_is_valid(winnr) then
    return self
  end

  local _wincfg = vim.api.nvim_win_get_config(winnr) ---@type vim.api.keyset.win_config
  _wincfg.row = dimension.row
  _wincfg.col = dimension.col
  _wincfg.width = dimension.width
  _wincfg.height = dimension.height
  vim.api.nvim_win_set_config(winnr, _wincfg)
  return self
end

----------------------------------------------------------------------------------------------------

---@return eve.ux.PickerPreview
function M:mark_content_dirty()
  self:__health__()
  self._scheduler_content:schedule()
  return self
end

----------------------------------------------------------------------------------------------------

---@return nil
function M:__health__()
  if self._disposed then
    local message = string.format("[%s | %s] has been disposed.", self.name, __module_name__) ---@type string
    error(message)
  end
end

---@return eve.ux.PickerPreview
function M:__update_winopts__()
  local result = self._last_result ---@type eve.ux.picker.preview.IDrawResult
  if result == nil then
    return self
  end

  local winnr = self._winnr ---@type integer|nil
  if winnr == nil or not vim.api.nvim_win_is_valid(winnr) then
    return self
  end

  local wincfg = vim.api.nvim_win_get_config(winnr) ---@type vim.api.keyset.win_config
  wincfg.title = result.title
  wincfg.title_pos = #result.title > 0 and "center" or nil
  vim.wo[winnr].cursorline = result.cursorline
  vim.wo[winnr].number = result.number
  vim.wo[winnr].wrap = result.wrap
  vim.api.nvim_win_set_config(winnr, wincfg)

  if result.lnum ~= nil then
    pcall(vim.api.nvim_win_set_cursor, winnr, { result.lnum, result.col or 0 })
  end
  return self
end

return M
