local __module_name__ = "fml.ux.nvimbar" ---@type string

local fn = require("eve.builtin.fn")
local path = require("eve.std.path")
local reporter = require("eve.std.reporter")
local Scheduler = require("eve.collection.scheduler")
local calc_fileicon = require("eve.module.fileicon").calc_fileicon

---@alias fml.ux.nvimbar.Position
---| 'f_sl'
---| 'f_tl'
---| 'f_wl'

---@class fml.ux.nvimbar.IPresetContext
---@field public winnr                  ?integer

---@class fml.ux.nvimbar.IContext
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

---@class fml.ux.nvimbar.IRawComponent
---@field public atomic                 boolean
---@field public name                   string
---@field public tight                  ?boolean
---@field public condition              ?fun(context: fml.ux.nvimbar.IContext, remain_width: integer): boolean
---@field public render                 fun(context: fml.ux.nvimbar.IContext, remain_width: integer): string, string, boolean
---@field public will_change            ?fun(context: fml.ux.nvimbar.IContext, prev_context: fml.ux.nvimbar.IContext|nil, remain_width: integer): boolean

---@class fml.ux.nvimbar.IComponent
---@field public last_render_context    fml.ux.nvimbar.IContext|nil
---@field public last_result_full       boolean
---@field public last_result_hltext     string
---@field public last_result_text       string
---@field public last_result_width      integer
---@field public atomic                 boolean
---@field public name                   string
---@field public position               eve.e.NvimbarCompPosition
---@field public priority               integer
---@field public tight                  boolean
---@field public condition              fun(context: fml.ux.nvimbar.IContext, remain_width: integer): boolean
---@field public render                 fun(context: fml.ux.nvimbar.IContext, remain_width: integer): string, string, boolean
---@field public will_change            fun(context: fml.ux.nvimbar.IContext, prev_context: fml.ux.nvimbar.IContext|nil, remain_width: integer): boolean

---@class fml.ux.nvimbar.IItem
---@field public name                   string
---@field public position               eve.e.NvimbarCompPosition

---@class fml.ux.nvimbar.IProps
---@field public name                   string
---@field public comp_sep               string
---@field public comp_sep_hlname        string
---@field public comp_sep_hlname_active string
---@field public render_delay           ?integer
---@field public silent                 ?fun(): boolean
---@field public get_max_width          fun(): integer
---@field public get_preset_context     ?fun(): fml.ux.nvimbar.IPresetContext
---@field public is_active              fun(context: fml.ux.nvimbar.IContext): boolean
---@field public pre_task               ?fun(callback: fun(err: string|false|nil): nil): nil
---@field public trigger_rerender       ?fun(): nil
---@field public validate               ?fun(): string|nil

---@class fml.ux.INvimbar
---@field public btn                    fun(text: string, callback: string, args?: integer|integer[]): string
---@field public txt                    fun(text: string, hlname: string): string
---@field public cancel_render          fun(self: fml.ux.INvimbar): fml.ux.INvimbar
---@field public dispose                fun(self: fml.ux.INvimbar): boolean
---@field public place                  fun(self: fml.ux.INvimbar, position: eve.e.NvimbarCompPosition, component: fml.ux.nvimbar.IRawComponent, priority?: integer): fml.ux.INvimbar
---@field public render                 fun(self: fml.ux.INvimbar): string
---@field public render_immediately     fun(self: fml.ux.INvimbar): string
---@field public snapshot               fun(self: fml.ux.INvimbar): string

---@class fml.ux.Nvimbar : fml.ux.INvimbar
---@field public name                   string
---@field private _disposed             boolean
---@field private _sep                  string
---@field private _sep_active           string
---@field private _sep_width            integer
---@field private _components           fml.ux.nvimbar.IComponent[]
---@field private _orders               integer[]
---@field private _render_scheduler     eve.collection.IScheduler
---@field private _get_max_width        fun(): integer
---@field public  _get_preset_context   fun(): fml.ux.nvimbar.IPresetContext
---@field private _is_active            fun(context: fml.ux.nvimbar.IContext): boolean
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

---@param preset_context                fml.ux.nvimbar.IPresetContext
---@return fml.ux.nvimbar.IContext
local function build_context(preset_context)
  local m = modes_map[vim.api.nvim_get_mode().mode]
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local winnr = preset_context.winnr or vim.api.nvim_tabpage_get_win(tabnr) ---@type integer
  local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  local cwd = path.cwd() ---@type string
  local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
  local filename = path.basename(filepath) ---@type string
  local filetype = vim.bo[bufnr].filetype ---@type string
  local fileicon, fileicon_hl = calc_fileicon(filename) ---@type string, string

  local git = vim.b[bufnr].gitsigns_status_dict
  local git_branch = git and git.head or nil ---@type string|nil

  ---@type fml.ux.nvimbar.IContext
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
    mode = m[1],
    mode_name = m[2],
    git_branch = git_branch,
  }
  return context
end

