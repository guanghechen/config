local nvimbar = require("fml.std.nvimbar")
local path = require("fml.std.path")
local reporter = require("fml.std.reporter")
local truthy = require("fml.fn.truthy")
local calc_fileicon = require("fml.fn.calc_fileicon")

---@class fml.ui.Nvimbar : fml.types.ui.INvimbar
---@field public name                   string
---@field private preset_context        fml.types.ui.nvimbar.IPresetContext
---@field private sep                   string
---@field private sep_width             integer
---@field private dirty                 boolean
---@field private rendering             boolean
---@field private last_result           string|nil
---@field private last_context          fml.types.ui.nvimbar.IContext|nil
---@field private components            fml.types.ui.nvimbar.IComponent[]
local M = {}
M.__index = M

---@class fml.ui.nvimbar.IProps
---@field public name                   string
---@field public component_sep          string
---@field public component_sep_hlname   string
---@field public preset_context         ?fml.types.ui.nvimbar.IPresetContext

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
  local fileicon = calc_fileicon(filepath) ---@type string
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

  local self = setmetatable({}, M)
  self.name = name
  self.preset_context = preset_context
  self.sep = nvimbar.txt(component_sep, component_sep_hlname)
  self.sep_width = vim.fn.strwidth(component_sep)
  self.dirty = true
  self.rendering = false
  self.last_result = nil
  self.last_context = nil
  self.components = {}
  return self
end

---@param position                      fml.enums.nvimbar.ComponentPosition
---@param raw_component                 fml.types.ui.nvimbar.IRawComponent
---@return fml.ui.Nvimbar
function M:add(position, raw_component)
  ---@type fml.types.ui.nvimbar.IComponent
  local component = {
    name = raw_component.name,
    position = position,
    last_result_text = "",
    last_result_width = 0,
    render = raw_component.render,
    will_change = raw_component.will_change or truthy,
    condition = raw_component.condition or truthy,
  }
  table.insert(self.components, component)
  return self
end

---@return string
function M:render()
  self:internal_render()
  return self.last_result or ""
end

---@return nil
function M:internal_render()
  if self.rendering then
    self.dirty = true
    vim.schedule(function()
      self:internal_render()
    end)
    return
  end

  self.rendering = true

  local sep = self.sep ---@type string
  local sep_width = self.sep_width ---@type integer
  local context = build_context(self.preset_context) ---@type fml.types.ui.nvimbar.IContext
  local prev_context = self.last_context ---@type fml.types.ui.nvimbar.IContext|nil

  local lc = "" ---@type string
  local cc = "" ---@type string
  local rc = "" ---@type string
  local remain_width = vim.o.columns - sep_width - sep_width ---@type integer
  local components = self.components ---@type fml.types.ui.nvimbar.IComponent[]
  for i = 1, #components, 1 do
    local component = components[i] ---@type fml.types.ui.nvimbar.IComponent
    local ok, err = pcall(render_component, component, context, prev_context, remain_width)
    if ok then
      local text = component.last_result_text ---@type string
      local width = component.last_result_width ---@type integer
      if width > 0 then
        if component.position == "left" then
          if #lc > 0 then
            lc = lc .. sep .. text
            remain_width = remain_width - width - sep_width - sep_width
          else
            lc = text
            remain_width = remain_width - width - sep_width
          end
        elseif component.position == "center" then
          if #cc > 0 then
            cc = cc .. sep .. text
            remain_width = remain_width - width - sep_width - sep_width
          else
            cc = text
            remain_width = remain_width - width - sep_width
          end
        elseif component.position == "right" then
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
            subject = "add",
            message = "Bad component position.",
            details = { component = component },
          })
        end
      end
    else
      reporter.error({
        from = "fml.ui.nvimbar",
        subject = "render_components",
        message = "Encounter error while render the nvimbar component.",
        details = { name = component.name, error = err },
      })
    end
  end

  local final_result = lc .. sep .. "%=" .. sep .. cc .. sep .. "%=" .. sep .. rc ---@type string
  self.last_context = context
  self.last_result = final_result
  self.dirty = false
  self.rendering = false
end

return M
