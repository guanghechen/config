---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.nvimbar" ---@type string

local Component = require("era.m.nvimbar.component")
local queue = require("era.m.nvimbar.queue")
local hub = require("stl.c.signal_hub").new()
local changed_signal = hub:register_signal("nvimbar.component.changed")
local stale_signal = hub:register_signal("nvimbar.component.stale")

---@param from                          stl.c.signal_hub.IRole
---@param to                            stl.c.signal_hub.IRole
---@param signal                        string
---@param context                       ?era.m.nvimbar.INvimbarContext
---@return nil
local function notify(from, to, signal, context)
  local _, errors = hub:emit(from, { signal = signal, scope = "nvimbar", payload = context, track = { to = to } })
  if errors then
    for _, failure in ipairs(errors) do
      stl.reporter.error({
        from = __module_name__,
        subject = "signal",
        details = { signal = signal, error = failure.error },
      })
    end
  end
end

---@class era.m.nvimbar.INvimbarPresetContext
---@field public winnr                  ?integer

---@alias era.m.nvimbar.IGetNvimbarPresetContext
---| fun(): era.m.nvimbar.INvimbarPresetContext|nil

---@class era.m.nvimbar.INvimbarContext
---@field public winnr                  integer
---@field public bufnr                  integer
---@field public tabnr                  integer
---@field public cwd                    string
---@field public filename               string
---@field public filepath               string
---@field public filetype               string
---@field public mode                   stl.t.VimModeNameEnum
---@field public mode_name              string
---@field public cursor                 integer[]
---@field public line_count             integer
---@field public changedtick            integer

---@class era.m.nvimbar.IItem
---@field public name                   string
---@field public position               dot.e.NvimbarCompPosition

---@class era.m.nvimbar.INvimbarProps
---@field public name                   string
---@field public comp_sep               string
---@field public comp_sep_hlname        string
---@field public comp_sep_hlname_active string
---@field public get_max_width          fun(): integer
---@field public get_preset_context     ?era.m.nvimbar.IGetNvimbarPresetContext
---@field public is_active              fun(context: era.m.nvimbar.INvimbarContext): boolean
---@field public on_fulfilled           ?fun(result: string, last_result: string|nil): nil
---@field public validate               ?fun(): string|nil
---@field public draw_interval          ?integer Milliseconds between publications; defaults to 16, zero only merges the current turn.

---@class era.m.nvimbar.IPlacement
---@field public position               dot.e.NvimbarCompPosition
---@field public priority               ?integer Defaults to 1.
---@field public component              era.m.nvimbar.IComponentSource
---@field public notify                 ?era.m.nvimbar.INotifyPolicy Replaces the raw component's notification policy.

---@class era.m.nvimbar.IPlacedComponent
---@field public source                 era.m.nvimbar.IComponentSource
---@field public runtime                era.m.nvimbar.Component
---@field public position               dot.e.NvimbarCompPosition
---@field public priority               integer
---@field public notify                 ?era.m.nvimbar.INotifyPolicy
---@field public role                   stl.c.signal_hub.IRole

---@class era.m.nvimbar.Nvimbar
---@field public fullname               string
---@field protected _value              string
---@field protected _drawn_snapshots    ?era.m.nvimbar.ISnapshot[]
---@field protected _disposed           boolean
---@field protected _sep                string
---@field protected _sep_active         string
---@field protected _sep_width          integer
---@field protected _components         era.m.nvimbar.IPlacedComponent[]
---@field protected _orders             integer[]
---@field protected _get_max_width      fun(): integer
---@field protected _get_preset_context era.m.nvimbar.IGetNvimbarPresetContext
---@field protected _isactive           fun(context: era.m.nvimbar.INvimbarContext): boolean
---@field protected _on_fulfilled       fun(result: string, last_result: string|nil): nil
---@field protected _validate           fun(): string|nil
---@field protected _publish_scheduled  ?table
---@field protected _publish_requested  boolean
---@field protected _draw_interval      integer
---@field protected _last_draw          ?number
---@field protected _has_changed        boolean
---@field protected _role               stl.c.signal_hub.IRole
---@field protected _props              era.m.nvimbar.INvimbarProps
---@field protected _forks              table<integer, era.m.nvimbar.Nvimbar>
---@field protected _parent             ?era.m.nvimbar.Nvimbar
---@field protected _winnr              ?integer
---@field protected _bufnr              ?integer
---@field protected _close_autocmd      ?integer
local M = {}
M.__index = M

