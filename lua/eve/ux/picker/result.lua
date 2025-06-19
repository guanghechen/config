---@diagnostic disable: invisible
local __module_name__ = "eve.ux.picker.result" ---@type string

---@alias eve.ux.picker.result.IDraw
---| fun(bufnr: integer): eve.ux.picker.result.IDrawResult

---@alias eve.ux.picker.result.IIsSelected
---| fun(bufnr: integer, lnum: integer): boolean

---@alias eve.ux.picker.result.IOnDrawed
---| fun(bufnr: integer): nil

---@class eve.ux.picker.result.IDrawResult
---@field public lnum_current           integer|nil
---@field public lnum_present           integer|nil

---@class eve.ux.picker.result.IFlagItemRaw
---@field public desc                   string
---@field public callback               fun(): nil
---@field public disabled               (fun(): boolean)|boolean|nil
---@field public snapshot               fun(): string, string

---@class eve.ux.picker.result.IFlagItem
---@field public desc                   string
---@field public callback               string
---@field public disabled               fun(): boolean
---@field public snapshot               fun(): string, string

---@class eve.ux.picker.result.IWinOpts
---@field public border                 string|string[]
---@field public number                 boolean
---@field public winhighlight           string

----------------------------------------------------------------------------------------------------

---@class eve.ux.picker.IResultProps
---@field public uuid                   string
---@field public name                   string
---@field public draw                   eve.ux.picker.result.IDraw
---@field public isselected             ?eve.ux.picker.result.IIsSelected
---@field public keymaps                std.t.IKeymap[]
---@field public flags                  eve.ux.picker.result.IFlagItemRaw[]
---@field public flags_start_index      ?0|1
---@field public on_drawed              ?eve.ux.picker.result.IOnDrawed

---@class eve.ux.picker.Result
---@field public uuid                   string
---@field public fullname               string
---@field public draw                   eve.ux.picker.result.IDraw
---@field public flags                  eve.ux.picker.result.IFlagItem[]
---@field public keymaps                std.t.IKeymap[]
---@field public lnum_current           std.collection.IObservable
---@field public lnum_present           std.collection.IObservable
---@field public lnum_total             std.collection.IObservable
---@field protected _disposed           boolean
---@field protected _bufnr              integer|nil
---@field protected _winnr              integer|nil
---@field protected _augroup_CursorMoved      integer
---@field protected _nvimbar                  eve.ux.nvimbar.Nvimbar
---@field protected _scheduler_content        std.collection.Scheduler
---@field protected _scheduler_lnum_current   std.collection.Scheduler
---@field protected _scheduler_lnum_present   std.collection.Scheduler
---@field protected _scheduler_lnums_selected std.collection.Scheduler
local M = {}
M.__index = M

