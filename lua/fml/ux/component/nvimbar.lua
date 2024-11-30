local __module_name__ = "fml.ux.component.nvimbar" ---@type string

local path = require("eve.builtin.path")
local reporter = require("eve.builtin.reporter")
local nvimbar = require("eve.std.nvimbar")
local Scheduler = require("eve.collection.scheduler")

---@return boolean
local function truthy()
  return true
end

---@class fml.ux.Nvimbar : fml.t.ux.INvimbar
---@field public name                   string
---@field private _sep                  string
---@field private _sep_active           string
---@field private _sep_width            integer
---@field private _last_context         fml.t.ux.nvimbar.IContext|nil
---@field private _preset_context       fml.t.ux.nvimbar.IPresetContext
---@field private _components           table<string, fml.t.ux.nvimbar.IComponent>
---@field private _items                fml.t.ux.nvimbar.IItem[]
---@field private _render_scheduler     eve.t.collection.IScheduler
---@field private _get_max_width        fun(): integer
---@field private _is_active            fun(context: fml.t.ux.nvimbar.IContext): boolean
local M = {}
M.__index = M

---@class fml.ux.nvimbar.IProps
---@field public name                   string
---@field public component_sep          string
---@field public component_sep_hlname   string
---@field public component_sep_hlname_active string
---@field public preset_context         ?fml.t.ux.nvimbar.IPresetContext
---@field public render_delay           ?integer
---@field public silent                 ?boolean
---@field public get_max_width          fun(): integer
---@field public is_active              fun(context: fml.t.ux.nvimbar.IContext): boolean
---@field public trigger_rerender       fun(): nil
---@field public validate               fun(): string|nil

local modes_map = {
  ["n"] = { "normal", "NORMAL" },
  ["no"] = { "normal", "NORMAL (no)" },
  ["nov"] = { "normal", "NORMAL (nov)" },
  ["noV"] = { "normal", "NORMAL (noV)" },
  ["noCTRL-V"] = { "normal", "NORMAL" },
  ["niI"] = { "normal", "NORMAL i" },
  ["niR"] = { "normal", "NORMAL r" },
  ["niV"] = { "normal", "NORMAL v" },
  ["nt"] = { "nterminal", "NTERMINAL" },
  ["ntT"] = { "nterminal", "NTERMINAL (ntT)" },
  ["v"] = { "visual", "VISUAL" },
  ["vs"] = { "visual", "V-CHAR (Ctrl O)" },
  ["V"] = { "visual", "V-LINE" },
  ["Vs"] = { "visual", "V-LINE" },
  [""] = { "visual", "V-BLOCK" },
  ["i"] = { "insert", "INSERT" },
  ["ic"] = { "insert", "INSERT (completion)" },
  ["ix"] = { "insert", "INSERT completion" },
  ["t"] = { "terminal", "TERMINAL" },
  ["R"] = { "replace", "REPLACE" },
  ["Rc"] = { "replace", "REPLACE (Rc)" },
  ["Rx"] = { "replace", "REPLACEa (Rx)" },
  ["Rv"] = { "replace", "V-REPLACE" },
  ["Rvc"] = { "replace", "V-REPLACE (Rvc)" },
  ["Rvx"] = { "replace", "V-REPLACE (Rvx)" },
  ["s"] = { "select", "SELECT" },
  ["S"] = { "select", "S-LINE" },
  [""] = { "select", "S-BLOCK" },
  ["c"] = { "command", "COMMAND" },
  ["cv"] = { "command", "COMMAND" },
  ["ce"] = { "command", "COMMAND" },
  ["r"] = { "confirm", "PROMPT" },
  ["rm"] = { "confirm", "MORE" },
  ["r?"] = { "confirm", "CONFIRM" },
  ["x"] = { "confirm", "CONFIRM" },
  ["!"] = { "terminal", "SHELL" },
}

