local __module_name__ = "eve.lib.ux.nvimbar" ---@type string

local path = require("eve.lib.path")
local reporter = require("eve.lib.reporter")
local functional = require("eve.lib.functional")
local Scheduler = require("eve.lib.collection.scheduler")

---@alias eve.lib.ux.nvimbar.Position
---| 'f_sl'
---| 'f_tl'
---| 'f_wl'

---@class eve.lib.ux.nvimbar.IPresetContext
---@field public winnr                  ?integer

---@class eve.lib.ux.nvimbar.IContext
---@field public tabnr                  integer
---@field public winnr                  integer
---@field public bufnr                  integer
---@field public cwd                    string
---@field public filename               string
---@field public filepath               string
---@field public fileicon               string
---@field public filetype               string
---@field public mode                   eve.e.VimModeName
---@field public mode_name              string

---@class eve.lib.ux.nvimbar.IRawComponent
---@field public name                   string
---@field public render                 fun(context: eve.lib.ux.nvimbar.IContext, remain_width: integer): string, integer
---@field public tight                  ?boolean
---@field public condition              ?fun(context: eve.lib.ux.nvimbar.IContext, remain_width: integer): boolean
---@field public will_change            ?fun(context: eve.lib.ux.nvimbar.IContext, prev_context: eve.lib.ux.nvimbar.IContext|nil, remain_width: integer): boolean

---@class eve.lib.ux.nvimbar.IComponent
---@field public last_result_text       string
---@field public last_result_width      integer
---@field public tight                  boolean
---@field public render                 fun(context: eve.lib.ux.nvimbar.IContext, remain_width: integer): string, integer
---@field public condition              fun(context: eve.lib.ux.nvimbar.IContext, remain_width: integer): boolean
---@field public will_change            fun(context: eve.lib.ux.nvimbar.IContext, prev_context: eve.lib.ux.nvimbar.IContext|nil, remain_width: integer): boolean

---@class eve.lib.ux.nvimbar.IItem
---@field public name                   string
---@field public position               eve.e.NvimbarCompPosition

---@class eve.lib.ux.nvimbar.IProps
---@field public name                   string
---@field public component_sep          string
---@field public component_sep_hlname   string
---@field public component_sep_hlname_active string
---@field public render_delay           ?integer
---@field public silent                 ?boolean
---@field public get_max_width          fun(): integer
---@field public get_preset_context     ?fun(): eve.lib.ux.nvimbar.IPresetContext
---@field public is_active              fun(context: eve.lib.ux.nvimbar.IContext): boolean
---@field public pre_task               ?fun(callback: fun(err: string|false|nil): nil): nil
---@field public trigger_rerender       fun(): nil
---@field public validate               fun(): string|nil

---@class eve.lib.ux.INvimbar
---@field public btn                    fun(text: string, callback: string, args?: integer|integer[]): string
---@field public txt                    fun(text: string, hlname: string): string
---@field public cancel_render          fun(self: eve.lib.ux.INvimbar): eve.lib.ux.INvimbar
---@field public dispose                fun(self: eve.lib.ux.INvimbar): boolean
---@field public register               fun(self: eve.lib.ux.INvimbar, component: eve.lib.ux.nvimbar.IRawComponent, position: eve.e.NvimbarCompPosition): eve.lib.ux.INvimbar
---@field public render                 fun(self: eve.lib.ux.INvimbar): string
---@field public snapshot               fun(self: eve.lib.ux.INvimbar): string

---@class eve.lib.ux.Nvimbar : eve.lib.ux.INvimbar
---@field public name                   string
---@field private _disposed             boolean
---@field private _sep                  string
---@field private _sep_active           string
---@field private _sep_width            integer
---@field private _last_context         eve.lib.ux.nvimbar.IContext|nil
---@field private _components           table<string, eve.lib.ux.nvimbar.IComponent>
---@field private _items                eve.lib.ux.nvimbar.IItem[]
---@field private _render_scheduler     eve.lib.collection.IScheduler
---@field private _get_max_width        fun(): integer
---@field public  _get_preset_context   fun(): eve.lib.ux.nvimbar.IPresetContext
---@field private _is_active            fun(context: eve.lib.ux.nvimbar.IContext): boolean
local M = {}
M.__index = M

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

---@param num                           integer
---@return string
local function encode_int(num)
  local text = string.format("%o", num) ---@type string
  return text
end

---@param text                          string
---@return integer|nil
local function decode_int(text)
  local num = tonumber(text, 8) ---@type integer|nil
  return num
end

---@param preset_context                eve.lib.ux.nvimbar.IPresetContext
---@return eve.lib.ux.nvimbar.IContext
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

  ---@type eve.lib.ux.nvimbar.IContext
  local context = {
    tabnr = tabnr,
    winnr = winnr,
    bufnr = bufnr,
    cwd = cwd,
    filename = filename,
    filepath = filepath,
    fileicon = fileicon,
    filetype = filetype,
    mode = m[1],
    mode_name = m[2],
  }
  return context
end

---@param component                     eve.lib.ux.nvimbar.IComponent
---@param context                       eve.lib.ux.nvimbar.IContext
---@param prev_context                  eve.lib.ux.nvimbar.IContext|nil
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