---@param props                         fml.ux.nvimbar.IProps
---@return fml.ux.Nvimbar
function M.new(props)
  local name = props.name ---@type string
  local comp_sep = props.comp_sep ---@type string
  local comp_sep_hlname = props.comp_sep_hlname ---@type string
  local comp_sep_hlname_active = props.comp_sep_hlname_active ---@type string
  local render_delay = props.render_delay or 20 ---@type integer
  local silent = props.silent ---@type fun(): boolean
  local get_max_width = props.get_max_width ---@type fun(): integer

  ---@type fun(): fml.ux.nvimbar.IPresetContext
  local get_preset_context = props.get_preset_context or function()
    return {}
  end

  local is_active = props.is_active ---@type fun(context: fml.ux.nvimbar.IContext): boolean
  local pre_task = props.pre_task ---@type fun(callback: fun(err: string|false|nil): nil): nil
  local trigger_rerender = props.trigger_rerender or fn.noop ---@type fun(): nil
  local validate = props.validate or fn.noop ---@type fun(): string|nil

  local self = setmetatable({}, M)

  local _render_scheduler ---@type eve.collection.IScheduler
  _render_scheduler = Scheduler.new({
    name = "fml.ux.nvimbar#" .. name,
    delay = render_delay,
    silent = silent,
    task = function(callback)
      local validate_message = validate() ---@type string|nil
      if validate_message ~= nil then
        callback("rejected", nil, "[fml.ux.nvimbar#" .. name .. "] Invalid: " .. validate_message)
        return
      end

      ---@param cancelled               boolean
      ---@return nil
      local function handle(cancelled)
        local last_result = _render_scheduler:snapshot() ---@type string|nil
        if cancelled then
          callback("fulfilled", last_result)
          return
        end

        local result = self:render_sync(false)
        callback("fulfilled", result)

        --- Trigger rerender need called after the callback executed,
        --- so we can get the latest value from the :snapshot()
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
            callback("rejected", nil, "[fml.ux.nvimbar#" .. name .. "] " .. err)
          else
            handle(false)
          end
        end)
      end
    end,
  })

  self.name = name
  self._disposed = false
  self._sep = M.txt(comp_sep, comp_sep_hlname)
  self._sep_active = M.txt(comp_sep, comp_sep_hlname_active)
  self._sep_width = vim.api.nvim_strwidth(comp_sep)
  self._components = {}
  self._orders = {}
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
  local argv = vim.split(text, "9", { plain = true }) ---@type string[]
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

  local scheduler = self._render_scheduler
  scheduler:schedule()
  return scheduler:snapshot() or ""
end

---@return string
function M:render_immediately()
  if self._disposed then
    return "!!!Invalid. This nvimbar has been disposed."
  end

  return self:render_sync(true) ---@type string
end

---@param position                      eve.e.NvimbarCompPosition
---@param raw_component                 fml.ux.nvimbar.IRawComponent
---@param priority                      ?integer
---@return fml.ux.Nvimbar
function M:place(position, raw_component, priority)
  priority = priority or 1 ---@type integer
  local name = raw_component.name ---@type string

  if position ~= "left" and position ~= "center" and position ~= "right" then
    reporter.error({
      from = __module_name__,
      subject = "place",
      message = "Bad component position.",
      details = { name = name, position = position, priority = priority, component = raw_component },
    })
    return self
  end

  local components = self._components ---@type fml.ux.nvimbar.IComponent[]
  local orders = self._orders ---@type integer[]
  local k = #components ---@type integer

  ---@type fml.ux.nvimbar.IComponent
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
    will_change = raw_component.will_change or fn.truthy,
    condition = raw_component.condition or fn.truthy,
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
  return self._render_scheduler:snapshot() or ""
end

---@param force                         boolean
---@return string
function M:render_sync(force)
  local preset_context = self._get_preset_context() ---@type fml.ux.nvimbar.IPresetContext
  local context = build_context(preset_context) ---@type fml.ux.nvimbar.IContext

  local sep = self._is_active(context) and self._sep_active or self._sep ---@type string
  local width_sep = self._sep_width ---@type integer
  local width_full = self._get_max_width() ---@type integer

  local wl = width_sep ---@type integer
  local wc = width_sep + width_sep ---@type integer
  local wr = width_sep ---@type integer
  local width_remain = width_full - wl - wc - wr ---@type integer

  local components = self._components ---@type fml.ux.nvimbar.IComponent[]
  local orders = self._orders ---@type integer[]
  local hltexts = {} ---@type string[]

  local N = #orders ---@type integer
  local hl, hc, hr = false, false, false ---@type boolean, boolean, boolean
  for _, order in ipairs(orders) do
    hltexts[order] = ""
    local component = components[order] ---@type fml.ux.nvimbar.IComponent
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
      reporter.error({
        from = __module_name__,
        subject = "render",
        message = "Encounter error while render the nvimbar component.",
        details = { context = context, component = component, error = hltext },
      })
    end
  end

  local tl, tc, tr = "", "", "" ---@type string, string, string
  for i = 1, N, 1 do
    local hltext = hltexts[i] ---@type string
    local component = components[i] ---@type fml.ux.nvimbar.IComponent
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
