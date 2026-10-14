---@diagnostic disable: invisible
---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.view.picker.result" ---@type string

local Future = require("stl.c.future")
local nvimbar = require("era.m.nvimbar")
local c = nvimbar.component
local Nvimbar = nvimbar.Nvimbar

---@alias era.view.picker.result.IDraw
---| fun(bufnr: integer): stl.c.Future|nil

---@alias era.view.picker.result.IOnDrawed
---| fun(bufnr: integer): nil

---@alias era.view.picker.result.IStatusSnapshot
---| fun(): string|nil, string|nil

---@class era.view.picker.result.IFlagItemRaw
---@field public desc                   string
---@field public callback               fun(): nil
---@field public disabled               (fun(): boolean)|boolean|nil
---@field public snapshot               fun(): string, string

---@class era.view.picker.result.IFlagItem
---@field public desc                   string
---@field public callback               string
---@field public disabled               fun(): boolean
---@field public snapshot               fun(): string, string

---@class era.view.picker.result.IWinOpts
---@field public border                 string|string[]
---@field public number                 boolean
---@field public winhighlight           string
---@field public zindex                 ?integer

----------------------------------------------------------------------------------------------------

---@class era.view.picker.result.IProps
---@field public tree                   era.view.ResultTree|era.view.Directory
---@field public uuid                   string
---@field public name                   string
---@field public draw                   era.view.picker.result.IDraw
---@field public keymaps                stl.t.IKeymap[]
---@field public flags                  era.view.picker.result.IFlagItemRaw[]
---@field public flags_start_index      ?0|1
---@field public on_drawed              ?era.view.picker.result.IOnDrawed
---@field public status                 ?era.view.picker.result.IStatusSnapshot
---@field public winbar                 ?boolean False omits the bar; position observables remain available.
---@field public winline_hl             string
---@field public diagnostic_scope       string
---@field public augroup_prefix         string

---@class era.view.PickerResult
---@field public uuid                   string
---@field public fullname               string
---@field public draw                   era.view.picker.result.IDraw
---@field public flags                  era.view.picker.result.IFlagItem[]
---@field public keymaps                stl.t.IKeymap[]
---@field public lnum_current           stl.c.Observable
---@field public lnum_present           stl.c.Observable
---@field public lnum_total             stl.c.Observable
---@field protected _disposed           boolean
---@field protected _bufnr              integer|nil
---@field protected _winnr              integer|nil
---@field protected _augroup_CursorMoved integer
---@field protected _nvimbar            ?era.m.nvimbar.Nvimbar
---@field protected _scheduler_content  stl.c.Scheduler
---@field protected _scheduler_lnum_current stl.c.Scheduler
---@field protected _scheduler_lnum_present stl.c.Scheduler
---@field protected _unregister_fns     (fun(): nil)[]
local M = {}
M.__index = M