---@param props                         eve.lib.ux.nvimbar.IProps
---@return eve.lib.ux.Nvimbar
function M.new(props)
  local name = props.name ---@type string
  local component_sep = props.component_sep ---@type string
  local component_sep_hlname = props.component_sep_hlname ---@type string
  local component_sep_hlname_active = props.component_sep_hlname_active ---@type string
  local render_delay = props.render_delay or 20 ---@type integer
  local silent = not not props.silent ---@type boolean
  local get_max_width = props.get_max_width ---@type fun(): integer

  ---@type fun(): eve.lib.ux.nvimbar.IPresetContext
  local get_preset_context = props.get_preset_context or function()
    return {}
  end

  local is_active = props.is_active ---@type fun(context: eve.lib.ux.nvimbar.IContext): boolean
  local pre_task = props.pre_task ---@type fun(callback: fun(err: string|false|nil): nil): nil
  local trigger_rerender = props.trigger_rerender ---@type fun(): nil
  local validate = props.validate ---@type fun(): string|nil

  local self = setmetatable({}, M)

  local _render_scheduler ---@type eve.lib.collection.IScheduler
  _render_scheduler = Scheduler.new({
    name = "eve.lib.ux.nvimbar#" .. name,
    delay = render_delay,
    silent = silent,
    task = function(callback)
      local validate_message = validate() ---@type string|nil
      if validate_message ~= nil then
        callback("rejected", nil, "[eve.lib.ux.nvimbar#" .. name .. "] Invalid: " .. validate_message)
        return
      end

      ---@param cancelled               boolean
      ---@return nil
      local function handle(cancelled)
        local last_result = _render_scheduler:snapshot() ---@type string|nil
        if cancelled then
          callback("fulfilled", last_result)
        end

        local result = self:render_sync()
        callback("fulfilled", result)

        if last_result ~= result then
          trigger_rerender()
        end
      end

      if pre_task == nil then
        handle(false)
      else
        pre_task(function(err)
          if err == false then
            handle(true)
          elseif err ~= nil then
            callback("rejected", nil, "[eve.lib.ux.nvimbar#" .. name .. "] " .. err)
          else
            handle(false)
          end
        end)
      end
    end,
  })

  self.name = name
  self._disposed = false
  self._sep = M.txt(component_sep, component_sep_hlname)
  self._sep_active = M.txt(component_sep, component_sep_hlname_active)
  self._sep_width = vim.api.nvim_strwidth(component_sep)
  self._last_context = nil
  self._components = {}
  self._items = {}
  self._render_scheduler = _render_scheduler
  self._get_max_width = get_max_width
  self._get_preset_context = get_preset_context
  self._is_active = is_active
  return self
end

---@return boolean
function M:is_disposed()
  return self._disposed
end

---@return nil
function M:dispose()
  if not self._disposed then
    self._disposed = true
  end
end

---@param text                          string
---@param callback                      string
---@param args                          ?integer|integer[]
function M.btn(text, callback, args)
  local args_str = args or "" ---@type integer|integer[]|string
  if type(args) == "table" then
    args_str = M.encode_btn_args(args)
  end
  return "%" .. args_str .. "@v:lua." .. callback .. "@" .. text .. "%T"
end

---@param text                          string
---@param hlname                        string
---@return string
function M.txt(text, hlname)
  return "%#" .. hlname .. "#" .. text:gsub("%%", "%%%%")
end

---@param args                          integer[]
---@return string
function M.encode_btn_args(args)
  local result = "" ---@type string
  for i, num in ipairs(args) do
    if i > 1 then
      result = result .. "9"
    end
    result = result .. encode_int(num)
  end
  return result
end

---@param text                          string
---@return integer[]
function M.decode_btn_args(text)
  local argv = vim.split(text, "9") ---@type string[]
  local result = {} ---@type integer[]
  for _, arg in ipairs(argv) do
    local num = decode_int(arg)
    if num ~= nil then
      table.insert(result, num)
    end
  end
  return result
end

---@return nil
function M:cancel_render()
  self._render_scheduler:cancel()
end

---@return string
function M:render()
  if self._disposed then
    return "!!!Invalid. This nvimbar has been disposed."
  end

  self._render_scheduler:schedule()
  return self._render_scheduler:snapshot() or ""
end

---@param raw_component                 eve.lib.ux.nvimbar.IRawComponent
---@param position                      eve.e.NvimbarCompPosition
---@return eve.lib.ux.Nvimbar
function M:register(raw_component, position)
  local name = raw_component.name ---@type string
  if self._components[name] ~= nil then
    reporter.warn({
      from = __module_name__,
      subject = "register",
      message = "The component is already registered.",
      details = { name = name, raw_component = raw_component, position = position },
    })
  end

  ---@type eve.lib.ux.nvimbar.IComponent
  local component = {
    name = name,
    last_result_text = "",
    last_result_width = 0,
    tight = not not raw_component.tight,
    render = raw_component.render,
    will_change = raw_component.will_change or functional.truthy,
    condition = raw_component.condition or functional.truthy,
  }
  self._components[name] = component

  ---@type eve.lib.ux.nvimbar.IItem
  local item = { name = name, position = position }
  table.insert(self._items, item)
  return self
end

---@return string
function M:snapshot()
  return self._render_scheduler:snapshot() or ""
end

---@return string
function M:render_sync()
  local preset_context = self._get_preset_context() ---@type eve.lib.ux.nvimbar.IPresetContext
  local context = build_context(preset_context) ---@type eve.lib.ux.nvimbar.IContext
  local prev_context = self._last_context ---@type eve.lib.ux.nvimbar.IContext|nil

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
  local components = self._components ---@type eve.lib.ux.nvimbar.IComponent[]
  local positions = self._items ---@type eve.lib.ux.nvimbar.IItem[]
  for i = 1, #positions, 1 do
    local item = positions[i] ---@type eve.lib.ux.nvimbar.IItem
    local name = item.name ---@type string
    local position = item.position ---@type eve.e.NvimbarCompPosition

    local component = components[name] ---@type eve.lib.ux.nvimbar.IComponent|nil
    if component ~= nil then
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
