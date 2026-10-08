---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.era.m.explorer.prompt" ---@type string

local fixture = require("__test__.support.explorer").new("era.m.explorer.prompt")
local t = fixture.t
local UI = require("__test__.support.ui")
local Grid = require("__test__.support.ui_grid")

---@param predicate                     fun(): boolean
---@param timeout                       integer
---@return nil
local function wait_for(predicate, timeout)
  local deadline = vim.uv.hrtime() + timeout * 1000000
  while not predicate() do
    t.assert_true(vim.uv.hrtime() < deadline, "UI condition did not complete")
    vim.wait(5, function()
      return false
    end, 5)
  end
end

---@param names                         string[]
---@return table
local function open_ui(names)
  local path = fixture.directory()
  for _, name in ipairs(names) do
    if name:sub(-1) == "/" then
      assert(vim.uv.fs_mkdir(path .. "/" .. name:sub(1, -2), 448))
    else
      vim.fn.writefile({ name }, path .. "/" .. name)
    end
  end
  local ui = UI.new()
  t:defer(function()
    ui:close()
  end)
  local grid = Grid.new(ui)
  ui:rpc("nvim_ui_attach", 142, 69, { rgb = true, ext_linegrid = true })
  ui:rpc(
    "nvim_exec_lua",
    [[
    local root, path, count = ...
    vim.opt.runtimepath:prepend(root)
    local system = vim.uv.os_uname().sysname
    local library = system == "Windows_NT" and "yoz.dll" or "libyoz." .. (system == "Darwin" and "dylib" or "so")
    yoz = assert(package.loadlib(root .. "/rust/target/debug/" .. library, "luaopen_yoz"))()
    stl, dot, era = require("stl"), require("dot"), require("era")
    dot.path.workspace = function() return path end
    dot.path.is_git_repo = function() return false end
    dot.context.explorer.trash.snapshot = function() return false end
    errors = {}
    stl.reporter.warn = function(value) errors[#errors + 1] = vim.inspect(value) end
    stl.reporter.error = stl.reporter.warn
    stl.reporter.info = function() end
    vim.ui.input = require("era.m.input").open
    vim.ui.select = function() error("a confirmation must not open a picker") end
    widget = require("era.m.explorer.widget").new({ name = "compact-prompt", root = path })
    widget:focus()
    assert(vim.wait(10000, function()
      session, view = widget._session, widget._views[vim.api.nvim_get_current_tabpage()]
      return session and view and view:frame() and view:frame():header().row_count == count
        and not session.data._native:is_busy() and session.state._native:applicable(view:frame())
    end, 1))
  ]],
    { assert(vim.uv.cwd()), path, #names }
  )
  return { ui = ui, grid = grid, path = path }
end

---@param context                       table
---@return table
local function dialog(context)
  local result
  wait_for(function()
    result = context.ui:rpc(
      "nvim_exec_lua",
      [[
      local result, floats = nil, 0
      for _, winnr in ipairs(vim.api.nvim_list_wins()) do
        local config = vim.api.nvim_win_get_config(winnr)
        if config.relative ~= "" then floats = floats + 1 end
        if vim.w[winnr].wintype == stl.e.WinTypeEnum.INPUT then
          local bufnr = vim.api.nvim_win_get_buf(winnr)
          result = {
            height = config.height, width = config.width, relative = config.relative,
            origin = config.win == view.winnr,
            lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false),
            wrap = vim.api.nvim_get_option_value("wrap", {win = winnr}),
          }
        end
      end
      if result then result.floats = floats end
      return result
    ]],
      {}
    )
    return result ~= nil
  end, 10000)
  t.assert_eq(1, result.floats, "confirmation must use one compact surface")
  t.assert_eq("win", result.relative)
  t.assert_true(result.origin, "confirmation must stay anchored to the Explorer window")
  return result
end

---@param context                       table
---@param keys                          string
---@return nil
local function answer(context, keys)
  context.ui:rpc("nvim_input", keys)
  wait_for(function()
    return context.ui:rpc(
      "nvim_exec_lua",
      "return not session:busy() and vim.api.nvim_get_current_win() == view.winnr",
      {}
    )
  end, 10000)
  local errors = context.ui:rpc("nvim_exec_lua", "return errors", {})
  t.assert_eq(0, #errors, vim.inspect(errors))
end

t:test("single-file deletion uses one input line with y, n, Escape and default No", function()
  local context = open_ui({ "b.rs" })
  for _, keys in ipairs({ "<CR>", "n", "<Esc>", "y" }) do
    context.ui:rpc("nvim_exec_lua", "widget:focus(); deleting = widget._action:delete()", {})
    local popup = dialog(context)
    t.assert_eq(1, popup.height)
    t.assert_true(popup.width <= 80)
    t.assert_eq(1, #popup.lines)
    t.assert_eq("? (y/N)  ", popup.lines[1])
    wait_for(function()
      return context.grid:find('Permanently delete "b.rs"?') ~= nil
    end, 10000)
    answer(context, keys)
    t.assert_eq(keys ~= "y", vim.uv.fs_stat(context.path .. "/b.rs") ~= nil)
  end
end)

t:test("multiple delete targets stay readable in a content-sized confirmation", function()
  local names = { "customer-export-alpha.csv", "customer-export-beta.csv", "customer-export-gamma.csv" }
  local context = open_ui(names)
  context.ui:rpc(
    "nvim_exec_lua",
    'vim.api.nvim_win_set_cursor(view.winnr, {1, 0}); vim.cmd.normal({args={"V2j"}, bang=true}); deleting = widget._action:delete()',
    {}
  )
  local popup = dialog(context)
  t.assert_eq(4, popup.height)
  t.assert_true(popup.width <= 80)
  t.assert_true(popup.wrap)
  for index, name in ipairs(names) do
    t.assert_eq('"' .. name .. '"', popup.lines[index])
  end
  wait_for(function()
    if not context.grid:find("Permanently delete 3 items?") then
      return false
    end
    for _, name in ipairs(names) do
      if not context.grid:find('"' .. name .. '"') then
        return false
      end
    end
    return true
  end, 10000)
  answer(context, "<Esc>")
  for _, name in ipairs(names) do
    t.assert_true(vim.uv.fs_stat(context.path .. "/" .. name) ~= nil)
  end
end)

t:test("a long Unicode delete target wraps inside a bounded confirmation", function()
  local name = string.rep("界", 80) .. ".txt"
  local context = open_ui({ name })
  context.ui:rpc("nvim_ui_try_resize", 80, 24)
  context.ui:rpc("nvim_exec_lua", "deleting = widget._action:delete()", {})
  local popup = dialog(context)
  t.assert_true(popup.width <= 76)
  t.assert_true(popup.height > 1 and popup.height <= 8)
  t.assert_true(popup.wrap)
  t.assert_true(popup.lines[1]:find(name, 1, true) ~= nil)
  t.assert_eq("? (y/N)  ", popup.lines[#popup.lines])
  answer(context, "<CR>")
  t.assert_true(vim.uv.fs_stat(context.path .. "/" .. name) ~= nil)
end)

t:test("overwrite shows source and target without a picker and defaults to Skip", function()
  local context = open_ui({ "a.txt", "b.txt" })
  for _, keys in ipairs({ "<CR>", "y" }) do
    context.ui:rpc(
      "nvim_exec_lua",
      'local path = ...; copying = widget._action:operate({ kind = "copy_to_path", path = path .. "/b.txt"})',
      { context.path }
    )
    local popup = dialog(context)
    t.assert_true(popup.height >= 3 and popup.height <= 8)
    t.assert_true(popup.lines[1]:find("b.txt", 1, true) ~= nil)
    t.assert_true(popup.lines[2]:find("a.txt", 1, true) ~= nil)
    answer(context, keys)
    t.assert_eq(keys == "y" and "a.txt" or "b.txt", vim.fn.readfile(context.path .. "/b.txt")[1])
    wait_for(function()
      return context.ui:rpc("nvim_exec_lua", "return widget:get_cursor_filepath() == ...", {
        context.path .. (keys == "y" and "/b.txt" or "/a.txt"),
      })
    end, 10000)
  end
end)

t:test("real path inputs preserve successful copy and move following across their focus changes", function()
  local context = open_ui({ "source.txt" })
  context.ui:rpc("nvim_input", "c")
  local popup = dialog(context)
  t.assert_true(popup.lines[1]:find("source-copy.txt", 1, true) ~= nil)
  answer(context, "<CR>")
  wait_for(function()
    return context.ui:rpc("nvim_exec_lua", "return widget:get_cursor_filepath() == ...", {
      context.path .. "/source-copy.txt",
    })
  end, 10000)
  local target = fixture.directory() .. "/moved.txt"
  context.ui:rpc("nvim_input", "x")
  dialog(context)
  context.ui:rpc("nvim_exec_lua", "vim.api.nvim_buf_set_lines(vim.api.nvim_get_current_buf(), 0, -1, false, {...})", {
    target,
  })
  answer(context, "<CR>")
  wait_for(function()
    return context.ui:rpc("nvim_exec_lua", "return widget:get_cursor_filepath() == ...", { target })
  end, 10000)
  t.assert_true(vim.uv.fs_stat(target) ~= nil)
  t.assert_eq(nil, vim.uv.fs_stat(context.path .. "/source-copy.txt"))
end)

t:test("create input shows the current directory prefix and accepts normal append editing", function()
  local context = open_ui({ "folder/", "placeholder.txt" })
  context.ui:rpc("nvim_exec_lua", "creating = widget._action:create(false)", {})
  local popup = dialog(context)
  t.assert_eq(1, popup.height)
  t.assert_eq("folder/", popup.lines[1])
  answer(context, "<CR>")
  t.assert_eq(nil, vim.uv.fs_stat(context.path .. "/folder/child.txt"))

  context.ui:rpc("nvim_exec_lua", "creating = widget._action:create(false)", {})
  popup = dialog(context)
  t.assert_eq("folder/", popup.lines[1])
  context.ui:rpc("nvim_input", "Achild.txt<CR>")
  wait_for(function()
    return context.ui:rpc(
      "nvim_exec_lua",
      "return not session:busy() and vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf()) == vim.uv.fs_realpath(...)",
      { context.path .. "/folder/child.txt" }
    )
  end, 10000)
  t.assert_true(vim.uv.fs_stat(context.path .. "/folder/child.txt") ~= nil)
  t.assert_eq(0, context.ui:rpc("nvim_exec_lua", "return #errors", {}))
end)

t:test("a newline in the create parent keeps a usable input and the original directory target", function()
  local context = open_ui({ "a\nb/", "placeholder.txt" })
  context.ui:rpc("nvim_exec_lua", "creating = widget._action:create(false)", {})
  local popup = dialog(context)
  t.assert_eq(1, popup.height)
  t.assert_eq("", popup.lines[1])
  context.ui:rpc("nvim_input", "ichild.txt<CR>")
  wait_for(function()
    return context.ui:rpc(
      "nvim_exec_lua",
      "return not session:busy() and vim.uv.fs_stat(...) ~= nil",
      { context.path .. "/a\nb/child.txt" }
    )
  end, 10000)
  t.assert_true(vim.uv.fs_stat(context.path .. "/a\nb/child.txt") ~= nil)
  t.assert_eq(nil, vim.uv.fs_stat(context.path .. "/child.txt"))
  t.assert_eq(0, context.ui:rpc("nvim_exec_lua", "return #errors", {}))
end)

t:test("confirmation descriptions preserve trailing colons and spaces exactly", function()
  local context = open_ui({ "placeholder.txt" })
  context.ui:rpc(
    "nvim_exec_lua",
    [[
    reply = false
    vim.ui.input({prompt = "  Overwrite?  \nTarget: target:\nSource: source:  ", inputtype = "confirmation"}, function(value)
      reply = value
    end)
  ]],
    {}
  )
  local popup = dialog(context)
  t.assert_eq("Target: target:", popup.lines[1])
  t.assert_eq("Source: source:  ", popup.lines[2])
  answer(context, "<CR>")
  wait_for(function()
    return context.ui:rpc("nvim_exec_lua", "return reply ~= false", {})
  end, 10000)
  t.assert_eq("", context.ui:rpc("nvim_exec_lua", "return reply", {}))
end)

t:test("invalid single-line defaults fail before allocating an input surface", function()
  local context = open_ui({ "placeholder.txt" })
  local result = context.ui:rpc(
    "nvim_exec_lua",
    [[
    local wins, bufs = #vim.api.nvim_list_wins(), #vim.api.nvim_list_bufs()
    local ok = pcall(vim.ui.input, {prompt = "Input", default = "a\nb"}, function() end)
    return {ok = ok, windows = #vim.api.nvim_list_wins() - wins, buffers = #vim.api.nvim_list_bufs() - bufs}
  ]],
    {}
  )
  t.assert_false(result.ok)
  t.assert_eq(0, result.windows)
  t.assert_eq(0, result.buffers)
end)

t:run()