---@param props                         era.view.picker.result.IProps
---@return era.view.PickerResult
function M.new(props)
  local uuid = props.uuid ---@type string
  local name = props.name ---@type string
  local diagnostic_scope = props.diagnostic_scope ---@type string
  local fullname = string.format("%s -> %s", name, diagnostic_scope) ---@type string
  local native_tree = assert(props.tree, "Picker results require a native Treeview owner")
  local draw = props.draw ---@type era.view.picker.result.IDraw
  local keymaps = props.keymaps ---@type stl.t.IKeymap[]
  local flags_start_index = props.flags_start_index == 0 and 0 or 1 ---@type 0|1
  local status = props.status ---@type era.view.picker.result.IStatusSnapshot|nil
  local winline_hl = props.winline_hl ---@type string
  local augroup_prefix = props.augroup_prefix ---@type string

  local on_drawed = props.on_drawed or stl.fn.noop ---@type era.view.picker.result.IOnDrawed
  local augroup_CursorMoved = stl.nvim.fn.augroup(string.format("%s:CursorMoved#%s", augroup_prefix, uuid)) ---@type integer

  local _o_lnum_current = stl.c.Observable.from_value(0) ---@type stl.c.Observable
  local _o_lnum_present = stl.c.Observable.from_value(-1) ---@type stl.c.Observable
  local _o_lnum_total = stl.c.Observable.from_value(0) ---@type stl.c.Observable

  local flags = {} ---@type era.view.picker.result.IFlagItem[]
  local unregister_fns = {} ---@type (fun(): nil)[]
  if props.flags ~= nil and #props.flags > 0 then
    for _, flag in ipairs(props.flags) do
      ---@cast flag                     era.view.picker.result.IFlagItemRaw
      local raw_disabled = flag.disabled ---@type boolean|nil|(fun(): boolean)
      local callback = flag.callback ---@type fun(): nil
      local snapshot = flag.snapshot ---@type fun(): boolean, string

      local disabled ---@type fun(): boolean
      if raw_disabled == nil or raw_disabled == false then
        disabled = stl.fn.falsy
      elseif raw_disabled == true then
        disabled = stl.fn.truthy
      else
        ---@return boolean
        disabled = function()
          return raw_disabled()
        end
      end

      local callback_fn, unregister = dot.G.register_anonymous_fn(callback)
      unregister_fns[#unregister_fns + 1] = unregister

      ---@type era.view.picker.result.IFlagItem
      local item = {
        desc = flag.desc,
        callback = callback_fn,
        disabled = disabled,
        snapshot = snapshot,
      }
      flags[#flags + 1] = item
    end
  end

  local position = "f_wl" ---@type stl.t.NvimbarPositionEnum

  local self = setmetatable({}, M)

  local result_nvimbar ---@type era.m.nvimbar.Nvimbar|nil
  if props.winbar ~= false then
    result_nvimbar = Nvimbar.new({
      name = string.format("%s#winline", fullname),
      comp_sep = "",
      comp_sep_hlname = winline_hl,
      comp_sep_hlname_active = winline_hl,
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
          vim.api.nvim_set_option_value("winbar", result, { win = winnr, scope = "local" })
        end
      end,
    })
      :place({
        position = "left",
        priority = 100,
        component = c.lazy(function()
          return c.picker.result_flags(position, flags, flags_start_index)
        end),
      })
      :place({
        position = "right",
        priority = 100,
        component = c.lazy(function()
          return c.picker.result_pos(position, _o_lnum_current, _o_lnum_total)
        end),
      })

    if status ~= nil then
      result_nvimbar:place({
        position = "center",
        priority = 200,
        component = c.lazy(function()
          return c.picker.result_status(position, status)
        end),
      })
    end
  end

  ---@type stl.c.Scheduler
  local scheduler_lnum_current = stl.c.Scheduler.new({
    name = string.format("%s#lnum_current", fullname),
    mode = "throttle",
    delay = 32,
    timeout = 0,
    silent = stl.fn.falsy,
    value = stl.c.Observable.from_value(true),
    task = function()
      local bufnr = self._bufnr ---@type integer|nil
      if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
        local group = dot.var.sign.GROUP_PICKER_RESULT_CURRENT ---@type string
        local signnr = dot.var.sign.NR_PICKER_RESULT_CURRENT ---@type integer
        local lnum = _o_lnum_current:snapshot() ---@type integer
        local lnum_present = _o_lnum_present:snapshot() ---@type integer

        pcall(vim.fn.sign_unplace, group, { id = signnr, buffer = bufnr })
        if lnum > 0 then
          local sign = dot.var.sign.PICKER_RESULT_CURRENT ---@type string
          local frame = native_tree:frame()
          local id = frame and frame:node_at(lnum)
          local flags = frame and id and frame:flags(id)
          if flags and flags.marked then
            sign = dot.var.sign.PICKER_RESULT_SELECTED_CURRENT
          elseif lnum == lnum_present then
            sign = dot.var.sign.PICKER_RESULT_PRESENT_CURRENT
          end
          pcall(vim.fn.sign_place, signnr, group, sign, bufnr, { lnum = lnum, priority = 50 })
        end
      end
    end,
  })

  ---@type stl.c.Scheduler
  local scheduler_lnum_present = stl.c.Scheduler.new({
    name = string.format("%s#lnum_present", fullname),
    mode = "debounce",
    delay = 64,
    timeout = 0,
    silent = stl.fn.falsy,
    value = stl.c.Observable.from_value(true),
    task = function()
      local bufnr = self._bufnr ---@type integer|nil
      if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
        local group = dot.var.sign.GROUP_PICKER_RESULT_PRESENT ---@type string
        local signnr = dot.var.sign.NR_PICKER_RESULT_PRESENT ---@type integer
        local lnum_present = _o_lnum_present:snapshot() ---@type integer

        pcall(vim.fn.sign_unplace, group, { id = signnr, buffer = bufnr })
        if lnum_present > 0 then
          local sign = dot.var.sign.PICKER_RESULT_PRESENT ---@type string
          pcall(vim.fn.sign_place, signnr, group, sign, bufnr, { lnum = lnum_present, priority = 30 })
        end
      end
    end,
  })

  ---@type stl.c.Scheduler
  local scheduler_content = stl.c.Scheduler.new({
    name = string.format("%s#content", fullname),
    mode = "debounce",
    delay = 0,
    timeout = 0,
    silent = stl.fn.falsy,
    value = stl.c.Observable.from_value(true),
    task = function()
      local bufnr = self._bufnr ---@type integer|nil
      if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
        return
      end

      local ok, error = pcall(draw, bufnr)
      if not ok then
        stl.reporter.error({ from = fullname, subject = "Treeview", message = tostring(error) })
      end
    end,
  })

  self.fullname = name
  self.draw = function(bufnr)
    local future = draw(bufnr)
    if not future then
      return Future.resolve(nil)
    end
    return future:then_(function(reply)
      if reply and reply.kind == "Superseded" then
        return native_tree:ready()
      end
      return reply
    end)
  end
  self._tree = native_tree
  self._on_drawed = on_drawed
  self.keymaps = keymaps
  self.lnum_current = _o_lnum_current
  self.lnum_present = _o_lnum_present
  self.lnum_total = _o_lnum_total

  self._disposed = false
  self._bufnr = nil
  self._winnr = nil
  self._augroup_CursorMoved = augroup_CursorMoved
  self._nvimbar = result_nvimbar
  self._scheduler_content = scheduler_content
  self._scheduler_lnum_current = scheduler_lnum_current
  self._scheduler_lnum_present = scheduler_lnum_present
  self._unregister_fns = unregister_fns

  stl.fn.observe({ _o_lnum_total }, function()
    local winnr = self._winnr ---@type integer|nil
    if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
      local lnum_total = _o_lnum_total:snapshot() ---@type integer
      vim.api.nvim_set_option_value("cursorline", lnum_total > 0, { win = winnr, scope = "local" })
      self:mark_nvimbar_dirty()
    end
  end, true)

  stl.fn.observe({ _o_lnum_current }, function()
    if self._disposed then
      return
    end

    local winnr = self._winnr ---@type integer|nil
    if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
      local cursor = vim.api.nvim_win_get_cursor(winnr) ---@type integer[]
      local lnum_current = _o_lnum_current:snapshot() ---@type integer
      if cursor[1] ~= lnum_current and native_tree.view then
        native_tree.view:set_cursor(lnum_current)
      end
      self:mark_nvimbar_dirty()
    end
    self._scheduler_lnum_current:schedule()
  end, true)

  stl.fn.observe({ _o_lnum_present }, function()
    if not self._disposed then
      self._scheduler_lnum_present:schedule()
    end
  end, true)

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
  local lnum_current = self.lnum_current ---@type stl.c.Observable
  local lnum_present = self.lnum_present ---@type stl.c.Observable
  local lnum_total = self.lnum_total ---@type stl.c.Observable
  local augroup_CursorMoved = self._augroup_CursorMoved ---@type integer
  local owned_nvimbar = self._nvimbar ---@type era.m.nvimbar.Nvimbar|nil
  local scheduler_content = self._scheduler_content ---@type stl.c.Scheduler
  local scheduler_lnum_current = self._scheduler_lnum_current ---@type stl.c.Scheduler
  local scheduler_lnum_present = self._scheduler_lnum_present ---@type stl.c.Scheduler
  local unregister_fns = self._unregister_fns ---@type (fun(): nil)[]

  self.draw = nil
  self._tree, self._on_drawed = nil, nil
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
  self._unregister_fns = nil

  local ok1, error1 = pcall(lnum_current.dispose, lnum_current)
  local ok2, error2 = pcall(lnum_present.dispose, lnum_present)
  local ok3, error3 = pcall(lnum_total.dispose, lnum_total)
  local ok4, error4 = pcall(stl.nvim.win.close, winnr)
  local ok5, error5 = pcall(stl.nvim.buf.close, bufnr)
  local ok6, error6 = pcall(vim.api.nvim_clear_autocmds, { group = augroup_CursorMoved })
  local ok7, error7 = pcall(function()
    if owned_nvimbar then
      owned_nvimbar:dispose()
    end
  end)
  local ok8, error8 = pcall(scheduler_content.dispose, scheduler_content)
  local ok9, error9 = pcall(scheduler_lnum_current.dispose, scheduler_lnum_current)
  local ok10, error10 = pcall(scheduler_lnum_present.dispose, scheduler_lnum_present)
  local ok11, error11 = pcall(function()
    for _, unregister in ipairs(unregister_fns) do
      unregister()
    end
  end)
  if not (ok1 and ok2 and ok3 and ok4 and ok5 and ok6 and ok7 and ok8 and ok9 and ok10 and ok11) then
    stl.reporter.error({
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

  vim.api.nvim_set_option_value("buflisted", false, { buf = bufnr })
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = bufnr })
  vim.api.nvim_set_option_value("filetype", stl.filetype.UX_PICKER_RESULT, { buf = bufnr })
  vim.api.nvim_set_option_value("swapfile", false, { buf = bufnr })
  vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })

  stl.nvim.fn.bindkeys(self.keymaps, { bufnr = bufnr, nowait = true, noremap = true, silent = true })

  self._scheduler_content:schedule({ immediate = true })
  return bufnr, true
