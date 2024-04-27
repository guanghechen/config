local components = {
  left = {
    require("ghc.ui.bufferline.component.neotree"),
  },
  right = {},
}

local M = {}

M.colors = {}
M.modules_left = {}
M.modules_right = {}
M.order_left = {}
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

    return component.renderer_left()
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
    return component.renderer_right()
  end
end

return M
