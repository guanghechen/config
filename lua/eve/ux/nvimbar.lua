local __module_name__ = "eve.ux.nvimbar" ---@type string

---@alias eve.ux.nvimbar.Position
---| 'f_sl'
---| 'f_tl'
---| 'f_wl'

---@class eve.ux.nvimbar.IPresetContext
---@field public winnr                  ?integer

---@class eve.ux.nvimbar.IContext
---@field public tabnr                  integer
---@field public winnr                  integer
---@field public bufnr                  integer
---@field public cwd                    string
---@field public filename               string
---@field public filepath               string
---@field public fileicon               string
---@field public fileicon_hl            string
---@field public filetype               string
---@field public mode                   eve.e.VimModeName
---@field public mode_name              string
---@field public git_branch             string|nil

---@class eve.ux.nvimbar.IRawComponent
---@field public atomic                 boolean
---@field public name                   string
---@field public tight                  ?boolean
---@field public condition              ?fun(context: eve.ux.nvimbar.IContext, remain_width: integer): boolean
---@field public render                 fun(context: eve.ux.nvimbar.IContext, remain_width: integer): string, string, boolean
---@field public will_change            ?fun(context: eve.ux.nvimbar.IContext, prev_context: eve.ux.nvimbar.IContext|nil, remain_width: integer): boolean

---@class eve.ux.nvimbar.IComponent
---@field public last_render_context    eve.ux.nvimbar.IContext|nil
---@field public last_result_full       boolean
---@field public last_result_hltext     string
---@field public last_result_text       string
---@field public last_result_width      integer
---@field public atomic                 boolean
---@field public name                   string
---@field public position               eve.e.NvimbarCompPosition
---@field public priority               integer
---@field public tight                  boolean
---@field public condition              fun(context: eve.ux.nvimbar.IContext, remain_width: integer): boolean
---@field public render                 fun(context: eve.ux.nvimbar.IContext, remain_width: integer): string, string, boolean
---@field public will_change            fun(context: eve.ux.nvimbar.IContext, prev_context: eve.ux.nvimbar.IContext|nil, remain_width: integer): boolean

---@class eve.ux.nvimbar.IItem
---@field public name                   string
---@field public position               eve.e.NvimbarCompPosition

---@class eve.ux.nvimbar.IProps
---@field public name                   string
---@field public comp_sep               string
---@field public comp_sep_hlname        string
---@field public comp_sep_hlname_active string
---@field public delay           ?integer
---@field public silent                 ?fun(): boolean
---@field public get_max_width          fun(): integer
---@field public get_preset_context     ?fun(): eve.ux.nvimbar.IPresetContext
---@field public is_active              fun(context: eve.ux.nvimbar.IContext): boolean
---@field public on_fulfilled           ?fun(result: string): nil
---@field public validate               ?fun(): string|nil

---@class eve.ux.Nvimbar
---@field public name                   string
---@field protected _value              eve.std.collection.Observable
---@field protected _disposed           boolean
---@field protected _sep                string
---@field protected _sep_active         string
---@field protected _sep_width          integer
---@field protected _components         eve.ux.nvimbar.IComponent[]
---@field protected _orders             integer[]
---@field protected _scheduler          eve.std.collection.Scheduler
---@field protected _get_max_width      fun(): integer
---@field protected _get_preset_context fun(): eve.ux.nvimbar.IPresetContext
---@field protected _isactive          fun(context: eve.ux.nvimbar.IContext): boolean
local M = {}
M.__index = M

---@param preset_context                eve.ux.nvimbar.IPresetContext
---@return eve.ux.nvimbar.IContext
local function build_context(preset_context)
  local mode, mode_name = eve.constant.hlgroup.common.resolve_mode()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local winnr = preset_context.winnr or vim.api.nvim_tabpage_get_win(tabnr) ---@type integer
  local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  local cwd = eve.path.cwd() ---@type string
  local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
  local filename = eve.path.basename(filepath) ---@type string
  local filetype = vim.bo[bufnr].filetype ---@type string
  local fileicon, fileicon_hl = eve.fn.fileicon(filename) ---@type string, string

  local git = vim.b[bufnr].gitsigns_status_dict
  local git_branch = git and git.head or nil ---@type string|nil

  ---@type eve.ux.nvimbar.IContext
  local context = {
    tabnr = tabnr,
    winnr = winnr,
    bufnr = bufnr,
    cwd = cwd,
    filename = filename,
    filepath = filepath,
    fileicon = fileicon,
    fileicon_hl = fileicon_hl,
    filetype = filetype,
    mode = mode,
    mode_name = mode_name,
    git_branch = git_branch,
  }
  return context