---@param preset_context                era.m.nvimbar.INvimbarPresetContext
---@return era.m.nvimbar.INvimbarContext|nil
local function build_context(preset_context)
  local winnr = preset_context.winnr ---@type integer|nil
  if winnr == nil or not vim.api.nvim_win_is_valid(winnr) then
    return nil
  end

  local mode, mode_name = dot.theme.hlgroup.common.resolve_mode()
  local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  local cwd = dot.path.cwd() ---@type string
  local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
  local filename = yoz.path.basename(filepath) ---@type string
  local filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr }) ---@type string
  local tabnr = vim.api.nvim_win_get_tabpage(winnr) ---@type integer
  local cursor = vim.api.nvim_win_get_cursor(winnr) ---@type integer[]
  local line_count = vim.api.nvim_buf_line_count(bufnr) ---@type integer
  local changedtick = vim.api.nvim_buf_get_changedtick(bufnr) ---@type integer

  ---@type era.m.nvimbar.INvimbarContext
  local context = {
    winnr = winnr,
    bufnr = bufnr,
    tabnr = tabnr,
    cwd = cwd,
    filename = filename,
    filepath = filepath,
    filetype = filetype,
    mode = mode,
    mode_name = mode_name,
    cursor = cursor,
    line_count = line_count,
    changedtick = changedtick,
  }
  return context
end

---@param props                         era.m.nvimbar.INvimbarProps
---@return era.m.nvimbar.Nvimbar
function M.new(props)
  local name = props.name ---@type string
  local fullname = string.format("%s -> %s", name, __module_name__) ---@type string
  local comp_sep = props.comp_sep ---@type string
  local comp_sep_hlname = props.comp_sep_hlname ---@type string
  local comp_sep_hlname_active = props.comp_sep_hlname_active ---@type string
  local get_max_width = props.get_max_width ---@type fun(): integer
  local value = "" ---@type string
  local draw_interval = props.draw_interval ---@type integer|nil
  if draw_interval == nil then
    draw_interval = 16
  end
  assert(
    type(draw_interval) == "number" and draw_interval >= 0 and draw_interval % 1 == 0,
    "Invalid nvimbar draw interval"
  )

  ---@type era.m.nvimbar.IGetNvimbarPresetContext
  local get_preset_context = props.get_preset_context
    or function()
      local winnr = vim.api.nvim_get_current_win() ---@type integer
      ---@type era.m.nvimbar.INvimbarPresetContext
      return {
        winnr = winnr,
      }
    end

  local isactive = props.is_active ---@type fun(context: era.m.nvimbar.INvimbarContext): boolean
  local on_fulfilled = props.on_fulfilled or stl.fn.noop ---@type fun(result: string, last_result: string|nil): nil
  local validate = props.validate or stl.fn.noop ---@type fun(): string|nil

  local self = setmetatable({}, M)

  self.fullname = fullname
  self._value = value
  self._disposed = false
  self._sep = stl.nvim.fn.txt(comp_sep, comp_sep_hlname)
  self._sep_active = stl.nvim.fn.txt(comp_sep, comp_sep_hlname_active)
  self._sep_width = vim.api.nvim_strwidth(comp_sep)
  self._components = {}
  self._orders = {}
  self._get_max_width = get_max_width
  self._get_preset_context = get_preset_context
  self._isactive = isactive
  self._on_fulfilled = on_fulfilled
  self._validate = validate
  self._publish_scheduled = nil
  self._publish_requested = false
  self._draw_interval = draw_interval
  self._has_changed = false
  self._props = props
  self._forks = {}
  self._role = hub:register_role(fullname)
  hub:subscribe(self._role, { signal = changed_signal, scope = "nvimbar" }, function(message)
    if M.__is_current__(self, message.payload) then
      M.__publish__(self)
    else
      self:refresh()
    end
  end)
  hub:subscribe(self._role, { signal = stale_signal, scope = "nvimbar" }, function()
    self:refresh()
  end)
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
  if self._publish_scheduled then
    queue.unwatch(self._publish_scheduled)
  end
  hub:unregister_role(self._role)

  if self._close_autocmd ~= nil then
    vim.api.nvim_del_autocmd(self._close_autocmd)
  end
  local parent = self._parent ---@type era.m.nvimbar.Nvimbar|nil
  if parent ~= nil and parent._forks ~= nil and parent._forks[self._winnr] == self then
    parent._forks[self._winnr] = nil
  end
  local forks = self._forks ---@type table<integer, era.m.nvimbar.Nvimbar>
  self._forks = {}
  for _, fork in pairs(forks) do
    fork:dispose()
  end
  for _, component in ipairs(self._components) do
    component.runtime:dispose()
    hub:unregister_role(component.role)
  end

  self._value = nil
  self._drawn_snapshots = nil
  self._sep = nil
  self._sep_active = nil
  self._sep_width = nil
  self._components = nil
  self._orders = nil
  self._get_max_width = nil
  self._get_preset_context = nil
  self._isactive = nil
  self._on_fulfilled = nil
  self._validate = nil
  self._publish_scheduled = nil
  self._publish_requested = false
  self._last_draw = nil
  self._role = nil
  self._props = nil
  self._forks = nil
  self._parent = nil
  self._winnr = nil
  self._bufnr = nil
  self._close_autocmd = nil
