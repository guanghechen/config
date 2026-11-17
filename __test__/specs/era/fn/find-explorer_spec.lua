local t = require("__test__.support.harness").new()
local fixture = require("__test__.support.directory_picker")

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

t:test("an action typed right after a query reads the rows of that query", function()
  local ui, path = fixture.new(t)
  -- One burst, as fast typing gives it: <CR> runs before the 64 ms filter debounce does.
  ui:rpc("nvim_input", "itwo<CR>")
  ui:wait_lua([[return vim.api.nvim_buf_get_name(0):match("Alpha%-two%.txt$") ~= nil]], 8000, "Alpha-two.txt opened")
  t.assert_eq(
    vim.uv.fs_realpath(path .. "/Alpha-two.txt"),
    vim.uv.fs_realpath(ui:lua("return vim.api.nvim_buf_get_name(0)"))
  )
end)

t:test("native create/copy/rename/delete update the current directory and editor buffers", function()
  local ui, path = fixture.new(t)
  actions(ui)
  -- The answer is relative to the cwd, which is not the listed directory.
  ui:lua([[local path=...; action("alpha.lua","c",path.."/copied.lua")]], path)
  ui:wait_lua([[return present("copied.lua") and not require("era.m.filetree.jobs").pending()]], 8000, "copy listed")
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
  ui:wait_lua(
    [[return present("renamed.lua") and not present("copied.lua") and not require("era.m.filetree.jobs").pending()]],
    8000,
    "rename listed"
  )
  t.assert_eq(vim.uv.fs_realpath(path .. "/renamed.lua"), ui:lua("return vim.api.nvim_buf_get_name(renamed_buffer)"))
  t.assert_nil(vim.uv.fs_stat(path .. "/copied.lua"))
  ui:lua([[action("../","a","new-dir/")]])
  ui:wait_lua(
    [[return present("new-dir") and not require("era.m.filetree.jobs").pending()]],
    8000,
    "new directory listed"
  )
  t.assert_eq("directory", vim.uv.fs_stat(path .. "/new-dir").type)
  ui:lua([[action("new-dir","od","yes")]])
  ui:wait_lua(
    [[return not present("new-dir") and not require("era.m.filetree.jobs").pending()]],
    8000,
    "deleted directory unlisted"
  )
  ui:wait_lua(
    [[return not surface._focus and select(2,surface:retrieve(picker.result.lnum_current:snapshot()))==false]],
    8000,
    "cursor settled off the parent row"
  )
  t.assert_nil(vim.uv.fs_stat(path .. "/new-dir"))
  t.assert_eq(0, ui:lua("return #errors"), vim.inspect(ui:lua("return errors")))
end)

