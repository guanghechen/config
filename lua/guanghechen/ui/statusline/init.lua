local components = {
  left = {
    require("guanghechen.ui.statusline.component.username"),
    require("guanghechen.ui.statusline.component.mode"),
    require("guanghechen.ui.statusline.component.git"),
    require("guanghechen.ui.statusline.component.filepath"),
    require("guanghechen.ui.statusline.component.readonly"),
  },
  middle = {
    require("guanghechen.ui.statusline.component.bg"),
    require("guanghechen.ui.statusline.component.search"),
    require("guanghechen.ui.statusline.component.find_file"),
    require("guanghechen.ui.statusline.component.find_recent"),
    require("guanghechen.ui.statusline.component.bg"),
  },
  right = {
    require("guanghechen.ui.statusline.component.bg"),
    require("guanghechen.ui.statusline.component.diagnostics"),
    require("guanghechen.ui.statusline.component.noice"),
    require("guanghechen.ui.statusline.component.pos"),
    require("guanghechen.ui.statusline.component.fileformat"),
    require("guanghechen.ui.statusline.component.copilot"),
    require("guanghechen.ui.statusline.component.lsp"),
    require("guanghechen.ui.statusline.component.filetype"),
    require("guanghechen.ui.statusline.component.cwd"),
  },
}

local M = {}

M.colors = {}
M.modules_left = {}
M.modules_middle = {}
M.modules_right = {}
M.order_left = {}
M.order_middle = {}
M.order_right = {}

for _, component in ipairs(components.left) do
  for name, color in pairs(component.color) do
    M.colors[component.name .. "_" .. name] = color
  end

  table.insert(M.order_left, component.name)
  M.modules_left[component.name] = function()
    if not component.condition() then
      return ""
    end

    return component.renderer()
  end
end

for _, component in ipairs(components.middle) do
  for name, color in pairs(component.color) do
    M.colors[component.name .. "_" .. name] = color
  end

  table.insert(M.order_middle, component.name)
  M.modules_middle[component.name] = function()
    if not component.condition() then
      return ""
    end

    return component.renderer()
  end
end

for _, component in ipairs(components.right) do
  for name, color in pairs(component.color) do
    M.colors[component.name .. "_" .. name] = color
  end

  table.insert(M.order_right, component.name)
  M.modules_right[component.name] = function()
    if not component.condition() then
      return ""
    end

    return component.renderer()
  end
end

return M
