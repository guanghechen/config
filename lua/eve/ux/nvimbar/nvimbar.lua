local __module_name__ = "eve.ux.nvimbar" ---@type string

---@class eve.ux.nvimbar.INvimbarPresetContext
---@field public winnr                  ?integer

---@alias eve.ux.nvimbar.IGetNvimbarPresetContext
---| fun(): eve.ux.nvimbar.INvimbarPresetContext|nil

---@class eve.ux.nvimbar.INvimbarContext
---@field public winnr                  integer
---@field public bufnr                  integer
---@field public cwd                    string
---@field public filename               string
---@field public filepath               string
---@field public fileicon               string
---@field public fileicon_hl            string
---@field public filetype               string
---@field public mode                   std.e.VimModeName
---@field public mode_name              string
---@field public git_branch             string|nil

---@class eve.ux.nvimbar.IItem
---@field public name                   string
---@field public position               std.e.NvimbarCompPosition

---@class eve.ux.nvimbar.INvimbarProps
---@field public name                   string
---@field public comp_sep               string
---@field public comp_sep_hlname        string
---@field public comp_sep_hlname_active string
---@field public delay                  ?integer
---@field public silent                 ?fun(): boolean
---@field public get_max_width          fun(): integer
---@field public get_preset_context     ?eve.ux.nvimbar.IGetNvimbarPresetContext
---@field public is_active              fun(context: eve.ux.nvimbar.INvimbarContext): boolean
---@field public on_fulfilled           ?fun(result: string): nil
---@field public validate               ?fun(): string|nil

---@class eve.ux.nvimbar.Nvimbar
---@field public name                   string
---@field protected _value              std.collection.Observable
---@field protected _disposed           boolean
---@field protected _sep                string
---@field protected _sep_active         string
---@field protected _sep_width          integer
---@field protected _components         eve.ux.nvimbar.IComponent[]
---@field protected _orders             integer[]
---@field protected _scheduler          std.collection.Scheduler
---@field protected _get_max_width      fun(): integer
---@field protected _get_preset_context eve.ux.nvimbar.IGetNvimbarPresetContext
---@field protected _isactive           fun(context: eve.ux.nvimbar.INvimbarContext): boolean
local M = {}
M.__index = M

---@param preset_context                eve.ux.nvimbar.INvimbarPresetContext
---@return eve.ux.nvimbar.INvimbarContext|nil
local function build_context(preset_context)
  local winnr = preset_context.winnr ---@type integer|nil
  if winnr == nil or not vim.api.nvim_win_is_valid(winnr) then
    return nil
  end

  local mode, mode_name = eve.constant.hlgroup.common.resolve_mode()
  local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  local cwd = std.path.cwd() ---@type string
  local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
  local filename = std.path.basename(filepath) ---@type string
  local filetype = vim.bo[bufnr].filetype ---@type string
  local fileicon, fileicon_hl = eve.fn.fileicon(filename) ---@type string, string

  local git = vim.b[bufnr].gitsigns_status_dict
  local git_branch = git and git.head or nil ---@type string|nil

  ---@type eve.ux.nvimbar.INvimbarContext
  local context = {
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

---@param props                         eve.ux.nvimbar.INvimbarProps
---@return eve.ux.nvimbar.Nvimbar
function M.new(props)
  local name = props.name ---@type string
  local comp_sep = props.comp_sep ---@type string
  local comp_sep_hlname = props.comp_sep_hlname ---@type string
  local comp_sep_hlname_active = props.comp_sep_hlname_active ---@type string
  local delay = props.delay or 20 ---@type integer
  local silent = props.silent ---@type fun(): boolean
  local get_max_width = props.get_max_width ---@type fun(): integer
  local value = std.Observable.from_value("") ---@type std.collection.Observable

  ---@type eve.ux.nvimbar.IGetNvimbarPresetContext
  local get_preset_context = props.get_preset_context
    or function()
      local winnr = vim.api.nvim_get_current_win() ---@type integer
      ---@type eve.ux.nvimbar.INvimbarPresetContext
      return {
        winnr = winnr,
      }
    end

  local isactive = props.is_active ---@type fun(context: eve.ux.nvimbar.INvimbarContext): boolean
  local on_fulfilled = props.on_fulfilled or std.fn.noop ---@type fun(result: string): nil
  local validate = props.validate or std.fn.noop ---@type fun(): string|nil

  local self = setmetatable({}, M)

  ---@type std.collection.Scheduler
  local scheduler = std.Scheduler.new({
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
      local result = self:__render__(false) ---@type string|nil
      if result == nil then
        callback(false)
        return
      end

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
    local result = self:__render__(false) ---@type string|nil
    if result ~= nil then
      self._value:next(result)
      return result
    end
    return self._scheduler:snapshot() or ""
  end

  self._scheduler:schedule()
  return self._scheduler:snapshot() or ""
end

---@param position                      std.e.NvimbarCompPosition
---@param raw_component                 eve.ux.nvimbar.IRawComponent
---@param priority                      ?integer
---@return eve.ux.nvimbar.Nvimbar
function M:place(position, raw_component, priority)
  self:__health__()

  priority = priority or 1 ---@type integer
  local name = raw_component.name ---@type string

  if position ~= "left" and position ~= "center" and position ~= "right" then
    std.reporter.error({
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
    will_change = raw_component.will_change or std.fn.truthy,
    condition = raw_component.condition or std.fn.truthy,
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
---@return string|nil
function M:__render__(force)
  local preset_context = self._get_preset_context() or {} ---@type eve.ux.nvimbar.INvimbarPresetContext
  local context = build_context(preset_context) ---@type eve.ux.nvimbar.INvimbarContext|nil
  if context == nil then
    return nil
  end

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
        local position = component.position ---@type std.e.NvimbarCompPosition
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
      std.reporter.error({
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
    local position = component.position ---@type std.e.NvimbarCompPosition
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