---@param preset_context                fml.t.ux.nvimbar.IPresetContext
---@return fml.t.ux.nvimbar.IContext
local function build_context(preset_context)
  local m = modes_map[vim.api.nvim_get_mode().mode]
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local winnr = preset_context.winnr or vim.api.nvim_get_current_win() ---@type integer
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  local cwd = path.cwd() ---@type string
  local filepath = vim.fn.expand("%:p") ---@type string
  local filename = vim.fn.expand("%:t") ---@type string
  local filetype = vim.bo.filetype ---@type string
  local fileicon = eve.nvim.calc_fileicon(filename) ---@type string

  ---@type fml.t.ux.nvimbar.IContext
  local context = {
    tabnr = tabnr,
    winnr = winnr,
    bufnr = bufnr,
    cwd = cwd,
    filepath = filepath,
    fileicon = fileicon,
    filetype = filetype,
    mode = m[1],
    mode_name = m[2],
  }
  return context
end

---@param component                     fml.t.ux.nvimbar.IComponent
---@param context                       fml.t.ux.nvimbar.IContext
---@param prev_context                  fml.t.ux.nvimbar.IContext|nil
---@return nil
local function render_component(component, context, prev_context, remain_width)
  if not component.condition(context, remain_width) then
    component.last_result_text = ""
    component.last_result_width = 0
    return
  end

  if not component.will_change(context, prev_context, remain_width) then
    return
  end

  local text, width = component.render(context, remain_width)
  component.last_result_text = text
  component.last_result_width = width
end

---@param props                         fml.ux.nvimbar.IProps
---@return fml.ux.Nvimbar
function M.new(props)
  local name = props.name ---@type string
  local component_sep = props.component_sep ---@type string
  local component_sep_hlname = props.component_sep_hlname ---@type string
  local component_sep_hlname_active = props.component_sep_hlname_active ---@type string
  local render_delay = props.render_delay or 20 ---@type integer
  local silent = not not props.silent ---@type boolean
  local preset_context = props.preset_context or {} ---@type fml.t.ux.nvimbar.IPresetContext
  local get_max_width = props.get_max_width ---@type fun(): integer
  local is_active = props.is_active ---@type fun(context: fml.t.ux.nvimbar.IContext): boolean
  local validate = props.validate ---@type fun(): string|nil
  local trigger_rerender = props.trigger_rerender ---@type fun(): nil

  local self = setmetatable({}, M)

  ---@type eve.t.collection.IScheduler
  local _render_scheduler = Scheduler.new({
    name = "fml.ux.component.nvimbar#" .. name,
    delay = render_delay,
    silent = silent,
    task = function(callback)
      local validate_message = validate() ---@type string|nil
      if validate_message == nil then
        local result = self:internal_render()
        callback("fulfilled", result)

        trigger_rerender()
      else
        callback("rejected", nil, "[fml.ux.component.nvimbar#render] Invalid: " .. validate_message)
      end
    end,
  })

  self.name = name
  self._sep = nvimbar.txt(component_sep, component_sep_hlname)
  self._sep_active = nvimbar.txt(component_sep, component_sep_hlname_active)
  self._sep_width = vim.api.nvim_strwidth(component_sep)
  self._last_context = nil
  self._preset_context = preset_context
  self._components = {}
  self._items = {}
  self._render_scheduler = _render_scheduler
  self._get_max_width = get_max_width
  self._is_active = is_active
  return self
end

---@return nil
function M:cancel_render()
  self._render_scheduler:cancel()
end

---@param name                          string
---@return fml.ux.Nvimbar
function M:disable(name)
  local component = self._components[name] ---@type fml.t.ux.nvimbar.IComponent
  if component ~= nil then
    component.enabled = false
  end
  return self
end

---@param name                          string
---@return fml.ux.Nvimbar
function M:enable(name)
  local component = self._components[name] ---@type fml.t.ux.nvimbar.IComponent
  if component ~= nil then
    component.enabled = true
  end
  return self
end

---@param name                          string
---@param position                      eve.e.NvimbarCompPosition
---@return fml.ux.Nvimbar
function M:place(name, position)
  ---@type fml.t.ux.nvimbar.IItem
  local item = { name = name, position = position }
  table.insert(self._items, item)
  return self
end