---@param props                         eve.ux.picker.IResultProps
---@return eve.ux.picker.Result
function M.new(props)
  local uuid = props.uuid ---@type string
  local name = props.name ---@type string
  local fullname = string.format("%s -> %s", name, __module_name__) ---@type string
  local draw = props.draw ---@type eve.ux.picker.result.IDraw
  local isselected = props.isselected or std.fn.falsy ---@type eve.ux.picker.result.IIsSelected
  local keymaps = props.keymaps ---@type std.t.IKeymap[]
  local flags_start_index = props.flags_start_index == 0 and 0 or 1 ---@type 0|1

  local on_drawed = props.on_drawed or std.fn.noop ---@type eve.ux.picker.result.IOnDrawed
  local augroup_CursorMoved = eve.nvim.augroup(string.format("picker.result:CursorMoved#%s", uuid)) ---@type integer

  local _o_lnum_current = std.Observable.from_value(0) ---@type std.collection.IObservable
  local _o_lnum_present = std.Observable.from_value(-1) ---@type std.collection.IObservable
  local _o_lnum_total = std.Observable.from_value(0) ---@type std.collection.IObservable

  local flags = {} ---@type eve.ux.picker.result.IFlagItem[]
  if props.flags ~= nil and #props.flags > 0 then
    for _, flag in ipairs(props.flags) do
      ---@cast flag                     eve.ux.picker.result.IFlagItemRaw
      local raw_disabled = flag.disabled ---@type boolean|nil|(fun(): boolean)
      local callback = flag.callback ---@type fun(): nil
      local snapshot = flag.snapshot ---@type fun(): boolean, string

      local disabled ---@type fun(): boolean
      if raw_disabled == nil or raw_disabled == false then
        disabled = std.fn.falsy
      elseif raw_disabled == true then
        disabled = std.fn.truthy
      else
        ---@return boolean
        disabled = function()
          return raw_disabled()
        end
      end

      local callback_fn = eve.G.register_anonymous_fn(callback) or "eve.G.noop" ---@type string

      ---@type eve.ux.picker.result.IFlagItem
      local item = {
        desc = flag.desc,
        callback = callback_fn,
        disabled = disabled,
        snapshot = snapshot,
      }
      flags[#flags + 1] = item
    end
  end

  local position = "f_wl" ---@type eve.ux.nvimbar.PositionEnum
  local c = eve.ux.nvimbar.component

  local self = setmetatable({}, M)

  ---@type eve.ux.nvimbar.Nvimbar
  local nvimbar = eve.ux.nvimbar.Nvimbar
    .new({
      name = string.format("%s#winline", fullname),
      comp_sep = "",
      comp_sep_hlname = "f_wl_picker",
      comp_sep_hlname_active = "f_wl_picker",
      delay = 128,
      silent = std.fn.falsy,
      get_max_width = function()
        local winnr = self._winnr ---@type integer|nil
        if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
          return vim.api.nvim_win_get_width(winnr)
        end
        return 0
      end,
      get_preset_context = function()
        local winnr = self._winnr ---@type integer|nil
        return { winnr = winnr }
      end,
      is_active = function()
        local winnr = self._winnr ---@type integer|nil
        return winnr == vim.api.nvim_get_current_win()
      end,
      on_fulfilled = function(result)
        local winnr = self._winnr ---@type integer|nil
        if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
          vim.wo[winnr].winbar = result
        end
      end,
    })
    :place("left", c.picker.result_flags(position, flags, flags_start_index), 100)
    :place("right", c.picker.result_pos(position, _o_lnum_current, _o_lnum_total), 100)

  ---@type std.collection.Scheduler
  local scheduler_lnum_current = std.Scheduler.new({
    name = string.format("%s#lnum_current", fullname),
    mode = "throttle",
    delay = 32,
    timeout = 0,
    silent = std.fn.falsy,
    value = std.Observable.from_value(true),
    task = function()
      local bufnr = self._bufnr ---@type integer|nil
      if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
        local group = eve.var.sign.GROUP_PICKER_RESULT_CURRENT ---@type string
        local signnr = eve.var.sign.NR_PICKER_RESULT_CURRENT ---@type integer
        local lnum = _o_lnum_current:snapshot() ---@type integer
        local lnum_present = _o_lnum_present:snapshot() ---@type integer

        pcall(vim.fn.sign_unplace, group, { id = signnr, buffer = bufnr })
        if lnum > 0 then
          local sign = eve.var.sign.PICKER_RESULT_CURRENT ---@type string
          if isselected(bufnr, lnum) then
            sign = eve.var.sign.PICKER_RESULT_SELECTED_CURRENT
          elseif lnum == lnum_present then
            sign = eve.var.sign.PICKER_RESULT_PRESENT_CURRENT
          end
          pcall(vim.fn.sign_place, signnr, group, sign, bufnr, { lnum = lnum, priority = 50 })
        end
      end
    end,
  })

  ---@type std.collection.Scheduler
  local scheduler_lnum_present = std.Scheduler.new({
    name = string.format("%s#lnum_present", fullname),
    mode = "debounce",
    delay = 64,
    timeout = 0,
    silent = std.fn.falsy,
    value = std.Observable.from_value(true),
    task = function()
      local bufnr = self._bufnr ---@type integer|nil
      if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
        local group = eve.var.sign.GROUP_PICKER_RESULT_PRESENT ---@type string
        local signnr = eve.var.sign.NR_PICKER_RESULT_PRESENT ---@type integer
        local lnum_present = _o_lnum_present:snapshot() ---@type integer

        pcall(vim.fn.sign_unplace, group, { id = signnr, buffer = bufnr })
        if lnum_present > 0 then
          local sign = eve.var.sign.PICKER_RESULT_PRESENT ---@type string
          pcall(vim.fn.sign_place, signnr, group, sign, bufnr, { lnum = lnum_present, priority = 30 })
        end
      end
    end,
  })

  ---@type std.collection.Scheduler
  local scheduler_lnums_selected = std.Scheduler.new({
    name = string.format("%s#lnums_selected", fullname),
    mode = "debounce",
    delay = 128,
    timeout = 0,
    silent = std.fn.falsy,
    value = std.Observable.from_value(true),
    task = function()
      local bufnr = self._bufnr ---@type integer|nil
      if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
        local group = eve.var.sign.GROUP_PICKER_RESULT_SELECTED ---@type string
        local sign = eve.var.sign.PICKER_RESULT_SELECTED ---@type string
        pcall(vim.fn.sign_unplace, group, { buffer = bufnr })

        local linecount = vim.api.nvim_buf_line_count(bufnr) ---@type integer
        for lnum = 1, linecount, 1 do
          if isselected(bufnr, lnum) then
            pcall(vim.fn.sign_place, lnum, group, sign, bufnr, { lnum = lnum, priority = 40 })
          end
        end
      end
    end,
  })

  ---@type std.collection.Scheduler
  local scheduler_content = std.Scheduler.new({
    name = string.format("%s#content", fullname),
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
      local ok, result = pcall(draw, bufnr) ---@type boolean, eve.ux.picker.result.IDrawResult
      vim.bo[bufnr].modifiable = false
      vim.bo[bufnr].readonly = true

      local lnum_total = vim.api.nvim_buf_line_count(bufnr) ---@type integer
      if lnum_total == 1 then
        local lines = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)
        if lines[1] == "" then
          lnum_total = 0
        end
      end

      if not ok then
        std.reporter.error({
          from = fullname,
          subject = "draw",
          message = "Failed to draw",
          details = {
            bufnr = bufnr,
            error = result,
          },
        })
        return
      end

      local lnum_current = math.min(lnum_total, math.max(1, result.lnum_current or _o_lnum_current:snapshot())) ---@type integer
      local lnum_present = result.lnum_present or -1 ---@type integer

      _o_lnum_current:next(lnum_current)
      _o_lnum_present:next(lnum_present)
      _o_lnum_total:next(lnum_total)

      self._scheduler_lnum_current:schedule()
      self._scheduler_lnum_present:schedule()
      self._scheduler_lnums_selected:schedule()

      local on_drawed_ok, on_drawed_result = pcall(on_drawed, bufnr)
      if not on_drawed_ok then
        std.reporter.error({
          from = fullname,
          subject = "on_drawed",
          message = "Failed to call on_drawed",
          details = {
            bufnr = bufnr,
            error = on_drawed_result,
            lnum_current = lnum_current,
            lnum_present = lnum_present,
            lnum_total = lnum_total,
          },
        })
      end
    end,
  })

  self.fullname = name
  self.draw = draw
  self.keymaps = keymaps
  self.lnum_current = _o_lnum_current
  self.lnum_present = _o_lnum_present
  self.lnum_total = _o_lnum_total

  self._disposed = false
  self._bufnr = nil
  self._winnr = nil
  self._augroup_CursorMoved = augroup_CursorMoved
  self._nvimbar = nvimbar
  self._scheduler_content = scheduler_content
  self._scheduler_lnum_current = scheduler_lnum_current
  self._scheduler_lnum_present = scheduler_lnum_present
  self._scheduler_lnums_selected = scheduler_lnums_selected

  std.fn.observe({ _o_lnum_total }, function()
    local winnr = self._winnr ---@type integer|nil
    if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
      local lnum_total = _o_lnum_total:snapshot() ---@type integer
      vim.wo[winnr].cursorline = lnum_total > 0
      nvimbar:render()
    end
  end)

  std.fn.observe({ _o_lnum_current }, function()
    local winnr = self._winnr ---@type integer|nil
    if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
      local cursor = vim.api.nvim_win_get_cursor(winnr) ---@type integer[]
      local lnum_current = _o_lnum_current:snapshot() ---@type integer
      if cursor[1] ~= lnum_current then
        pcall(vim.api.nvim_win_set_cursor, winnr, { lnum_current, 0 })
      end
      nvimbar:render()
    end
    self._scheduler_lnum_current:schedule()
  end)

  std.fn.observe({ _o_lnum_current }, function()
    if not self._disposed then
      self._scheduler_lnum_current:schedule()
    end
  end)

  std.fn.observe({ _o_lnum_present }, function()
    if not self._disposed then
      self._scheduler_lnum_present:schedule()
    end
  end)

  vim.api.nvim_create_autocmd("CursorMoved", {
    group = augroup_CursorMoved,
    callback = function()
      local winnr = vim.api.nvim_get_current_win() ---@type integer
      if winnr == self._winnr then
        local cursor = vim.api.nvim_win_get_cursor(winnr) ---@type integer[]
        local row = cursor[1] ---@type integer
        _o_lnum_current:next(row)
      end
    end,
  })

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
  local lnum_current = self.lnum_current ---@type std.collection.IObservable
  local lnum_present = self.lnum_present ---@type std.collection.IObservable
  local lnum_total = self.lnum_total ---@type std.collection.IObservable
  local augroup_CursorMoved = self._augroup_CursorMoved ---@type integer
  local nvimbar = self._nvimbar ---@type eve.ux.nvimbar.Nvimbar
  local scheduler_content = self._scheduler_content ---@type std.collection.Scheduler
  local scheduler_lnum_current = self._scheduler_lnum_current ---@type std.collection.Scheduler
  local scheduler_lnum_present = self._scheduler_lnum_present ---@type std.collection.Scheduler
  local scheduler_lnums_selected = self._scheduler_lnums_selected ---@type std.collection.Scheduler

  self.draw = nil
  self.keymaps = nil
  self.lnum_current = nil
  self.lnum_present = nil
  self.lnum_total = nil
  self._bufnr = nil
  self._winnr = nil
  self._augroup_CursorMoved = nil
  self._nvimbar = nil
  self._scheduler_content = nil
  self._scheduler_lnum_current = nil
  self._scheduler_lnum_present = nil
  self._scheduler_lnums_selected = nil

  local ok1, error1 = pcall(lnum_current.dispose, lnum_current)
  local ok2, error2 = pcall(lnum_present.dispose, lnum_present)
  local ok3, error3 = pcall(lnum_total.dispose, lnum_total)
  local ok4, error4 = pcall(eve.win.close, winnr)
  local ok5, error5 = pcall(eve.buf.close, bufnr)
  local ok6, error6 = pcall(vim.api.nvim_clear_autocmds, { group = augroup_CursorMoved })
  local ok7, error7 = pcall(nvimbar.dispose, nvimbar)
  local ok8, error8 = pcall(scheduler_content.dispose, scheduler_content)
  local ok9, error9 = pcall(scheduler_lnum_current.dispose, scheduler_lnum_current)
  local ok10, error10 = pcall(scheduler_lnum_present.dispose, scheduler_lnum_present)
  local ok11, error11 = pcall(scheduler_lnums_selected.dispose, scheduler_lnums_selected)
  if not (ok1 and ok2 and ok3 and ok4 and ok5 and ok6 and ok7 and ok8 and ok9 and ok10 and ok11) then
    std.reporter.error({
      from = fullname,
      subject = "dispose",
      message = "Failed to dispose",
      details = {
        bufnr = bufnr,
        winnr = winnr,
        error1 = not ok1 and error1 or nil,
        error2 = not ok2 and error2 or nil,
        error3 = not ok3 and error3 or nil,
        error4 = not ok4 and error4 or nil,
        error5 = not ok5 and error5 or nil,
        error6 = not ok6 and error6 or nil,
        error7 = not ok7 and error7 or nil,
        error8 = not ok8 and error8 or nil,
        error9 = not ok9 and error9 or nil,
        error10 = not ok10 and error10 or nil,
        error11 = not ok11 and error11 or nil,
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

  vim.b[bufnr].miniai_disable = true
  vim.b[bufnr].minihipatterns_disable = true
  vim.b[bufnr].miniindentscope_disable = true
  vim.bo[bufnr].buflisted = false
  vim.bo[bufnr].buftype = "nofile"
  vim.bo[bufnr].filetype = eve.filetype.UX_PICKER_RESULT
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].readonly = true

  eve.nvim.bindkeys(self.keymaps, { bufnr = bufnr, nowait = true, noremap = true, silent = true })

  self._scheduler_content:schedule({ immediate = true })
  self._scheduler_lnum_current:schedule({ immediate = true })
  self._scheduler_lnum_present:schedule({ immediate = true })
  self._scheduler_lnums_selected:schedule({ immediate = true })
  return bufnr, true
end

---@param winopts                       eve.ux.picker.result.IWinOpts
---@param dimension                     std.t.IWinDimension,
---@return integer
---@return boolean
function M:create_win(winopts, dimension)
  self:__health__()

  local winnr = self._winnr ---@type integer|nil
  if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
    return winnr, false
  end

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
  }
  winnr = vim.api.nvim_open_win(bufnr, false, wincfg)
  self._winnr = winnr

  eve.win.set_type(winnr, eve.win.Types.PICKER_RESULT)

  local lnum_total = self.lnum_total:snapshot() ---@type integer
  vim.wo[winnr].cursorline = lnum_total > 0
  vim.wo[winnr].number = winopts.number
  vim.wo[winnr].relativenumber = winopts.number
  vim.wo[winnr].signcolumn = "yes"
  vim.wo[winnr].spell = false
  vim.wo[winnr].winbar = self._nvimbar:render(true)
  vim.wo[winnr].winblend = winblend
  vim.wo[winnr].winfixbuf = true
  vim.wo[winnr].winhighlight = winopts.winhighlight
  vim.wo[winnr].wrap = false

  vim.schedule(function()
    local lnum = self.lnum_current:snapshot() ---@type integer
    pcall(vim.api.nvim_win_set_cursor, winnr, { lnum, 0 })
  end)
  return winnr, true
end

----------------------------------------------------------------------------------------------------

---@return eve.ux.picker.Result
function M:focus()
  self:__health__()
  local winnr = self._winnr ---@type integer|nil
  if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) and winnr ~= vim.api.nvim_get_current_win() then
    vim.api.nvim_set_current_win(winnr)
  end
  return self
