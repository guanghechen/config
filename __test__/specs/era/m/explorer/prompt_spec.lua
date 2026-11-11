local explorer = require("__test__.support.explorer")
local t = require("__test__.support.harness").new()
local prompt = explorer.prompt(t)
local open_ui, dialog, answer = prompt.open, prompt.dialog, prompt.answer

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

t:run()