end

---@return nil
function M:cancel_refresh()
  self:__health__()
  local tokens = {} ---@type stl.c.CancellationToken[]
  for _, component in ipairs(self._components) do
    local token = component.runtime:prepare_cancel()
    if token then
      tokens[#tokens + 1] = token
    end
  end
  -- Cleanup may request a new frame after every component has released its old work.
  for _, token in ipairs(tokens) do
    token:cancel()
  end
end

--- Synchronously lay out committed data without refreshing or publishing it.
---@return string
function M:render()
  self:__health__()

  local result = self:__render__() ---@type string|nil
  return result or ""
end

---@param placement                     era.m.nvimbar.IPlacement
---@return era.m.nvimbar.Nvimbar
function M:place(placement)
  self:__health__()

  local position = placement.position ---@type dot.e.NvimbarCompPosition
  local raw_component = placement.component ---@type era.m.nvimbar.IComponentSource
  local priority = placement.priority or 1 ---@type integer
  local name = type(raw_component) == "table" and raw_component.name or nil ---@type string|nil

  if position ~= "left" and position ~= "center" and position ~= "right" then
    stl.reporter.error({
      from = self.fullname,
      subject = "place",
      message = "Bad component position.",
      details = { name = name, position = position, priority = priority, component = raw_component },
    })
    return self
  end

  local components = self._components ---@type era.m.nvimbar.IPlacedComponent[]
  local orders = self._orders ---@type integer[]
  local k = #components ---@type integer
  local role ---@type stl.c.signal_hub.IRole
  local notification = placement.notify
  if notification ~= nil then
    notification = vim.deepcopy(notification)
  end
  local runtime = Component.new(raw_component, function(context)
    if not self._disposed then
      notify(role, self._role, changed_signal, context)
    end
  end, function(context)
    return self:__is_current__(context)
  end, function()
    if not self._disposed then
      notify(role, self._role, stale_signal)
    end
  end, notification)
  role = hub:register_role(string.format("%s:component:%d", self.fullname, k + 1))

  ---@type era.m.nvimbar.IPlacedComponent
  local component = {
    source = raw_component,
    position = position,
    priority = priority,
    notify = notification,
    runtime = runtime,
    role = role,
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
  return self._value or ""
end

--- Request component data; completion schedules publication independently.
---@param force                         ?boolean
---@return era.m.nvimbar.Nvimbar
function M:refresh(force)
  self:__health__()

  for _, fork in pairs(self._forks) do
    fork:refresh(force)
  end
  local context = self:__context__() ---@type era.m.nvimbar.INvimbarContext|nil
  if context == nil then
    self:cancel_refresh()
    return self
  end
  for _, order in ipairs(self._orders) do
    self._components[order].runtime:request(context, force)
  end
  self:__publish__(true)
  return self
end

--- Window copies own their snapshots and publication target.
---@param winnr                         integer
---@param padding                       ?integer
---@return era.m.nvimbar.Nvimbar
function M:fork(winnr, padding)
  self:__health__()

  assert(vim.api.nvim_win_is_valid(winnr), "Invalid nvimbar fork")
  local bufnr = vim.api.nvim_win_get_buf(winnr)
  local existing = self._forks[winnr]
  if existing and existing._bufnr == bufnr then
    return existing
  elseif existing then
    existing:dispose()
  end
  local fork = M.new(vim.tbl_extend("force", self._props, {
    name = self._props.name .. ":" .. winnr,
    get_preset_context = function()
      return { winnr = winnr }
    end,
    get_max_width = function()
      return math.max(0, vim.api.nvim_win_get_width(winnr) - (padding or 0))
    end,
    is_active = function()
      return vim.api.nvim_get_current_win() == winnr
    end,
    validate = function()
      if not vim.api.nvim_win_is_valid(winnr) or vim.api.nvim_win_get_buf(winnr) ~= bufnr then
        return "The fork window no longer displays its buffer."
      end
    end,
    on_fulfilled = function(result)
      if
        vim.api.nvim_win_is_valid(winnr)
        and vim.api.nvim_get_option_value("winbar", { win = winnr, scope = "local" }) ~= result
      then
        vim.api.nvim_set_option_value("winbar", result, { win = winnr, scope = "local" })
      end
    end,
  }))
  fork._parent, fork._winnr, fork._bufnr = self, winnr, bufnr
  self._forks[winnr] = fork
  for _, component in ipairs(self._components) do
    fork:place({
      position = component.position,
      priority = component.priority,
      component = component.source,
      notify = component.notify,
    })
  end
  fork._close_autocmd = vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(winnr),
    once = true,
    callback = function()
      fork:dispose()
    end,
  })
  return fork