end

---@param props                         eve.ux.nvimbar.IProps
---@return eve.ux.Nvimbar
function M.new(props)
  local name = props.name ---@type string
  local comp_sep = props.comp_sep ---@type string
  local comp_sep_hlname = props.comp_sep_hlname ---@type string
  local comp_sep_hlname_active = props.comp_sep_hlname_active ---@type string
  local delay = props.delay or 20 ---@type integer
  local silent = props.silent ---@type fun(): boolean
  local get_max_width = props.get_max_width ---@type fun(): integer
  local value = eve.std.Observable.from_value("") ---@type eve.std.collection.Observable

  ---@type fun(): eve.ux.nvimbar.IPresetContext
  local get_preset_context = props.get_preset_context or function()
    return {}
  end

  local isactive = props.is_active ---@type fun(context: eve.ux.nvimbar.IContext): boolean
  local on_fulfilled = props.on_fulfilled or eve.std.fn.noop ---@type fun(result: string): nil
  local validate = props.validate or eve.std.fn.noop ---@type fun(): string|nil

  local self = setmetatable({}, M)

  ---@type eve.std.collection.Scheduler
  local scheduler = eve.std.Scheduler.new({
    name = string.format("%s | %s", name, __module_name__),
    mode = "throttle",
    delay = delay,
    timeout = 0,
    value = value,
    silent = silent,
    task = function(scheduler, _, callback)
      local validate_message = validate() ---@type string|nil
      if validate_message ~= nil then
        callback(false, string.format("[%s | %s] Invalid: %s", name, __module_name__, validate_message))
        return
      end

      local last_result = scheduler:snapshot() ---@type string|nil

      ---@diagnostic disable-next-line: invisible
      local result = self:__render__(false) ---@type string
      callback(true, result)

      --- Trigger rerender need called after the callback executed,
      --- so we can get the latest value from the :snapshot()
      if last_result ~= result then
        vim.schedule(function()
          on_fulfilled(result)
        end)
      end
    end,
  })

  self.name = name
  self._value = value
  self._disposed = false
  self._sep = eve.nvim.txt(comp_sep, comp_sep_hlname)
  self._sep_active = eve.nvim.txt(comp_sep, comp_sep_hlname_active)
  self._sep_width = vim.api.nvim_strwidth(comp_sep)
  self._components = {}
  self._orders = {}
  self._scheduler = scheduler
  self._get_max_width = get_max_width
  self._get_preset_context = get_preset_context
  self._isactive = isactive
  return self
end

---@return boolean
function M:isdisposed()
  return self._disposed
end

---@return nil
function M:dispose()
  if self._disposed then
    return
  end
  self._disposed = true

  self._scheduler:dispose()
  self._value:dispose()

  self._sep = nil
  self._sep_active = nil
  self._sep_width = nil
  self._components = nil
  self._orders = nil
  self._scheduler = nil
  self._get_max_width = nil
  self._get_preset_context = nil
  self._isactive = nil
end

---@return nil
function M:cancel_render()
  self:__health__()
  self._scheduler:cancel()
end

---@param immediate                     ?boolean
---@return string
function M:render(immediate)
  self:__health__()

  if immediate then
    local result = self:__render__(false) ---@type string
    self._value:next(result)
    return result
  end

  self._scheduler:schedule()
  return self._scheduler:snapshot() or ""
end

---@param position                      eve.e.NvimbarCompPosition
---@param raw_component                 eve.ux.nvimbar.IRawComponent
---@param priority                      ?integer
---@return eve.ux.Nvimbar
function M:place(position, raw_component, priority)
  self:__health__()

  priority = priority or 1 ---@type integer
  local name = raw_component.name ---@type string

  if position ~= "left" and position ~= "center" and position ~= "right" then
    eve.reporter.error({
      from = __module_name__,
      subject = "place",
      message = "Bad component position.",
      details = { name = name, position = position, priority = priority, component = raw_component },
    })
    return self
  end

  local components = self._components ---@type eve.ux.nvimbar.IComponent[]
  local orders = self._orders ---@type integer[]
  local k = #components ---@type integer

  ---@type eve.ux.nvimbar.IComponent
  local component = {
    last_result_full = false,
    last_render_context = nil,
    last_result_hltext = "",
    last_result_text = "",
    last_result_width = 0,
    atomic = raw_component.atomic,
    name = name,
    position = position,
    priority = priority,
    tight = not not raw_component.tight,
    render = raw_component.render,
    will_change = raw_component.will_change or eve.std.fn.truthy,
    condition = raw_component.condition or eve.std.fn.truthy,
  }
  components[k + 1] = component

  while k >= 1 do
    local order = orders[k] ---@type integer
    if components[order].priority >= priority then
      break
    end
    orders[k + 1] = order
    k = k - 1
  end
  orders[k + 1] = #components

  return self
