---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.era.m.explorer.open" ---@type string

local support = require("__test__.support.explorer").new("era.m.explorer.open")
local t, await = support.t, support.await

---@return table
local function setup_open()
  local source_winnr = vim.api.nvim_get_current_win()
  local original_bufnr = vim.api.nvim_get_current_buf()
  local old_bufnr = vim.api.nvim_create_buf(true, false)
  local filepath
  t:defer(function()
    vim.api.nvim_set_current_win(source_winnr)
    vim.api.nvim_win_set_buf(source_winnr, original_bufnr)
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      if bufnr == old_bufnr or vim.api.nvim_buf_get_name(bufnr) == filepath then
        vim.api.nvim_buf_delete(bufnr, { force = true })
      end
    end
  end)
  local root = assert(vim.uv.fs_realpath(support.directory()))
  filepath = root .. "/file.txt"
  support.write(filepath)
  filepath = assert(vim.uv.fs_realpath(filepath))
  vim.api.nvim_win_set_buf(source_winnr, old_bufnr)
  local widget = support.widget(root)
  support.cursor(widget, filepath)
  local _, view = widget:context()
  local fixture = {
    filepath = filepath,
    source_winnr = source_winnr,
    old_bufnr = old_bufnr,
    explorer_winnr = view.winnr,
    remembered_winnr = source_winnr,
    old_entries = 0,
    focused_bufnrs = {},
    action = widget._action,
  }
  t:patch_table(dot.tab, "retrieve_winnr_sourcefile", function()
    return fixture.remembered_winnr
  end)
  local group = vim.api.nvim_create_augroup("test_explorer_open", { clear = true })
  t:defer(function()
    vim.api.nvim_del_augroup_by_id(group)
  end)
  vim.api.nvim_create_autocmd({ "WinEnter", "BufEnter" }, {
    group = group,
    callback = function(event)
      if event.buf == old_bufnr then
        fixture.old_entries = fixture.old_entries + 1
      end
      if event.event == "WinEnter" and vim.api.nvim_get_current_win() == source_winnr then
        fixture.focused_bufnrs[#fixture.focused_bufnrs + 1] = event.buf
      end
    end,
  })
  return fixture
end

for _, strategy in ipairs({ false, "pick" }) do
  local label = strategy or "default"
  t:test(label .. ": focuses the new file without entering the replaced buffer", function()
    local fixture = setup_open()
    await(fixture.action:open(strategy or nil))

    local bufnr = vim.api.nvim_win_get_buf(fixture.source_winnr)
    t.assert_eq(fixture.filepath, vim.api.nvim_buf_get_name(bufnr), "file displayed")
    t.assert_eq(fixture.source_winnr, vim.api.nvim_get_current_win(), "target focused")
    t.assert_eq(0, fixture.old_entries, "old buffer never entered")
    t.assert_true(vim.deep_equal({ bufnr }, fixture.focused_bufnrs), "focus enters the new buffer")
  end)

  t:test(label .. ": a missing file preserves explorer focus and the target buffer", function()
    local fixture = setup_open()
    assert(vim.uv.fs_unlink(fixture.filepath))
    await(fixture.action:open(strategy or nil))

    t.assert_eq(fixture.explorer_winnr, vim.api.nvim_get_current_win(), "explorer retains focus")
    t.assert_eq(fixture.old_bufnr, vim.api.nvim_win_get_buf(fixture.source_winnr), "old buffer retained")
    t.assert_eq(0, fixture.old_entries, "failure does not enter the target")
  end)
end

t:test("default opening uses the remembered source without invoking window selection", function()
  local fixture = setup_open()
  t:patch_table(era.fn, "pick_win", function()
    error("remembered source should bypass the picker")
  end)
  await(fixture.action:open())
  t.assert_eq(fixture.source_winnr, vim.api.nvim_get_current_win())
  t.assert_eq(0, fixture.old_entries)
end)

t:test("default opening falls back to window selection when no source window is remembered", function()
  local fixture = setup_open()
  fixture.remembered_winnr = nil
  await(fixture.action:open())

  t.assert_eq(fixture.source_winnr, vim.api.nvim_get_current_win(), "fallback target focused")
  t.assert_eq(fixture.filepath, vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf()), "file displayed")
  t.assert_eq(0, fixture.old_entries, "fallback does not enter the old buffer")
end)

t:test("explicit window selection can be cancelled even when a source is remembered", function()
  local fixture = setup_open()
  t:patch_table(era.fn, "pick_win", function()
    return nil
  end)
  await(fixture.action:open("pick"))

  t.assert_eq(fixture.explorer_winnr, vim.api.nvim_get_current_win(), "explorer retains focus")
  t.assert_eq(fixture.old_bufnr, vim.api.nvim_win_get_buf(fixture.source_winnr), "old buffer retained")
end)

t:run()
