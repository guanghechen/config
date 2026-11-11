local explorer = require("__test__.support.explorer")
local t = require("__test__.support.harness").new()

---@param names                         string[]
---@return table
local function open_ui(names)
  local path = t:tempdir()
  for _, name in ipairs(names) do
    if name:sub(-1) == "/" then
      assert(vim.uv.fs_mkdir(path .. "/" .. name:sub(1, -2), 448))
    else
      vim.fn.writefile({ name }, path .. "/" .. name)
    end
  end
  local ui, grid = explorer.open_ui(t, { width = 142, height = 69, path = path })
  ui:lua(
    [[
    local path, count = ...
    dot.context.explorer.trash.snapshot = function() return false end
    vim.ui.input = require("era.m.input").open
    vim.ui.select = function() error("a confirmation must not open a picker") end
    widget = require("era.m.explorer.widget").new({ name = "compact-prompt", root = path })
    widget:focus()
    session, view = shown(widget, count, function(current_session, current)
      return not current_session.data:native():is_busy() and current_session.state:native():applicable(current:frame())
    end)
  ]],
    path,
    #names
  )
  return { ui = ui, grid = grid, path = path }
end

---@param context                       table
---@return table
local function dialog(context)
  local result
  context.ui:wait_until(function()
    result = context.ui:lua([[
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
    ]])
    return result ~= nil
  end, 10000, "the input dialog must open")
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
  context.ui:wait_lua(
    "return not session:busy() and vim.api.nvim_get_current_win() == view.winnr",
    10000,
    "the answer must settle the operation and return to the Explorer"
  )
  local errors = context.ui:lua("return errors")
  t.assert_eq(0, #errors, vim.inspect(errors))
end

t:test("single-file deletion uses one input line with y, n, Escape and default No", function()
  local context = open_ui({ "b.rs" })
  for _, keys in ipairs({ "<CR>", "n", "<Esc>", "y" }) do
    context.ui:lua("widget:focus(); widget:action():delete()")
    local popup = dialog(context)
    t.assert_eq(1, popup.height)
    t.assert_true(popup.width <= 80)
    t.assert_eq(1, #popup.lines)
    t.assert_eq("? (y/N)  ", popup.lines[1])
    context.ui:wait_until(function()
      return context.grid:find('Permanently delete "b.rs"?') ~= nil
    end, 10000, "the delete confirmation must be drawn")
    answer(context, keys)
    t.assert_eq(keys ~= "y", vim.uv.fs_stat(context.path .. "/b.rs") ~= nil)
  end
end)

t:test("multiple delete targets stay readable in a content-sized confirmation", function()
  local names = { "customer-export-alpha.csv", "customer-export-beta.csv", "customer-export-gamma.csv" }
  local context = open_ui(names)
  context.ui:lua(
    'vim.api.nvim_win_set_cursor(view.winnr, {1, 0}); vim.cmd.normal({args={"V2j"}, bang=true}); widget:action():delete()'
  )
  local popup = dialog(context)
  t.assert_eq(4, popup.height)
  t.assert_true(popup.width <= 80)
  t.assert_true(popup.wrap)
  for index, name in ipairs(names) do
    t.assert_eq('"' .. name .. '"', popup.lines[index])
  end
  context.ui:wait_until(function()
    if not context.grid:find("Permanently delete 3 items?") then
      return false
    end
    for _, name in ipairs(names) do
      if not context.grid:find('"' .. name .. '"') then
        return false
      end
    end
    return true
  end, 10000, "the confirmation must draw every target")
  answer(context, "<Esc>")
  for _, name in ipairs(names) do
    t.assert_true(vim.uv.fs_stat(context.path .. "/" .. name) ~= nil)
  end
end)

t:test("a long Unicode delete target wraps inside a bounded confirmation", function()
  local name = string.rep("界", 80) .. ".txt"
  local context = open_ui({ name })
  context.ui:rpc("nvim_ui_try_resize", 80, 24)
  context.ui:lua("widget:action():delete()")
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
    context.ui:lua(
      'local path = ...; widget:action():operate({ kind = "copy_to_path", path = path .. "/b.txt"})',
      context.path
    )
    local popup = dialog(context)
    t.assert_true(popup.height >= 3 and popup.height <= 8)
    t.assert_true(popup.lines[1]:find("b.txt", 1, true) ~= nil)
    t.assert_true(popup.lines[2]:find("a.txt", 1, true) ~= nil)
    answer(context, keys)
    t.assert_eq(keys == "y" and "a.txt" or "b.txt", vim.fn.readfile(context.path .. "/b.txt")[1])
    context.ui:wait_lua(
      "return widget:get_cursor_filepath() == ...",
      10000,
      "the cursor must follow the overwrite result",
      context.path .. (keys == "y" and "/b.txt" or "/a.txt")
    )
  end
end)

t:test("real path inputs preserve successful copy and move following across their focus changes", function()
  local context = open_ui({ "source.txt" })
  context.ui:rpc("nvim_input", "c")
  local popup = dialog(context)
  t.assert_true(popup.lines[1]:find("source-copy.txt", 1, true) ~= nil)
  answer(context, "<CR>")
  context.ui:wait_lua(
    "return widget:get_cursor_filepath() == ...",
    10000,
    "the cursor must follow the copy",
    context.path .. "/source-copy.txt"
  )
  local target = t:tempdir() .. "/moved.txt"
  context.ui:rpc("nvim_input", "x")
  dialog(context)
  context.ui:lua("vim.api.nvim_buf_set_lines(vim.api.nvim_get_current_buf(), 0, -1, false, {...})", target)
  answer(context, "<CR>")
  context.ui:wait_lua("return widget:get_cursor_filepath() == ...", 10000, "the cursor must follow the move", target)
  t.assert_true(vim.uv.fs_stat(target) ~= nil)
  t.assert_eq(nil, vim.uv.fs_stat(context.path .. "/source-copy.txt"))
end)

t:test("create input shows the current directory prefix and accepts normal append editing", function()
  local context = open_ui({ "folder/", "placeholder.txt" })
  context.ui:lua("widget:action():create(false)")
  local popup = dialog(context)
  t.assert_eq(1, popup.height)
  t.assert_eq("folder/", popup.lines[1])
  answer(context, "<CR>")
  t.assert_eq(nil, vim.uv.fs_stat(context.path .. "/folder/child.txt"))

  context.ui:lua("widget:action():create(false)")
  popup = dialog(context)
  t.assert_eq("folder/", popup.lines[1])
  context.ui:rpc("nvim_input", "Achild.txt<CR>")
  context.ui:wait_lua(
    "return not session:busy() and vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf()) == vim.uv.fs_realpath(...)",
    10000,
    "the created file must open",
    context.path .. "/folder/child.txt"
  )
  t.assert_true(vim.uv.fs_stat(context.path .. "/folder/child.txt") ~= nil)
  t.assert_eq(0, context.ui:lua("return #errors"))
end)

t:test("a newline in the create parent keeps a usable input and the original directory target", function()
  local context = open_ui({ "a\nb/", "placeholder.txt" })
  context.ui:lua("widget:action():create(false)")
  local popup = dialog(context)
  t.assert_eq(1, popup.height)
  t.assert_eq("", popup.lines[1])
  context.ui:rpc("nvim_input", "ichild.txt<CR>")
  context.ui:wait_lua(
    "return not session:busy() and vim.uv.fs_stat(...) ~= nil",
    10000,
    "the file must be created inside the directory with a newline",
    context.path .. "/a\nb/child.txt"
  )
  t.assert_true(vim.uv.fs_stat(context.path .. "/a\nb/child.txt") ~= nil)
  t.assert_eq(nil, vim.uv.fs_stat(context.path .. "/child.txt"))
  t.assert_eq(0, context.ui:lua("return #errors"))
end)

t:test("confirmation descriptions preserve trailing colons and spaces exactly", function()
  local context = open_ui({ "placeholder.txt" })
  context.ui:lua([[
    reply = false
    vim.ui.input({prompt = "  Overwrite?  \nTarget: target:\nSource: source:  ", inputtype = "confirmation"}, function(value)
      reply = value
    end)
  ]])
  local popup = dialog(context)
  t.assert_eq("Target: target:", popup.lines[1])
  t.assert_eq("Source: source:  ", popup.lines[2])
  answer(context, "<CR>")
  context.ui:wait_lua("return reply ~= false", 10000, "the confirmation must reply")
  t.assert_eq("", context.ui:lua("return reply"))
end)

t:test("invalid single-line defaults fail before allocating an input surface", function()
  local context = open_ui({ "placeholder.txt" })
  local result = context.ui:lua([[
    local wins, bufs = #vim.api.nvim_list_wins(), #vim.api.nvim_list_bufs()
    local ok = pcall(vim.ui.input, {prompt = "Input", default = "a\nb"}, function() end)
    return {ok = ok, windows = #vim.api.nvim_list_wins() - wins, buffers = #vim.api.nvim_list_bufs() - bufs}
  ]])
  t.assert_false(result.ok)
  t.assert_eq(0, result.windows)
  t.assert_eq(0, result.buffers)
end)

t:run()
