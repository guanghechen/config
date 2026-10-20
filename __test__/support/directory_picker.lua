---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.support.directory_picker" ---@type string

local M = {}

---Opens the Find Explorer picker in a child on a small directory, with the picker's props, composer and result
---surface exposed as the child's globals `props`, `picker` and `surface`.
---@param t                             __test__.support.Harness
---@return __test__.support.UI
---@return string
function M.new(t)
  local directory = t:tempdir()
  vim.fn.mkdir(directory .. "/folder/sub", "p")
  vim.fn.writefile({ "hello" }, directory .. "/alpha.lua")
  vim.fn.writefile({ "other" }, directory .. "/Alpha-two.txt")
  vim.fn.writefile({ "deep" }, directory .. "/folder/sub/deep.txt")
  local ui = require("__test__.support.ui").new()
  t:defer(function()
    ui:close()
  end)
  ui:start({ width = 140, height = 42, runtime = "ark" })
  ui:lua(
    [[
    local path = ...
    errors={}
    stl.reporter.error=function(value) errors[#errors+1]=value end
    local original=era.m.picker.BasicComposer.new
    era.m.picker.BasicComposer.new=function(options)
      props=options
      picker=original(options)
      surface=options.result_tree
      return picker
    end
    require("era.fn.find-explorer")(path.."/alpha.lua")
  ]],
    directory
  )
  ui:wait_until(function()
    return ui:lua([[
      return surface and surface.view and surface.view:frame() and surface.view:frame():header().row_count==4
    ]])
  end, 5000)
  return ui, directory
end

return M
