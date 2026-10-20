local t = require("__test__.support.harness").new()
local fixture = require("__test__.support.directory_picker")

---@param ui                            __test__.support.UI
---@param expression                    string
---@return nil
local function wait(ui, expression)
  local started = vim.uv.hrtime()
  ui:wait_until(function()
    t.assert_true(vim.uv.hrtime() - started < 8000000000, expression)
    return ui:lua("return " .. expression)
  end, 8000)
end

---@param ui                            __test__.support.UI
---@return nil
local function actions(ui)
  ui:lua([[
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
  ]])
end

t:test("native create/copy/rename/delete update the current directory and editor buffers", function()
  local ui, path = fixture.new(t)
  actions(ui)
  ui:lua([[action("alpha.lua","c","copied.lua")]])
  wait(ui, [[present("copied.lua") and not require("era.m.filetree.jobs").pending()]])
  t.assert_true(vim.uv.fs_stat(path .. "/copied.lua") ~= nil)
  ui:lua(
    [[
    local path=...
    renamed_buffer=vim.api.nvim_create_buf(true,false)
    vim.api.nvim_buf_set_name(renamed_buffer,path.."/copied.lua")
    action("copied.lua","or","renamed.lua")
  ]],
    path
  )
  wait(ui, [[present("renamed.lua") and not present("copied.lua") and not require("era.m.filetree.jobs").pending()]])
  t.assert_eq(vim.uv.fs_realpath(path .. "/renamed.lua"), ui:lua("return vim.api.nvim_buf_get_name(renamed_buffer)"))
  t.assert_nil(vim.uv.fs_stat(path .. "/copied.lua"))
  ui:lua([[action("../","oa","new-dir/")]])
  wait(ui, [[present("new-dir") and not require("era.m.filetree.jobs").pending()]])
  t.assert_eq("directory", vim.uv.fs_stat(path .. "/new-dir").type)
  ui:lua([[action("new-dir","od","yes")]])
  wait(ui, [[not present("new-dir") and not require("era.m.filetree.jobs").pending()]])
  wait(ui, [[not surface._focus and select(2,surface:retrieve(picker.result.lnum_current:snapshot()))==false]])
  t.assert_nil(vim.uv.fs_stat(path .. "/new-dir"))
  t.assert_eq(0, ui:lua("return #errors"))
end)

t:test("completion preserves navigation made while the file operation was running", function()
  local ui = fixture.new(t)
  actions(ui)
  ui:lua([[
    require("era.m.filetree.jobs").run=function()
      local future,resolve=stl.c.Future.new_with_resolver()
      finish_operation=resolve
      return future
    end
    action("alpha.lua","c","copy.lua")
    choose("Alpha-two.txt")
    finish_operation({success=true,status={},items={{status="success"}}})
  ]])
  wait(
    ui,
    [[not surface._focus and surface:retrieve(picker.result.lnum_current:snapshot()):info().label=="Alpha-two.txt"]]
  )
  t.assert_eq(0, ui:lua("return #errors"))
end)

t:test("parent guards, no overwrite, and captured resource identity survive prompts", function()
  local ui, path = fixture.new(t)
  actions(ui)
  ui:lua([[action("../","od","yes"); action("../","c","copy"); action("../","or","renamed")]])
  t.assert_eq(0, ui:lua("return #prompts"))
  t.assert_eq(3, ui:lua("return #errors"))
  ui:lua([[errors={}; action("alpha.lua","c","Alpha-two.txt")]])
  wait(ui, [[#errors>0 and not require("era.m.filetree.jobs").pending()]])
  t.assert_eq("other", vim.fn.readfile(path .. "/Alpha-two.txt")[1])
  ui:lua([[errors={}; action("alpha.lua","or",nil,true)]])
  assert(vim.uv.fs_rename(path .. "/alpha.lua", path .. "/saved.lua"))
  vim.fn.writefile({ "replacement" }, path .. "/alpha.lua")
  ui:lua([[pending_prompt("moved.lua")]])
  wait(ui, [[#errors>0 and not require("era.m.filetree.jobs").pending()]])
  t.assert_nil(vim.uv.fs_stat(path .. "/moved.lua"))
  t.assert_eq("replacement", vim.fn.readfile(path .. "/alpha.lua")[1])
  t.assert_eq("hello", vim.fn.readfile(path .. "/saved.lua")[1])
end)

for _, command in ipairs({ "cd", "lcd", "tcd" }) do
  t:test(command .. " changes the base of explicit relative paths and preserves the remembered directory", function()
    local ui, path = fixture.new(t)
    vim.fn.mkdir(path .. "/other/sub", "p")
    vim.fn.writefile({ "other" }, path .. "/other/sub/only-other.txt")
    actions(ui)
    ui:lua(
      [[
      local path, command = ...
      picker:hide()
      vim.cmd[command]({args={path.."/other"}})
      require("era.fn.find-explorer")("sub")
    ]],
      path,
      command
    )
    wait(ui, [[present("only-other.txt")]])
    t.assert_eq(
      vim.uv.fs_realpath(path .. "/other/sub"),
      ui:lua([[return surface.data:inspect(surface:frame():source(),surface:frame():header().root.node):path()]])
    )
    ui:lua([[picker:hide(); require("era.fn.find-explorer")()]])
    wait(ui, [[present("only-other.txt")]])
    ui:lua([[picker:hide(); require("era.fn.find-explorer")(...)]], path .. "/folder/sub")
    wait(ui, [[present("deep.txt") and not present("only-other.txt")]])
    t.assert_eq(0, ui:lua("return #errors"))
  end)
end

t:run()
