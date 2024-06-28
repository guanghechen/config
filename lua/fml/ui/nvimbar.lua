local reporter = require("fml.std.reporter")
local truthy = require("fml.fn.truthy")

---@class fml.ui.Nvimbar : fml.types.ui.INvimbar
---@field private sep                   string
---@field private dirty                 boolean
---@field private rendering             boolean
---@field private last_result           string|nil
---@field private last_context          fml.types.ui.nvimbar.IContext|nil
---@field private left_components       fml.types.ui.nvimbar.IComponent[]
---@field private center_components     fml.types.ui.nvimbar.IComponent[]
---@field private right_components      fml.types.ui.nvimbar.IComponent[]
local M = {}

---@class fml.ui.nvimbar.IProps
---@field public component_sep          string

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

---@return fml.types.ui.nvimbar.IContext
local function build_context()
  local m = modes_map[vim.api.nvim_get_mode().mode]
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  local cwd = fml.path.cwd() ---@type string
  local filepath = vim.fn.expand("%:p") ---@type string
  local fileicon = fml.fn.calc_fileicon(filepath) ---@type string
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
---@return string
local function render_component(component, context, prev_context)
  if not component.will_change(context, prev_context) then
    return component.last_result
  end

  if not component.condition(context) then
    return ""
  end

  return component.render(context)
end

---@param components                    fml.types.ui.nvimbar.IComponent[]
---@param context                       fml.types.ui.nvimbar.IContext
---@param prev_context                  fml.types.ui.nvimbar.IContext|nil
---@param sep                           string
---@return string
local function render_components(components, context, prev_context, sep)
  local results = {} ---@type string[]
  for _, component in ipairs(components) do
    local ok, result = pcall(render_component, component, context, prev_context)
    if ok then
      if #result > 0 then
        component.last_result = result
        table.insert(results, result)
      end
    else
      reporter.error({
        from = "fml.ui.nvimbar",
        subject = "render_components",
        message = "Encounter error while render the nvimbar component.",
        details = { name = component.name, error = result },
      })
    end
  end
  return table.concat(results, sep)
end

---@param props                         fml.ui.nvimbar.IProps
---@return fml.ui.Nvimbar
function M.new(props)
  local self = setmetatable({}, M)
  self.sep = props.component_sep
  self.dirty = true
  self.rendering = false
  self.last_result = nil
  self.last_context = nil
  self.left_components = {}
  self.center_components = {}
  self.right_components = {}
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
    last_result = "",
    render = raw_component.render,
    will_change = raw_component.will_change or truthy,
    condition = raw_component.condition or truthy,
  }

  if position == "left" then
    table.insert(self.left_components, component)
  elseif position == "center" then
    table.insert(self.center_components, component)
  elseif position == "right" then
    table.insert(self.right_components, 1, component)
  else
    reporter.error({
      from = "fml.ui.nvimbar",
      subject = "add",
      message = "Bad component position.",
      details = { position = position, component = component },
    })
  end
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

  local context = build_context() ---@type fml.types.ui.nvimbar.IContext
  local prev_context = self.last_context ---@type fml.types.ui.nvimbar.IContext|nil

  local left_results = render_components(self.left_components, context, prev_context, self.sep) ---@type string
  local center_results = render_components(self.center_components, context, prev_context, self.sep) ---@type string
  local right_results = render_components(self.right_components, context, prev_context, self.sep) ---@type string
  local final_result = left_results
      .. self.sep
      .. "%="
      .. self.sep
      .. center_results
      .. self.sep
      .. "%="
      .. self.sep
      .. right_results

  self.last_context = context
  self.last_result = final_result
  self.dirty = false
  self.rendering = false
end

return M
