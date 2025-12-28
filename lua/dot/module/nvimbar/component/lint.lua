local btn = ark.vim.fn.btn
local txt = ark.vim.fn.txt

local disabled_linters = {} ---@type table<string, boolean>

---@return string[]
local function get_available_linters()
  local ok, lint = pcall(require, "lint")
  if not ok then
    return {}
  end

  local filetype = vim.bo.filetype ---@type string
  local names = lint._resolve_linter_by_ft(filetype) ---@type string[]
  names = vim.list_slice(names)
  vim.list_extend(names, lint.linters_by_ft["_"] or {})
  vim.list_extend(names, lint.linters_by_ft["*"] or {})
  return names
end

---@return string[]
local function get_running_linters()
  local ok, lint = pcall(require, "lint")
  if not ok then
    return {}
  end
  return lint.get_running()
end

---@param name                          string
---@return boolean
local function is_linter_enabled(name)
  return not disabled_linters[name]
end

---@param name                          string
local function toggle_linter(name)
  disabled_linters[name] = not disabled_linters[name]
  dot.state.status.dirtier_statusline:mark_dirty()
end

---@type string
local fn_open_selector = ark.G.register_anonymous_fn(function()
  local linters = get_available_linters() ---@type string[]
  if #linters == 0 then
    ark.reporter.info({
      from = "dot.module.nvimbar.component.lint",
      message = "No linters available for this filetype",
    })
    return
  end

  local items = {} ---@type { name: string, enabled: boolean }[]
  for _, name in ipairs(linters) do
    table.insert(items, { name = name, enabled = is_linter_enabled(name) })
  end

  vim.ui.select(items, {
    prompt = "Toggle Linter",
    format_item = function(item)
      local icon = item.enabled and "✓ " or "  "
      return icon .. item.name
    end,
  }, function(choice)
    if choice then
      toggle_linter(choice.name)
    end
  end)
end)

---@class dot.module.nvimbar.component.lint
local M = {}

M.disabled_linters = disabled_linters
M.is_linter_enabled = is_linter_enabled

---@param position                      ark.e.NvimbarPositionEnum
---@return dot.module.nvimbar.IRawComponent
function M.status(position)
  local hln_icon_active = position .. "_lint_icon_active" ---@type string
  local hln_icon_inactive = position .. "_lint_icon_inactive" ---@type string
  local hln_text = position .. "_lint_text" ---@type string

  ---@type dot.module.nvimbar.IRawComponent
  local component = {
    name = "lint:status",
    atomic = true,
    render = function()
      local running = get_running_linters() ---@type string[]
      local available = get_available_linters() ---@type string[]

      local enabled_names = {} ---@type string[]
      for _, name in ipairs(available) do
        if is_linter_enabled(name) then
          table.insert(enabled_names, name)
        end
      end

      local icon = " " ---@type string
      local display_text ---@type string
      local hln_icon ---@type string

      if #running > 0 then
        display_text = table.concat(running, ",")
        hln_icon = hln_icon_active
      elseif #enabled_names > 0 then
        display_text = table.concat(enabled_names, ",")
        hln_icon = hln_icon_active
      else
        display_text = ""
        hln_icon = hln_icon_inactive
      end

      local text = icon .. display_text ---@type string
      local hl_text = btn(txt(icon, hln_icon) .. txt(display_text, hln_text), fn_open_selector) ---@type string
      return text, hl_text, true
    end,
  }
  return component
end

return M
