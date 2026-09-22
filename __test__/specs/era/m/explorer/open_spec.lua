---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.era.m.explorer.open" ---@type string

local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")
local Action = require("era.m.explorer.action")
local t = harness.new("era.m.explorer.open")

bootstrap.with_runtime(t, {
  yoz = require("yoz"),
  stl = {
    e = require("stl.e"),
    env = { IS_WIN = vim.fn.has("win32") == 1 },
    nvim = { buf = require("stl.nvim.buf"), win = require("stl.nvim.win") },
    reporter = {
      error = function(details)
        error(vim.inspect(details))
      end,
    },
  },
  dot = { buf = require("dot.buf"), tab = {} },
  era = { fn = { pick_win = require("era.fn.pick-win") } },
})
bootstrap.with_dot(t, { win = require("dot.win") })

---@return table
local function setup_open()
  local source_winnr = vim.api.nvim_get_current_win() ---@type integer
  local original_bufnr = vim.api.nvim_get_current_buf() ---@type integer
  local old_bufnr = vim.api.nvim_create_buf(true, false) ---@type integer
  local explorer_bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  local filepath = vim.fn.tempname() .. ".txt" ---@type string
  local explorer_winnr ---@type integer|nil
  t:defer(function()
    vim.api.nvim_set_current_win(source_winnr)
    vim.api.nvim_win_set_buf(source_winnr, original_bufnr)
    if explorer_winnr ~= nil and vim.api.nvim_win_is_valid(explorer_winnr) then
      vim.api.nvim_win_close(explorer_winnr, true)
    end
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      if bufnr == old_bufnr or bufnr == explorer_bufnr or vim.api.nvim_buf_get_name(bufnr) == filepath then
        vim.api.nvim_buf_delete(bufnr, { force = true })
      end
    end
    vim.fn.delete(filepath)
  end)
  vim.fn.writefile({ "one", "two", "three" }, filepath)
  filepath = assert(vim.uv.fs_realpath(filepath))
  vim.api.nvim_win_set_buf(source_winnr, old_bufnr)
  explorer_winnr = vim.api.nvim_open_win(explorer_bufnr, true, { split = "left", win = source_winnr })
  vim.w[explorer_winnr].wintype = stl.e.WinTypeEnum.EXPLORER

  local fixture = {
    filepath = filepath,
    source_winnr = source_winnr,
    old_bufnr = old_bufnr,
    explorer_winnr = explorer_winnr,
    remembered_winnr = source_winnr,
    old_entries = 0,
    focused_bufnrs = {},
  }
  t:patch_table(dot.tab, "retrieve_winnr_sourcefile", function()
    return fixture.remembered_winnr
  end)
  local group = vim.api.nvim_create_augroup("test_explorer_open", { clear = true }) ---@type integer
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
  fixture.action = Action.new({
    get_cursor_filepath = function()
      return fixture.filepath
    end,
  })
  return fixture
end

for _, method in ipairs({ "open", "pick_win_open" }) do
  t:test(method .. ": focuses the new file without entering the replaced buffer", function()
    local fixture = setup_open()
    fixture.action[method](fixture.action)

    local bufnr = vim.api.nvim_win_get_buf(fixture.source_winnr) ---@type integer
    t.assert_eq(fixture.filepath, vim.api.nvim_buf_get_name(bufnr), "file displayed")
    t.assert_eq(fixture.source_winnr, vim.api.nvim_get_current_win(), "target focused")
    t.assert_eq(0, fixture.old_entries, "old buffer never entered")
    t.assert_true(vim.deep_equal({ bufnr }, fixture.focused_bufnrs), "focus enters the new buffer")
  end)

  t:test(method .. ": a missing file preserves explorer focus and the target buffer", function()
    local fixture = setup_open()
    fixture.filepath = fixture.filepath .. ".missing"
    fixture.action[method](fixture.action)

    t.assert_eq(fixture.explorer_winnr, vim.api.nvim_get_current_win(), "explorer retains focus")
    t.assert_eq(fixture.old_bufnr, vim.api.nvim_win_get_buf(fixture.source_winnr), "old buffer retained")
    t.assert_eq(0, fixture.old_entries, "failure does not enter the target")
  end)
end

t:test("open: falls back to window selection when no source window is remembered", function()
  local fixture = setup_open()
  fixture.remembered_winnr = nil
  fixture.action:open()

  t.assert_eq(fixture.source_winnr, vim.api.nvim_get_current_win(), "fallback target focused")
  t.assert_eq(fixture.filepath, vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf()), "file displayed")
  t.assert_eq(0, fixture.old_entries, "fallback does not enter the old buffer")
end)

t:test("pick_win_open: cancelling window selection preserves explorer focus", function()
  local fixture = setup_open()
  t:patch_table(era.fn, "pick_win", function()
    return nil
  end)
  fixture.action:pick_win_open()

  t.assert_eq(fixture.explorer_winnr, vim.api.nvim_get_current_win(), "explorer retains focus")
  t.assert_eq(fixture.old_bufnr, vim.api.nvim_win_get_buf(fixture.source_winnr), "old buffer retained")
end)

t:run()
