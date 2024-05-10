local components = {
  left = {
    require("ghc.ui.statusline.component.username"),
    require("ghc.ui.statusline.component.mode"),
    require("ghc.ui.statusline.component.git"),
  },
  left_c = {
    require("ghc.ui.statusline.component.filepath"),
    require("ghc.ui.statusline.component.bg"),
  },
  right_x = {
    require("ghc.ui.statusline.component.bg"),
    require("ghc.ui.statusline.component.noice"),
    require("ghc.ui.statusline.component.pos"),
    require("ghc.ui.statusline.component.fileformat"),
    require("ghc.ui.statusline.component.filetype"),
    require("ghc.ui.statusline.component.cwd"),
  },
  right = {},
}

local function get_leftest_name()
  local i = 1
  while i <= #components.right do
    local component = components.right[i]
    if component.condition() then
      return component.name
    end
    i = i + 1
  end
  return nil
end

local function get_rightest_name()
  local i = #components.left
  while i >= 1 do
    local component = components.left[i]
    if component.condition() then
      return component.name
    end
    i = i - 1
  end
  return nil
end

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

    local rightest_name = get_rightest_name()
    local is_rightest = rightest_name == component.name
    return component.renderer_left({ is_rightest = is_rightest })
  end
end
for _, component in ipairs(components.left_c) do
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
for _, component in ipairs(components.right_x) do
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
for _, component in ipairs(components.right) do
  for name, color in pairs(component.color) do
    M.colors[component.name .. "_" .. name] = color
  end

  table.insert(M.order_right, component.name)
  M.modules_right[component.name] = function()
    if not component.condition() then
      return ""
    end

    local leftest_name = get_leftest_name()
    local is_leftest = leftest_name == component.name
    return component.renderer_right({ is_leftest = is_leftest })
  end
end

return M
