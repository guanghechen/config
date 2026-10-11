---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.support.directory_picker" ---@type string

local M = {}

---@param t                             __test__.support.Harness
---@return __test__.support.UI
---@return string
function M.new(t)
  local directory = vim.fn.tempname()
  vim.fn.mkdir(directory .. "/folder/sub", "p")
  vim.fn.writefile({ "hello" }, directory .. "/alpha.lua")
  vim.fn.writefile({ "other" }, directory .. "/Alpha-two.txt")
  vim.fn.writefile({ "deep" }, directory .. "/folder/sub/deep.txt")
  t:defer(function()
    vim.fn.delete(directory, "rf")
  end)
  local ui = require("__test__.support.ui").new()
  t:defer(function()
    ui:close()
  end)
  ui:rpc("nvim_ui_attach", 140, 42, { rgb = true, ext_linegrid = true })
  ui:rpc(
    "nvim_exec_lua",
    [[
    local root, path = ...
    vim.opt.runtimepath:prepend(root)
    package.path=root.."/?.lua;"..root.."/?/init.lua;"..package.path
    require("ark.bootstrap").setup()
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
    { assert(vim.uv.cwd()), directory }
  )
  t.wait_until(function()
    return ui:rpc(
      "nvim_exec_lua",
      [[
      return surface and surface.view and surface.view:frame() and surface.view:frame():header().row_count==4
    ]],
      {}
    )
  end, 5000)
  return ui, directory
end

return M