end

---@param winopts                       era.view.picker.result.IWinOpts
---@param dimension                     dot.t.IWinDimension,
---@return integer
---@return boolean
function M:create_win(winopts, dimension)
  self:__health__()

  local winnr = self._winnr ---@type integer|nil
  if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
    return winnr, false
  end

  local bufnr, created = self:create_buf()
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
    zindex = winopts.zindex,
  }
  winnr = vim.api.nvim_open_win(bufnr, false, wincfg)
  self._winnr = winnr

  vim.w[winnr].wintype = stl.e.WinTypeEnum.PICKER_RESULT

  local lnum_total = self.lnum_total:snapshot() ---@type integer
  vim.api.nvim_set_option_value("cursorline", lnum_total > 0, { win = winnr, scope = "local" })
  vim.api.nvim_set_option_value("number", winopts.number, { win = winnr, scope = "local" })
  vim.api.nvim_set_option_value("relativenumber", winopts.number, { win = winnr, scope = "local" })
  vim.api.nvim_set_option_value("signcolumn", "yes", { win = winnr, scope = "local" })
  vim.api.nvim_set_option_value("spell", false, { win = winnr, scope = "local" })
  vim.api.nvim_set_option_value("winbar", "", { win = winnr, scope = "local" })
  self:mark_nvimbar_dirty()
  vim.api.nvim_set_option_value("winblend", 0, { win = winnr, scope = "local" })
  vim.api.nvim_set_option_value("winfixbuf", true, { win = winnr, scope = "local" })
  vim.api.nvim_set_option_value("winhighlight", winopts.winhighlight, { win = winnr, scope = "local" })
  vim.api.nvim_set_option_value("wrap", false, { win = winnr, scope = "local" })

  self._tree:mount(winnr, bufnr, function(frame)
    if self._disposed or self._winnr ~= winnr or not vim.api.nvim_win_is_valid(winnr) then
      return
    end
    local header = frame:header()
    self.lnum_total:next(header.row_count)
    -- A Visual gesture can be ahead of the native cursor acknowledgement; preserve its surface endpoint.
    self.lnum_current:next(header.row_count > 0 and vim.api.nvim_win_get_cursor(winnr)[1] or 0)
    self._scheduler_lnum_current:schedule()
    self._on_drawed(bufnr)
  end, function()
    vim.api.nvim_set_option_value("number", winopts.number, { win = winnr })
    vim.api.nvim_set_option_value("relativenumber", winopts.number, { win = winnr })
    vim.api.nvim_set_option_value("signcolumn", "yes", { win = winnr })
  end)
  if not created then
    self._scheduler_content:schedule({ immediate = true })
  end
  return winnr, true
