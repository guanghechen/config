local t = require("__test__.support.harness").new()

-- Every Diffview module loads while era and dot raise on any access: modules read them when used, not at load.

local root = assert(vim.uv.cwd()) ---@type string

---@param name                          string
---@return table
local function trap(name)
  return setmetatable({}, {
    __index = function(_, key)
      error(string.format("%s.%s read while loading", name, tostring(key)), 2)
    end,
    __newindex = function(_, key)
      error(string.format("%s.%s written while loading", name, tostring(key)), 2)
    end,
  })
end

local modules = {} ---@type string[]
for _, path in ipairs(vim.fn.globpath(root .. "/lua/era/m/diffview", "**/*.lua", false, true)) do
  modules[#modules + 1] = path:sub(#root + 6, -5):gsub("/", "."):gsub("%.init$", "")
end
table.sort(modules)

t:patch_global("stl", require("stl"))
t:patch_global("yoz", require("yoz"))

for _, name in ipairs(modules) do
  t:test("loads without reading era or dot: " .. name, function()
    local function unload()
      for loaded in pairs(package.loaded) do
        if loaded:match("^era%.") or loaded:match("^dot%.") then
          package.loaded[loaded] = nil
        end
      end
    end
    unload()
    t:defer(unload)
    t:patch_global("era", trap("era"))
    t:patch_global("dot", trap("dot"))
    require(name)
  end)
end

t:run()