end

---@return eve.ux.picker.Result
function M:hide()
  self:__health__()
  local winnr = self._winnr ---@type integer|nil

  self._winnr = nil

  local ok1, error1 = pcall(eve.win.close, winnr)
  if not ok1 then
    std.reporter.error({
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

---@param dimension                     std.t.IWinDimension,
---@return eve.ux.picker.Result
function M:resize(dimension)
  self:__health__()

  self._nvimbar:render()

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

---@return eve.ux.picker.Result
function M:mark_content_dirty()
  self:__health__()
  self._scheduler_content:schedule()
  return self
end

---@return eve.ux.picker.Result
function M:mark_nvimbar_dirty()
  self:__health__()
  self._nvimbar:render()
  return self
end

---@param step                          integer
---@return nil
function M:movedown(step)
  local total = self.lnum_total:snapshot() ---@type integer
  if total > 1 then
    local lnum = self.lnum_current:snapshot() ---@type integer
    local next_lnum = std.fn.navigate_circular(lnum, step, total) ---@type integer
    self.lnum_current:next(next_lnum)
  end
end

---@param next_lnum                     integer
---@return nil
function M:moveto(next_lnum)
  local total = self.lnum_total:snapshot() ---@type integer
  if total > 1 then
    next_lnum = math.min(total, math.max(0, next_lnum)) ---@type integer
    self.lnum_current:next(next_lnum)
  end
end

---@param lnum                          integer
---@return eve.ux.picker.Result
function M:set_lnum_current(lnum)
  self:__health__()
  local total = self.lnum_total:snapshot() ---@type integer
  lnum = math.min(total, math.max(0, lnum)) ---@type integer
  self.lnum_current:next(lnum, { force = true })
  return self
end

---@param lnum                          integer
---@return eve.ux.picker.Result
function M:set_lnum_present(lnum)
  self:__health__()
  local total = self.lnum_total:snapshot() ---@type integer
  lnum = math.min(total, math.max(0, lnum)) ---@type integer
  self.lnum_present:next(lnum, { force = true })
  return self
end

---@return eve.ux.picker.Result
function M:refresh_signs()
  self:__health__()
  self._scheduler_lnum_current:schedule()
  self._scheduler_lnum_present:schedule()
  self._scheduler_lnums_selected:schedule()
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

return M