end

----------------------------------------------------------------------------------------------------

---@return era.view.PickerResult
function M:focus()
  self:__health__()
  local winnr = self._winnr ---@type integer|nil
  if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) and winnr ~= vim.api.nvim_get_current_win() then
    vim.api.nvim_set_current_win(winnr)
  end
  return self
end

---@return era.view.PickerResult
function M:hide()
  self:__health__()
  local winnr = self._winnr ---@type integer|nil

  self._winnr = nil
  self._tree:unmount(true)

  local ok1, error1 = pcall(stl.nvim.win.close, winnr)
  if not ok1 then
    stl.reporter.error({
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
---@return era.view.PickerResult
function M:resize(dimension)
  self:__health__()

  self:mark_nvimbar_dirty()

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

---@return era.view.PickerResult
function M:mark_content_dirty()
  self:__health__()
  self._scheduler_content:schedule()
  return self
end

---@return era.view.PickerResult
function M:mark_nvimbar_dirty()
  self:__health__()
  if self._nvimbar then
    self._nvimbar:refresh()
  end
  return self
end

---@param step                          integer
---@return nil
function M:movedown(step)
  local total = self.lnum_total:snapshot() ---@type integer
  if total > 1 then
    local lnum = self.lnum_current:snapshot() ---@type integer
    local next_lnum = stl.fn.navigate_circular(lnum, step, total) ---@type integer
    self:set_lnum_current(next_lnum)
  end
end

---@param next_lnum                     integer
---@return nil
function M:moveto(next_lnum)
  local total = self.lnum_total:snapshot() ---@type integer
  if total > 1 then
    next_lnum = math.min(total, math.max(0, next_lnum)) ---@type integer
    self:set_lnum_current(next_lnum)
  end
end

---@param lnum                          integer
---@return era.view.PickerResult
function M:set_lnum_current(lnum)
  self:__health__()
  local total = self.lnum_total:snapshot() ---@type integer
  lnum = math.min(total, math.max(0, lnum)) ---@type integer
  if self._tree.view then
    self._tree.view:set_cursor(lnum)
  end
  self.lnum_current:next(lnum, { force = true })
  return self
end

---@param lnum                          integer
---@return era.view.PickerResult
function M:set_lnum_present(lnum)
  self:__health__()
  local total = self.lnum_total:snapshot() ---@type integer
  lnum = math.min(total, math.max(0, lnum)) ---@type integer
  self.lnum_present:next(lnum, { force = true })
  return self
end

---@return era.view.PickerResult
function M:refresh_signs()
  self:__health__()
  self._scheduler_lnum_current:schedule()
  self._scheduler_lnum_present:schedule()
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