t:test("oi shows the details of the row, oa adds it to AI, and a creates from the result window only", function()
  local ui, path = fixture.new(t)
  actions(ui)
  ui:lua([[
    shown, added = {}, {}
    require("era.m.filetree.jobs").show_info = function(filepath)
      shown[#shown + 1] = filepath
      return stl.c.Future.resolve()
    end
    era.fn.add_locations_to_ai = function(locations)
      added[#added + 1] = locations[1].filepath
    end
    action("alpha.lua", "oi")
    action("alpha.lua", "oa")
  ]])
  t.assert_same({ path .. "/alpha.lua" }, ui:lua("return shown"))
  t.assert_same({ path .. "/alpha.lua" }, ui:lua("return added"))
  local function binding(keymaps, key)
    return ui:lua(
      "for _, keymap in ipairs(props."
        .. keymaps
        .. ") do if keymap.key == ... then return { desc = keymap.desc, modes = keymap.modes } end end",
      key
    )
  end
  -- Normal mode only, as in the Explorer.
  t.assert_same({ desc = "filetree: create", modes = { "n" } }, binding("keymaps_result", "a"))
  t.assert_same({ desc = "filetree: file info", modes = { "n" } }, binding("keymaps_result", "oi"))
  t.assert_nil(binding("keymaps_finder", "a"), "a edits the query in the finder")
  t.assert_eq(0, ui:lua("return #errors"))
end)

t:test("l enters a directory and h returns to its parent, from the result window only", function()
  local ui = fixture.new(t)
  actions(ui)
  ui:lua([[action("folder", "l")]])
  ui:wait_lua([[return present("sub")]], 8000, "l entered the directory")
  ui:lua([[action("sub", "h")]])
  ui:wait_lua([[return present("alpha.lua")]], 8000, "h returned to the parent")
  local finder_keys = ui:lua([[
    local keys = {}
    for _, keymap in ipairs(props.keymaps_finder) do
      if keymap.key == "l" or keymap.key == "h" then keys[#keys + 1] = keymap.key end
    end
    return keys
  ]])
  t.assert_same({}, finder_keys, "l and h edit the query in the finder")
  t.assert_eq(0, ui:lua("return #errors"))
end)

t:test("completion preserves navigation made while the file operation was running", function()
  local ui, path = fixture.new(t)
  actions(ui)
  ui:lua(
    [[
    local path=...
    require("era.m.filetree.jobs").run=function()
      local future,resolve=stl.c.Future.new_with_resolver()
      finish_operation=resolve
      return future
    end
    action("alpha.lua","c",path.."/copy.lua")
    choose("Alpha-two.txt")
  ]],
    path
  )
  ui:wait_lua("return finish_operation~=nil", 8000, "copy started")
  ui:lua([[finish_operation({success=true,status={},items={{status="success"}}})]])
  ui:wait_lua(
    [[return not surface._focus and surface:retrieve(picker.result.lnum_current:snapshot()):info().label=="Alpha-two.txt"]],
    8000,
    "cursor kept on Alpha-two.txt"
  )
  t.assert_eq(0, ui:lua("return #errors"))
end)

t:test("parent guards, a declined overwrite, and captured resource identity survive prompts", function()
  local ui, path = fixture.new(t)
  actions(ui)
  ui:lua([[action("../","od","yes"); action("../","c","copy"); action("../","or","renamed")]])
  t.assert_eq(0, ui:lua("return #prompts"))
  t.assert_eq(3, ui:lua("return #errors"))
  -- Every prompt of the action takes the same answer, so the overwrite confirmation is declined.
  ui:lua([[local path=...; errors={}; action("alpha.lua","c",path.."/Alpha-two.txt")]], path)
  ui:wait_lua([[return #prompts==2 and not require("era.m.filetree.jobs").pending()]], 8000, "overwrite asked")
  t.assert_true(ui:lua("return prompts[2].prompt"):find("Overwrite existing target?", 1, true) ~= nil)
  t.assert_eq("other", vim.fn.readfile(path .. "/Alpha-two.txt")[1])
  t.assert_eq(0, ui:lua("return #errors"), vim.inspect(ui:lua("return errors")))
  ui:lua([[errors={}; action("alpha.lua","or",nil,true)]])
  assert(vim.uv.fs_rename(path .. "/alpha.lua", path .. "/saved.lua"))
  vim.fn.writefile({ "replacement" }, path .. "/alpha.lua")
  ui:lua([[pending_prompt("moved.lua")]])
  ui:wait_lua(
    [[return #errors>0 and not require("era.m.filetree.jobs").pending()]],
    8000,
    "move of a replaced file refused"
  )
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
    ui:wait_lua([[return present("only-other.txt")]], 8000, "relative path listed")
    t.assert_eq(
      vim.uv.fs_realpath(path .. "/other/sub"),
      ui:lua([[return surface.data:inspect(surface:frame():source(),surface:frame():header().root.node):path()]])
    )
    ui:lua([[picker:hide(); require("era.fn.find-explorer")()]])
    ui:wait_lua([[return present("only-other.txt")]], 8000, "remembered directory listed")
    ui:lua([[picker:hide(); require("era.fn.find-explorer")(...)]], path .. "/folder/sub")
    ui:wait_lua([[return present("deep.txt") and not present("only-other.txt")]], 8000, "absolute path listed")
    t.assert_eq(0, ui:lua("return #errors"))
  end)
end

t:run()