---@param force                         boolean
---@return string
function M:render(force)
  if force then
    self._render_scheduler:mark_dirty()
  end
  self._render_scheduler:schedule()
  return self._render_scheduler:snapshot() or ""
end

---@param name                          string
---@param raw_component                 fml.t.ux.nvimbar.IRawComponent
---@param enabled                       boolean
---@return fml.ux.Nvimbar
function M:register(name, raw_component, enabled)
  ---@type fml.t.ux.nvimbar.IComponent
  local component = {
    name = raw_component.name,
    enabled = enabled == nil and true or enabled,
    last_result_text = "",
    last_result_width = 0,
    tight = not not raw_component.tight,
    render = raw_component.render,
    will_change = raw_component.will_change or truthy,
    condition = raw_component.condition or truthy,
  }
  self._components[name] = component
  return self
end

---@return string
function M:internal_render()
  local context = build_context(self._preset_context) ---@type fml.t.ux.nvimbar.IContext
  local prev_context = self._last_context ---@type fml.t.ux.nvimbar.IContext|nil

  local sep = self._is_active(context) and self._sep_active or self._sep ---@type string
  local width_sep = self._sep_width ---@type integer
  local width_full = self._get_max_width() ---@type integer

  local lc = "" ---@type string
  local cc = "" ---@type string
  local rc = "" ---@type string
  local width_left = width_sep ---@type integer
  local width_right = width_sep ---@type integer
  local width_center = width_sep + width_sep ---@type integer
  local width_remain = width_full - width_left - width_center - width_right ---@type integer
  local components = self._components ---@type fml.t.ux.nvimbar.IComponent[]
  local positions = self._items ---@type fml.t.ux.nvimbar.IItem[]
  for i = 1, #positions, 1 do
    local item = positions[i] ---@type fml.t.ux.nvimbar.IItem
    local name = item.name ---@type string
    local position = item.position ---@type eve.e.NvimbarCompPosition

    local component = components[name] ---@type fml.t.ux.nvimbar.IComponent|nil
    if component ~= nil and component.enabled then
      local ok, err = pcall(render_component, component, context, prev_context, width_remain)
      if ok then
        local text = component.last_result_text ---@type string
        local width = component.last_result_width ---@type integer
        if width > 0 then
          local tight = component.tight ---@type boolean
          if position == "left" then
            if #lc < 1 or tight then
              lc = lc .. text
              width_left = width_left + width
              width_remain = width_remain - width
            else
              lc = lc .. sep .. text
              width_left = width_left + width + width_sep
              width_remain = width_remain - width - width_sep
            end
          elseif position == "center" then
            if #cc < 1 or tight then
              cc = cc .. text
              width_center = width_center + width
              width_remain = width_remain - width
            else
              cc = cc .. sep .. text
              width_center = width_center + width + width_sep
              width_remain = width_remain - width - width_sep
            end
          elseif position == "right" then
            if #rc < 1 or tight then
              rc = text .. rc
              width_right = width_right + width
              width_remain = width_remain - width
            else
              rc = text .. sep .. rc
              width_right = width_right + width + width_sep
              width_remain = width_remain - width - width_sep
            end
          else
            reporter.error({
              from = __module_name__,
              subject = "render",
              message = "Bad component position.",
              details = { item = item, component = component },
            })
          end
        end
      else
        reporter.error({
          from = __module_name__,
          subject = "render",
          message = "Encounter error while render the nvimbar component.",
          details = { item = item, component = component, error = err },
        })
      end
    end
  end

  self._last_context = context

  local width_half_left = math.floor(width_full / 2) ---@type integer
  local width_padding_left = width_half_left - width_left - math.floor(width_center / 2) ---@type integer
  if width_padding_left > 0 and width_padding_left + 1 < width_remain then
    local width_padding_right = width_remain - width_padding_left ---@type integer
    local padding_left = string.rep(" ", width_padding_left) ---@type string
    local padding_right = string.rep(" ", width_padding_right) ---@type string
    return lc .. sep .. padding_left .. sep .. cc .. sep .. padding_right .. sep .. rc
  else
    return lc .. sep .. "%=" .. sep .. cc .. sep .. "%=" .. sep .. rc
  end
end

return M