end

----------------------------------------------------------------------------------------------------

---@protected
---@return nil
function M:__health__()
  if self._disposed then
    local message = string.format("[%s] already been disposed.", self.fullname) ---@type string
    error(message)
  end
end

---@protected
---@return string|nil
---@return era.m.nvimbar.ISnapshot[]|nil
function M:__render__()
  local context = self:__context__() ---@type era.m.nvimbar.INvimbarContext|nil
  if context == nil then
    return nil
  end

  local sep = self._isactive(context) and self._sep_active or self._sep ---@type string
  local width_sep = self._sep_width ---@type integer
  local width_full = self._get_max_width() ---@type integer
  if width_full <= 1 then
    return nil
  end

  local wl = width_sep ---@type integer
  local wc = width_sep + width_sep ---@type integer
  local wr = width_sep ---@type integer
  local width_remain = width_full - wl - wc - wr ---@type integer

  local components = self._components ---@type era.m.nvimbar.IPlacedComponent[]
  local orders = self._orders ---@type integer[]
  local hltexts = {} ---@type string[]
  local snapshots = {} ---@type era.m.nvimbar.ISnapshot[]

  local N = #orders ---@type integer
  local hl, hc, hr = false, false, false ---@type boolean, boolean, boolean
  for _, order in ipairs(orders) do
    hltexts[order] = ""
    local component = components[order] ---@type era.m.nvimbar.IPlacedComponent
    local snapshot = component.runtime.snapshot
    local definition = component.runtime.definition ---@type era.m.nvimbar.IRawComponent|nil
    local tight = definition ~= nil and definition.tight ---@type boolean|nil
    local position = component.position ---@type dot.e.NvimbarCompPosition
    local has_peer = (position == "left" and hl) or (position == "center" and hc) or (position == "right" and hr)
    local available = width_remain - (has_peer and not tight and width_sep or 0) ---@type integer
    local ok, hltext, width = pcall(function()
      if available < 1 then
        return "", 0
      end
      return component.runtime:format(context, available)
    end)

    if ok then
      if width > 0 and width <= available then
        if snapshot ~= nil then
          snapshots[#snapshots + 1] = snapshot
        end
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
      stl.reporter.error({
        from = self.fullname,
        subject = "render",
        message = "Encounter error while render the nvimbar component.",
        details = {
          bufnr = context.bufnr,
          component = {
            name = definition and definition.name,
            position = component.position,
            priority = component.priority,
          },
          error = hltext,
        },
      })
    end
  end

  local tl, tc, tr = "", "", "" ---@type string, string, string
  for i = 1, N, 1 do
    local hltext = hltexts[i] ---@type string
    local component = components[i] ---@type era.m.nvimbar.IPlacedComponent
    local position = component.position ---@type dot.e.NvimbarCompPosition
    if position == "left" then
      tl = tl .. hltext
    elseif position == "center" then
      tc = tc .. hltext
    elseif position == "right" then
      tr = hltext .. tr
    end
  end

  if hc then
    local width_half_left = math.floor(width_full / 2) ---@type integer
    local width_padding_left = width_half_left - wl - math.floor(wc / 2) ---@type integer
    if width_padding_left >= 0 and width_padding_left <= width_remain then
      local width_padding_right = width_remain - width_padding_left ---@type integer
      local padding_left = string.rep(" ", width_padding_left) ---@type string
      local padding_right = string.rep(" ", width_padding_right) ---@type string
      return tl .. sep .. padding_left .. sep .. tc .. sep .. padding_right .. sep .. tr, snapshots
    end
    return tl .. sep .. "%=" .. sep .. tc .. sep .. "%=" .. sep .. tr, snapshots
  end
  return tl .. sep .. "%=" .. sep .. tr, snapshots
end

---@protected
---@return era.m.nvimbar.INvimbarContext|nil
function M:__context__()
  if self._disposed or self._validate() ~= nil then
    return nil
  end
  local preset_context = self._get_preset_context() or {} ---@type era.m.nvimbar.INvimbarPresetContext
  return build_context(preset_context)
end

---@protected
---@param context                       era.m.nvimbar.INvimbarContext
---@return boolean
function M:__is_current__(context)
  if self._disposed or self._validate() ~= nil then
    return false
  end
  local preset = self._get_preset_context() ---@type era.m.nvimbar.INvimbarPresetContext|nil
  local winnr = preset and preset.winnr ---@type integer|nil
  return winnr ~= nil
    and winnr == context.winnr
    and vim.api.nvim_win_is_valid(winnr)
    and vim.api.nvim_win_get_buf(winnr) == context.bufnr
    and vim.api.nvim_win_get_tabpage(winnr) == context.tabnr
    and vim.api.nvim_buf_get_name(context.bufnr) == context.filepath
    and dot.path.cwd() == context.cwd
end

---@protected
---@param requested                     ?boolean
---@return nil
function M:__publish__(requested)
  if self._disposed then
    return
  end
  self._publish_requested = self._publish_requested or requested == true
  if not requested and not self._has_changed then
    -- The bootstrap placeholder must not delay the first completed component.
    self._has_changed = true
    self._last_draw = nil
    if self._publish_scheduled then
      queue.unwatch(self._publish_scheduled)
      self._publish_scheduled = nil
    end
  end
  if self._publish_scheduled then
    return
  end
  local scheduled = {}
  self._publish_scheduled = scheduled

  ---@return nil
  local function publish()
    if self._disposed or self._publish_scheduled ~= scheduled then
      return
    end
    self._publish_scheduled = nil
    local should_publish = self._publish_requested ---@type boolean
    self._publish_requested = false
    self._last_draw = vim.uv.hrtime() / 1e6

    local last_result = self._value ---@type string
    local result, snapshots = self:__render__()
    if result == nil then
      return
    end
    self._value = result
    self._drawn_snapshots = snapshots
    if should_publish or result ~= last_result then
      self._on_fulfilled(result, last_result)
    end
  end

  local remaining = self._draw_interval > 0
      and self._last_draw
      and self._last_draw + self._draw_interval - vim.uv.hrtime() / 1e6
    or 0
  if remaining > 0 then
    queue.watch(scheduled, remaining, publish)
  else
    vim.schedule(publish)
  end
end

return M
