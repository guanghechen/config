local components = {
  left = {
    require("ghc.ui.statusline.component.username"),
    require("ghc.ui.statusline.component.mode"),
    require("ghc.ui.statusline.component.git"),
    require("ghc.ui.statusline.component.filepath"),
  },
  middle = {
    require("ghc.ui.statusline.component.bg"),
    require("ghc.ui.statusline.component.search"),
    require("ghc.ui.statusline.component.find_file"),
    require("ghc.ui.statusline.component.find_recent"),
    require("ghc.ui.statusline.component.bg"),
  },
  right = {
    require("ghc.ui.statusline.component.bg"),
    require("ghc.ui.statusline.component.noice"),
    require("ghc.ui.statusline.component.pos"),
    require("ghc.ui.statusline.component.fileformat"),
    require("ghc.ui.statusline.component.filetype"),
    require("ghc.ui.statusline.component.cwd"),
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