end

---@return string
function M:snapshot()
  self:__health__()
  return self._scheduler:snapshot() or ""
end

---@protected
---@return nil
function M:__health__()
  if self._disposed then
    local message = string.format("[%s#%s] already been disposed.", __module_name__, self.name) ---@type string
    error(message)
  end
end

---@protected
---@param force                         boolean
---@return string
function M:__render__(force)
  local preset_context = self._get_preset_context() ---@type eve.ux.nvimbar.IPresetContext
  local context = build_context(preset_context) ---@type eve.ux.nvimbar.IContext

  local sep = self._isactive(context) and self._sep_active or self._sep ---@type string
  local width_sep = self._sep_width ---@type integer
  local width_full = self._get_max_width() ---@type integer

  local wl = width_sep ---@type integer
  local wc = width_sep + width_sep ---@type integer
  local wr = width_sep ---@type integer
  local width_remain = width_full - wl - wc - wr ---@type integer

  local components = self._components ---@type eve.ux.nvimbar.IComponent[]
  local orders = self._orders ---@type integer[]
  local hltexts = {} ---@type string[]

  local N = #orders ---@type integer
  local hl, hc, hr = false, false, false ---@type boolean, boolean, boolean
  for _, order in ipairs(orders) do
    hltexts[order] = ""
    local component = components[order] ---@type eve.ux.nvimbar.IComponent
    local ok, hltext, width = pcall(function()
      if not component.condition(context, width_remain) then
        return "", 0
      end

      if
        force
        or (not component.atomic and (not component.last_result_full or component.last_result_width > width_remain))
        or component.will_change(context, component.last_render_context, width_remain)
      then
        local text, hltext, full = component.render(context, width_remain)
        local width = vim.api.nvim_strwidth(text) ---@type integer
        component.last_result_hltext = hltext
        component.last_result_text = text
        component.last_result_width = width
        component.last_result_full = full
        component.last_render_context = context
      end
      return component.last_result_hltext, component.last_result_width
    end)

    if ok then
      if width > 0 and width <= width_remain then
        local tight = component.tight ---@type boolean
        local position = component.position ---@type eve.e.NvimbarCompPosition
        if position == "left" then
          if not hl or tight then
            hl = true
            hltexts[order] = hltext
            wl = wl + width
            width_remain = width_remain - width
          else
            hltexts[order] = sep .. hltext
            wl = wl + width + width_sep
            width_remain = width_remain - width - width_sep
          end
        elseif position == "center" then
          if not hc or tight then
            hc = true
            hltexts[order] = hltext
            wc = wc + width
            width_remain = width_remain - width
          else
            hltexts[order] = sep .. hltext
            wc = wc + width + width_sep
            width_remain = width_remain - width - width_sep
          end
        elseif position == "right" then
          if not hr or tight then
            hr = true
            hltexts[order] = hltext
            wr = wr + width
            width_remain = width_remain - width
          else
            hltexts[order] = hltext .. sep
            wr = wr + width + width_sep
            width_remain = width_remain - width - width_sep
          end
        end
      end
    else
      eve.reporter.error({
        from = __module_name__,
        subject = "render",
        message = "Encounter error while render the nvimbar component.",
        details = {
          bufnr = context.bufnr,
          context = context,
          component = component,
          error = hltext,
        },
      })
    end
  end

  local tl, tc, tr = "", "", "" ---@type string, string, string
  for i = 1, N, 1 do
    local hltext = hltexts[i] ---@type string
    local component = components[i] ---@type eve.ux.nvimbar.IComponent
    local position = component.position ---@type eve.e.NvimbarCompPosition
    if position == "left" then
      tl = tl .. hltext
    elseif position == "center" then
      tc = tc .. hltext
    elseif position == "right" then
      tr = hltext .. tr
    end
  end

  local width_half_left = math.floor(width_full / 2) ---@type integer
  local width_padding_left = width_half_left - wl - math.floor(wc / 2) ---@type integer
  if width_padding_left > 0 and width_padding_left + 1 < width_remain then
    local width_padding_right = width_remain - width_padding_left ---@type integer
    local padding_left = string.rep(" ", width_padding_left) ---@type string
    local padding_right = string.rep(" ", width_padding_right) ---@type string
    return tl .. sep .. padding_left .. sep .. tc .. sep .. padding_right .. sep .. tr
  else
    return tl .. sep .. "%=" .. sep .. tc .. sep .. "%=" .. sep .. tr
  end
end

return M
