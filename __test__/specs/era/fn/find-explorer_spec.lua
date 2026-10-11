---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.era.fn.find_explorer" ---@type string

local t = require("__test__.support.harness").new("era.fn.find_explorer")
local fixture = require("__test__.support.directory_picker")

---@param ui                            __test__.support.UI
---@param expression                    string
---@return nil
local function wait(ui, expression)
  local started = vim.uv.hrtime()
  t.wait_until(function()
    t.assert_true(vim.uv.hrtime() - started < 8000000000, expression)
    return ui:rpc("nvim_exec_lua", "return " .. expression, {})
  end, 8000)
end

---@param ui                            __test__.support.UI
---@return nil
local function actions(ui)
  ui:rpc(
    "nvim_exec_lua",
    [[
    prompts={}
    stl.reporter.info=function() end
    ---@param label                     string
    ---@return nil
    function choose(label)
      local frame=surface:frame()
      local rows=frame:rows(1,frame:header().row_count)
      for row,value in ipairs(rows.labels) do
        if value==label or value==label.."/" then picker.result:set_lnum_current(row); return end
      end
      error("missing row "..label)
    end
    ---@param label                     string
    ---@param key                       string
    ---@param input                     ?string
    ---@param hold                      ?boolean
    ---@return nil
    function action(label,key,input,hold)
      choose(label)
      vim.ui.input=function(options,callback)
        prompts[#prompts+1]=options
        if hold then pending_prompt=callback else callback(input) end
      end
      for _,binding in ipairs(props.keymaps_result) do
        if binding.key==key then binding.callback(); return end
      end
      error("missing action "..key)
    end
    ---@param label                     string
    ---@return boolean
    function present(label)
      local frame=surface:frame()
      local labels=frame:rows(1,frame:header().row_count).labels
      return vim.list_contains(labels,label) or vim.list_contains(labels,label.."/")
    end
  ]],
    {}
  )
end

t:test("native create/copy/rename/delete update the current directory and editor buffers", function()
  local ui, path = fixture.new(t)
  actions(ui)
  ui:rpc("nvim_exec_lua", [[action("alpha.lua","c","copied.lua")]], {})
  wait(ui, [[present("copied.lua") and not require("era.m.filetree.jobs").pending()]])
  t.assert_true(vim.uv.fs_stat(path .. "/copied.lua") ~= nil)
  ui:rpc(
    "nvim_exec_lua",
    [[
    local path=...
    renamed_buffer=vim.api.nvim_create_buf(true,false)
    vim.api.nvim_buf_set_name(renamed_buffer,path.."/copied.lua")
    action("copied.lua","or","renamed.lua")
  ]],
    { path }
  )
  wait(ui, [[present("renamed.lua") and not present("copied.lua") and not require("era.m.filetree.jobs").pending()]])
  t.assert_eq(
    vim.uv.fs_realpath(path .. "/renamed.lua"),
    ui:rpc("nvim_exec_lua", "return vim.api.nvim_buf_get_name(renamed_buffer)", {})
  )
  t.assert_nil(vim.uv.fs_stat(path .. "/copied.lua"))
  ui:rpc("nvim_exec_lua", [[action("../","oa","new-dir/")]], {})
  wait(ui, [[present("new-dir") and not require("era.m.filetree.jobs").pending()]])
  t.assert_eq("directory", vim.uv.fs_stat(path .. "/new-dir").type)
  ui:rpc("nvim_exec_lua", [[action("new-dir","od","yes")]], {})
  wait(ui, [[not present("new-dir") and not require("era.m.filetree.jobs").pending()]])
  wait(ui, [[not surface._focus and select(2,surface:retrieve(picker.result.lnum_current:snapshot()))==false]])
  t.assert_nil(vim.uv.fs_stat(path .. "/new-dir"))
  t.assert_eq(0, ui:rpc("nvim_exec_lua", "return #errors", {}))
end)

t:test("completion preserves navigation made while the file operation was running", function()
  local ui = fixture.new(t)
  actions(ui)
  ui:rpc(
    "nvim_exec_lua",
    [[
    require("era.m.filetree.jobs").run=function()
      local future,resolve=stl.c.Future.new_with_resolver()
      finish_operation=resolve
      return future
    end
    action("alpha.lua","c","copy.lua")
    choose("Alpha-two.txt")
    finish_operation({success=true,status={},items={{status="success"}}})
  ]],
    {}
  )
  wait(
    ui,
    [[not surface._focus and surface:retrieve(picker.result.lnum_current:snapshot()):info().label=="Alpha-two.txt"]]
  )
  t.assert_eq(0, ui:rpc("nvim_exec_lua", "return #errors", {}))
end)

t:test("parent guards, no overwrite, and captured resource identity survive prompts", function()
  local ui, path = fixture.new(t)
  actions(ui)
  ui:rpc("nvim_exec_lua", [[action("../","od","yes"); action("../","c","copy"); action("../","or","renamed")]], {})
  t.assert_eq(0, ui:rpc("nvim_exec_lua", "return #prompts", {}))
  t.assert_eq(3, ui:rpc("nvim_exec_lua", "return #errors", {}))
  ui:rpc("nvim_exec_lua", [[errors={}; action("alpha.lua","c","Alpha-two.txt")]], {})
  wait(ui, [[#errors>0 and not require("era.m.filetree.jobs").pending()]])
  t.assert_eq("other", vim.fn.readfile(path .. "/Alpha-two.txt")[1])
  ui:rpc("nvim_exec_lua", [[errors={}; action("alpha.lua","or",nil,true)]], {})
  assert(vim.uv.fs_rename(path .. "/alpha.lua", path .. "/saved.lua"))
  vim.fn.writefile({ "replacement" }, path .. "/alpha.lua")
  ui:rpc("nvim_exec_lua", [[pending_prompt("moved.lua")]], {})
  wait(ui, [[#errors>0 and not require("era.m.filetree.jobs").pending()]])
  t.assert_nil(vim.uv.fs_stat(path .. "/moved.lua"))
  t.assert_eq("replacement", vim.fn.readfile(path .. "/alpha.lua")[1])
  t.assert_eq("hello", vim.fn.readfile(path .. "/saved.lua")[1])
end)

t:run()
