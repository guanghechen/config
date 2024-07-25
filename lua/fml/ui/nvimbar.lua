local nvimbar = require("fml.std.nvimbar")
local path = require("fml.std.path")
local reporter = require("fml.std.reporter")
local util = require("fml.std.util")

---@class fml.ui.Nvimbar : fml.types.ui.INvimbar
---@field public name                   string
---@field private _dirty                boolean
---@field private _rendering            boolean
---@field private _sep                  string
---@field private _sep_width            integer
---@field private _last_result          string|nil
---@field private _last_context         fml.types.ui.nvimbar.IContext|nil
---@field private _preset_context       fml.types.ui.nvimbar.IPresetContext
---@field private _components           table<string, fml.types.ui.nvimbar.IComponent>
---@field private _items                fml.types.ui.nvimbar.IItem[]
---@field private _get_max_width        fun(): integer
local M = {}
M.__index = M

---@class fml.ui.nvimbar.IProps
---@field public name                   string
---@field public component_sep          string
---@field public component_sep_hlname   string
---@field public preset_context         ?fml.types.ui.nvimbar.IPresetContext
---@field public get_max_width          fun(): integer

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

---@param preset_context                fml.types.ui.nvimbar.IPresetContext
---@return fml.types.ui.nvimbar.IContext
local function build_context(preset_context)
  local m = modes_map[vim.api.nvim_get_mode().mode]
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local winnr = preset_context.winnr or vim.api.nvim_get_current_win() ---@type integer
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  local cwd = path.cwd() ---@type string
  local filepath = vim.fn.expand("%:p") ---@type string
  local fileicon = util.calc_fileicon(filepath) ---@type string
  local filetype = vim.bo.filetype ---@type string

  ---@type fml.types.ui.nvimbar.IContext
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

---@param component                     fml.types.ui.nvimbar.IComponent
---@param context                       fml.types.ui.nvimbar.IContext
---@param prev_context                  fml.types.ui.nvimbar.IContext|nil
---@return nil
local function render_component(component, context, prev_context, remain_width)
  if not component.will_change(context, prev_context, remain_width) then
    return
  end

  if not component.condition(context, remain_width) then
    component.last_result_text = ""
    component.last_result_width = 0
    return
  end

  local text, width = component.render(context, remain_width)
  component.last_result_text = text
  component.last_result_width = width
end

---@param props                         fml.ui.nvimbar.IProps
---@return fml.ui.Nvimbar
function M.new(props)
  local name = props.name ---@type string
  local component_sep = props.component_sep ---@type string
  local component_sep_hlname = props.component_sep_hlname ---@type string
  local preset_context = props.preset_context or {} ---@type fml.types.ui.nvimbar.IPresetContext
  local get_max_width = props.get_max_width ---@type fun(): integer

  local self = setmetatable({}, M)
  self.name = name
  self._dirty = true
  self._rendering = false
  self._sep = nvimbar.txt(component_sep, component_sep_hlname)
  self._sep_width = vim.fn.strwidth(component_sep)
  self._last_result = nil
  self._last_context = nil
  self._preset_context = preset_context
  self._components = {}
  self._items = {}
  self._get_max_width = get_max_width
  return self
end

---@param name                          string
---@return fml.ui.Nvimbar
function M:disable(name)
  local component = self._components[name] ---@type fml.types.ui.nvimbar.IComponent
  if component ~= nil then
    component.enabled = false
  end
  return self
end

---@param name                          string
---@return fml.ui.Nvimbar
function M:enable(name)
  local component = self._components[name] ---@type fml.types.ui.nvimbar.IComponent
  if component ~= nil then
    component.enabled = true
  end
  return self
end

---@param name                          string
---@param position                      fml.enums.nvimbar.ComponentPosition
---@return fml.ui.Nvimbar
function M:place(name, position)
  ---@type fml.types.ui.nvimbar.IItem
  local item = { name = name, position = position }
  table.insert(self._items, item)
  return self
end

---@param name                          string
---@param raw_component                 fml.types.ui.nvimbar.IRawComponent
---@param enabled                       boolean
---@return fml.ui.Nvimbar
function M:register(name, raw_component, enabled)
  ---@type fml.types.ui.nvimbar.IComponent
  local component = {
    name = raw_component.name,
    enabled = enabled == nil and true or enabled,
    last_result_text = "",
    last_result_width = 0,
    render = raw_component.render,
    will_change = raw_component.will_change or util.truthy,
    condition = raw_component.condition or util.truthy,
  }
  self._components[name] = component
  return self
end

---@return string
function M:render()
  if self._rendering then
    self._dirty = true
    return self._last_result or ""
  end

  self._dirty = false
  self._rendering = true
  vim.schedule(function()
    local sep = self._sep ---@type string
    local sep_width = self._sep_width ---@type integer
    local context = build_context(self._preset_context) ---@type fml.types.ui.nvimbar.IContext
    local prev_context = self._last_context ---@type fml.types.ui.nvimbar.IContext|nil

    local lc = "" ---@type string
    local cc = "" ---@type string
    local rc = "" ---@type string
    local remain_width = self._get_max_width() - sep_width - sep_width ---@type integer
    local components = self._components ---@type fml.types.ui.nvimbar.IComponent[]
    local positions = self._items ---@type fml.types.ui.nvimbar.IItem[]
    for i = 1, #positions, 1 do
      local item = positions[i] ---@type fml.types.ui.nvimbar.IItem
      local name = item.name ---@type string
      local position = item.position ---@type fml.enums.nvimbar.ComponentPosition

      local component = components[name] ---@type fml.types.ui.nvimbar.IComponent|nil
      if component ~= nil and component.enabled then
        local ok, err = pcall(render_component, component, context, prev_context, remain_width)
        if ok then
          local text = component.last_result_text ---@type string
          local width = component.last_result_width ---@type integer
          if width > 0 then
            if position == "left" then
              if #lc > 0 then
                lc = lc .. sep .. text
                remain_width = remain_width - width - sep_width - sep_width
              else
                lc = text
                remain_width = remain_width - width - sep_width
              end
            elseif position == "center" then
              if #cc > 0 then
                cc = cc .. sep .. text
                remain_width = remain_width - width - sep_width - sep_width
              else
                cc = text
                remain_width = remain_width - width - sep_width
              end
            elseif position == "right" then
              if #rc > 0 then
                rc = text .. sep .. rc
                remain_width = remain_width - width - sep_width - sep_width
              else
                rc = text
                remain_width = remain_width - width - sep_width
              end
            else
              reporter.error({
                from = "fml.ui.nvimbar",
                subject = "render",
                message = "Bad component position.",
                details = { item = item, component = component },
              })
            end
          end
        else
          reporter.error({
            from = "fml.ui.nvimbar",
            subject = "render",
            message = "Encounter error while render the nvimbar component.",
            details = { item = item, component = component, error = err },
          })
        end
      end
    end

    local final_result = lc .. sep .. "%=" .. sep .. cc .. sep .. "%=" .. sep .. rc ---@type string
    self._last_context = context
    self._last_result = final_result

    self._rendering = false
    if self._dirty then
      self:render()
    end
  end)
  return self._last_result or ""
end

return M
