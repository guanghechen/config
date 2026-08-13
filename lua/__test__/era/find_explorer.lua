---@diagnostic disable: invisible
--- Run with: nvim -l lua/__test__/era/find_explorer.lua

local harness = require("__test__.harness")
require("ark.bootstrap").setup()

local t = harness.new("era.find_explorer")

---@param filetype                     "directory"|"file"
---@param filename                     string
---@return yoz.fs.IFileItemWithStatus
local function raw_item(filetype, filename)
  return {
    type = filetype,
    name = filename,
    perm = "-rw-r--r--",
    size = "1 B",
    owner = "alice",
    group = "users",
    date = "2026-08-13 12:00",
  }
end

---@class era.find_explorer.IFixture
---@field public props                  table
---@field public picker                 table
---@field public scans                  string[]
---@field public existence_checks       string[]
---@field public data                   era.m.picker.composer.list.IResetData|nil
---@field public current_item           era.fn.find_explorer.IItem|nil
---@field public focused                boolean
---@field public find_explorer          fun(specified_filepath: string|nil): nil

---@return era.find_explorer.IFixture
local function new_fixture()
  local fixture = {
    props = nil,
    picker = nil,
    scans = {},
    existence_checks = {},
    data = nil,
    current_item = nil,
    focused = false,
    find_explorer = nil,
  } ---@type era.find_explorer.IFixture

  local lnum_current = stl.c.Observable.from_value(1)
  local picker = {
    result = {
      lnum_current = lnum_current,
      get_winnr = function()
        return vim.api.nvim_get_current_win()
      end,
      set_lnum_current = function(_, lnum)
        lnum_current:next(lnum, { silent = true })
      end,
    },
    close = function() end,
    focus = function()
      fixture.focused = true
    end,
    isdisposed = function()
      return true
    end,
    reset_data = function(_, data)
      fixture.data = data
    end,
    retrieve = function(_, lnum)
      if fixture.current_item ~= nil then
        return fixture.current_item
      end
      return fixture.data and fixture.data.items[lnum] or nil
    end,
  }
  fixture.picker = picker

  t:patch_table(yoz.canonical_path, "get_cwd", function()
    return [[C:\workspace\project\]]
  end)
  t:patch_table(yoz.canonical_path, "to_os_path", function(filepath)
    return "OS<" .. filepath .. ">"
  end)
  t:patch_table(dot.path, "workspace", function()
    return [[C:\workspace\project\]]
  end)
  t:patch_table(dot.tab, "retrieve_winnr_sourcefile", function()
    return nil
  end)
  t:patch_table(yoz.path, "is_exist_directory", function(filepath)
    fixture.existence_checks[#fixture.existence_checks + 1] = filepath
    return filepath == "OS<C:/workspace/project/src>"
  end)
  t:patch_table(yoz.path, "is_exist_file", function(filepath)
    fixture.existence_checks[#fixture.existence_checks + 1] = filepath
    return filepath == "OS<C:/workspace/project/src/main.lua>"
  end)
  t:patch_table(yoz.fs, "readdir", function(dirpath)
    fixture.scans[#fixture.scans + 1] = dirpath
    return {
      itself = raw_item("directory", "src"),
      items = { raw_item("file", "main.lua") },
    }, nil
  end)
  t:patch_table(era.m.picker.ListComposer, "new", function(props)
    fixture.props = props
    return picker
  end)

  fixture.find_explorer = assert(loadfile("lua/era/fn/find-explorer.lua"))()
  return fixture
end

---@param props                         table
---@param desc                          string
---@return fun()
local function retrieve_action(props, desc)
  for _, keymap in ipairs(props.keymaps_result) do
    if keymap.desc == desc then
      return keymap.callback
    end
  end
  error("Cannot retrieve action: " .. desc)
end

t:test("canonicalizes ingress and crosses scan and preview boundaries", function()
  local fixture = new_fixture()
  fixture.find_explorer([[C:\workspace\project\src\]])

  t.assert_true(fixture.focused, "picker focused")
  t.assert_eq("OS<C:/workspace/project/src>", fixture.existence_checks[1], "directory existence boundary")
  t.assert_eq("OS<C:/workspace/project/src>", fixture.scans[1], "directory scan boundary")
  t.assert_eq("OS<C:/workspace/project>", fixture.scans[2], "parent scan boundary")

  local data = assert(fixture.data)
  local fileitem = assert(data.items[2]).data.fileitem
  local filepath = "C:/workspace/project/src/main.lua"
  t.assert_eq(filepath, data.items[2].uuid, "canonical item uuid")
  t.assert_eq(filepath, fileitem.path, "canonical item filepath")
  t.assert_eq("C:/workspace/project/src", fileitem.dir, "canonical item dirpath")

  fixture.current_item = data.items[2]
  local read_filepath = nil ---@type string|nil
  t:patch_table(stl.fs, "read_file_as_lines", function(params)
    read_filepath = params.filepath
    return { "return true" }
  end)
  local bufnr = vim.api.nvim_create_buf(false, true)
  local preview = fixture.props.render_preview(fixture.picker, bufnr)
  t.assert_eq("OS<" .. filepath .. ">", read_filepath, "preview read boundary")
  t.assert_eq("src/main.lua", preview.title, "canonical preview title")
  vim.api.nvim_buf_delete(bufnr, { force = true })

  fixture.find_explorer([[C:\workspace\project\src\main.lua]])
  t.assert_eq("OS<" .. filepath .. ">", fixture.existence_checks[#fixture.existence_checks], "file ingress boundary")
  t.assert_eq(filepath, assert(fixture.data).items[2].uuid, "file ingress parent selection")

  local restore_exists = t:patch_table(yoz.path, "is_exist_directory", function(path)
    return path == "OS<.>" or path == "OS</>"
  end)
  fixture.find_explorer(".")
  t.assert_eq("main.lua", assert(fixture.data).items[2].uuid, "relative directory item")
  fixture.find_explorer("/")
  t.assert_eq("/main.lua", assert(fixture.data).items[2].uuid, "root directory item")
  restore_exists()
end)

t:test("mutation actions keep canonical identity and convert only at OS boundaries", function()
  local fixture = new_fixture()
  fixture.find_explorer([[C:\workspace\project\src\]])
  fixture.current_item = assert(fixture.data).items[2]

  local source = "C:/workspace/project/src/main.lua"
  local create_target = "C:/workspace/project/src/new.lua"
  local copy_target = "C:/workspace/project/src/main-copy.lua"
  local rename_target = "C:/workspace/project/src/renamed.lua"
  local mkdir_filepath = nil ---@type string|nil
  local write_filepath = nil ---@type string|nil
  local delete_filepath = nil ---@type string|nil
  local copy_source = nil ---@type string|nil
  local copy_destination = nil ---@type string|nil
  local rename_params = nil ---@type dot.t.IRenameParams|nil

  t:patch_table(stl.reporter, "info", function() end)
  t:patch_table(stl.reporter, "error", function() end)
  t:patch_table(yoz.path, "is_exist", function()
    return false
  end)
  t:patch_table(yoz.path, "is_exist_file", function(filepath)
    return filepath == "OS<" .. create_target .. ">"
  end)
  t:patch_table(stl.env, "mkdirs", function(filepath)
    mkdir_filepath = filepath
  end)
  t:patch_table(vim.fn, "writefile", function(_, filepath)
    write_filepath = filepath
    return 0
  end)
  t:patch_table(vim.fn, "delete", function(filepath)
    delete_filepath = filepath
    return 0
  end)
  t:patch_table(stl.fs, "copy_file", function(from, to)
    copy_source = from
    copy_destination = to
    return true
  end)
  t:patch_table(era.fn, "rename", function(params)
    rename_params = params
    return true
  end)

  local function submit(desc, input)
    local restore = t:patch_table(vim.ui, "input", function(_, callback)
      callback(input)
    end)
    retrieve_action(fixture.props, desc)()
    restore()
  end

  submit("filetree: create", "new.lua")
  t.assert_eq("OS<" .. create_target .. ">", mkdir_filepath, "create mkdir boundary")
  t.assert_eq("OS<" .. create_target .. ">", write_filepath, "create write boundary")

  submit("filetree: delete", "yes")
  t.assert_eq("OS<" .. source .. ">", delete_filepath, "delete boundary")

  submit("filetree: copy as", "main-copy.lua")
  t.assert_eq("OS<" .. source .. ">", copy_source, "copy source boundary")
  t.assert_eq("OS<" .. copy_target .. ">", copy_destination, "copy destination boundary")

  submit("filetree: rename", "renamed.lua")
  t.assert_eq("OS<" .. source .. ">", rename_params and rename_params.from, "rename source boundary")
  t.assert_eq("OS<" .. rename_target .. ">", rename_params and rename_params.to, "rename destination boundary")

  for _, item in ipairs(assert(fixture.data).items) do
    t.assert_true(item.uuid:find("\\", 1, true) == nil, "canonical cache identity")
  end
end)

t:run()
