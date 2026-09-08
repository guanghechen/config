local harness = require("__test__.support.harness")
local bootstrap = require("__test__.support.bootstrap")
local nvim_fn = require("stl.nvim.fn")
local refresh_bufs = require("dot.tab").refresh_bufs
local t = harness.new("era.m.nvimbar.component.buf")

local function setup(count, selected)
  local state = {
    bufs = {},
    metas = {},
    diagnostics = {},
    selected = selected or 1,
    relative = true,
    txt_calls = 0,
    btn_calls = 0,
  }
  for index = 1, count do
    local bufnr = vim.api.nvim_create_buf(true, false)
    t:defer(function()
      if vim.api.nvim_buf_is_valid(bufnr) then
        vim.api.nvim_buf_delete(bufnr, { force = true })
      end
    end)
    state.bufs[index] = { bufnr = bufnr, pinned = false }
    state.metas[bufnr] = {
      filename = string.format("file%04d.lua", index),
      fileicon = "F",
      fileicon_hln = "Lua",
      dirpath_pieces = { "project", "src" },
    }
    state.diagnostics[bufnr] = { error = 0, warn = 0, hint = 0, info = 0 }
  end
  local registrations = 0
  bootstrap.with_runtime(t, {
    stl = {
      env = { PATH_SEP = "/" },
      nvim = {
        fn = {
          txt = function(text, hlname)
            state.txt_calls = state.txt_calls + 1
            return nvim_fn.txt(text, hlname)
          end,
          btn = function(text, callback, args)
            state.btn_calls = state.btn_calls + 1
            return nvim_fn.btn(text, callback, args)
          end,
        },
      },
      icon = {
        diagnostic = { Error_alt = "E", Warning_alt = "W", Hint_alt = "H", Information_alt = "I" },
        ui = { Left = "<", Right = ">" },
        todigit_subscript = tostring,
      },
    },
    dot = {
      G = {
        register_anonymous_fn = function()
          registrations = registrations + 1
          return "on_buf_click_" .. registrations
        end,
      },
      buf = {
        resolve = function(bufnr)
          return state.metas[bufnr]
        end,
      },
      tab = {
        resolve = function()
          return state
        end,
        refresh_bufs = refresh_bufs,
        retrieve_buf_sourcefile = function()
          return state.bufs[state.selected], state.selected
        end,
      },
      context = {
        behavior = {
          bufs_relative = {
            snapshot = function()
              return state.relative
            end,
          },
        },
      },
    },
  })
  t:patch_table(package.loaded, "era.m.lsp.diagnostic", {
    get_by_bufnr = function(bufnr)
      return state.diagnostics[bufnr]
    end,
  })
  t:patch_table(package.loaded, "era.m.nvimbar.component.buf", nil)
  return require("era.m.nvimbar.component.buf").bufs("f_tl"), state
end

local context = { tabnr = 1 }

t:test("formatting stays bounded by visible width as the buffer list grows", function()
  for _, count in ipairs({ 100, 500, 2000 }) do
    local component, state = setup(count, math.floor(count / 2))
    local snapshot = component.refresh(context)
    t.assert_eq(0, state.txt_calls, "refresh captures data without formatting hidden items")
    t.assert_eq(0, state.btn_calls)
    local text = component.render(snapshot, context, 120)
    t.assert_true(
      text:find(state.metas[state.bufs[state.selected].bufnr].filename, 1, true) ~= nil,
      "selected buffer stays visible"
    )
    t.assert_true(vim.api.nvim_strwidth(text) <= 120)
    t.assert_true(state.btn_calls <= 12, "visible buffers, boundary candidates and omitter buttons")
    t.assert_true(state.txt_calls <= 80, "highlight formatting is independent of the hidden count")
  end
end)

t:test("resizing uses an isolated snapshot without rereading mutable buffer data", function()
  local component, state = setup(30, 15)
  local first_bufnr = state.bufs[1].bufnr
  local snapshot = component.refresh(context)
  local saved = vim.deepcopy(snapshot)
  local narrow = component.render(snapshot, context, 90)

  state.metas[first_bufnr].filename = "renamed.lua"
  state.metas[first_bufnr].fileicon = "NEW"
  state.metas[first_bufnr].dirpath_pieces[2] = "changed"
  state.diagnostics[first_bufnr].error = 9
  state.bufs[1].pinned = true
  state.selected, state.relative = 1, false
  vim.api.nvim_set_option_value("modified", true, { buf = first_bufnr })
  ---@return nil
  local function unexpected_read()
    error("layout must use its data snapshot")
  end
  t:patch_table(dot.buf, "resolve", unexpected_read)
  t:patch_table(dot.tab, "resolve", unexpected_read)
  t:patch_table(dot.context.behavior.bufs_relative, "snapshot", unexpected_read)
  t:patch_table(package.loaded["era.m.lsp.diagnostic"], "get_by_bufnr", unexpected_read)
  t:patch_table(vim.api, "nvim_get_option_value", unexpected_read)
  t:patch_table(vim.api, "nvim_eval", unexpected_read)
  t:patch_table(vim.fn, "getbufinfo", unexpected_read)

  local wide, hltext = component.render(snapshot, context, 10000)
  for _, buf in ipairs(saved.bufs) do
    t.assert_true(wide:find(buf.filename, 1, true) ~= nil, "all buffers fit after widening")
  end
  t.assert_true(#wide > #narrow)
  t.assert_true(wide:find("14₋F file0001.lua  ", 1, true) ~= nil, "hidden data is captured before resizing")
  t.assert_false(wide:find("renamed.lua", 1, true) ~= nil)
  t.assert_false(wide:find("E 9", 1, true) ~= nil)
  t.assert_false(wide:find("", 1, true) ~= nil)
  t.assert_eq(wide, vim.api.nvim_eval_statusline(hltext, { maxwidth = 10000 }).str)
  t.assert_true(vim.deep_equal(saved, snapshot), "layout does not mutate the snapshot")
end)

t:test("selection, disambiguation, diagnostics and click targets survive lazy formatting", function()
  local component, state = setup(3, 1)
  local first, second, third = state.bufs[1].bufnr, state.bufs[2].bufnr, state.bufs[3].bufnr
  state.metas[first].filename = "main.lua"
  state.metas[second].filename = "main.lua"
  state.metas[second].dirpath_pieces[2] = "test"
  state.metas[third].filename = "z%名.lua"
  state.bufs[1].pinned = true
  state.diagnostics[first] = { error = 3, warn = 2, hint = 1, info = 4 }
  state.diagnostics[second] = { error = 0, warn = 0, hint = 4, info = 5 }
  vim.api.nvim_set_option_value("modified", true, { buf = first })
  vim.api.nvim_set_option_value("modified", true, { buf = third })
  local text, hltext = component.render(component.refresh(context), context, 1000)
  t.assert_true(text:find("▎1.F main.lua src/  E 3 W 2  ", 1, true) ~= nil, text)
  t.assert_true(text:find("▏1₊F main.lua test/  H 4 I 5  ", 1, true) ~= nil)
  t.assert_true(text:find("▏2₊F z%名.lua  ", 1, true) ~= nil)
  t.assert_false(text:find("H 1", 1, true) ~= nil, "only two diagnostic severities are displayed")
  t.assert_true(hltext:find("%#f_tl_bufc_Lua#", 1, true) ~= nil, "selected icon highlight")
  t.assert_true(hltext:find("%#f_tl_bufc_error#", 1, true) ~= nil, "selected diagnostic highlight")
  for _, buf in ipairs(state.bufs) do
    t.assert_true(hltext:find("%" .. buf.bufnr .. "@v:lua.on_buf_click_1@", 1, true) ~= nil)
  end
  t.assert_eq(text, vim.api.nvim_eval_statusline(hltext, { maxwidth = 1000 }).str, "escaped native statusline")
end)

t:test("duplicate filenames at the end of the sorted list include their directories", function()
  for _, count in ipairs({ 2, 4 }) do
    local component, state = setup(count)
    local left, right = state.bufs[count - 1].bufnr, state.bufs[count].bufnr
    state.metas[left].filename = "same.lua"
    state.metas[left].dirpath_pieces[2] = "left"
    state.metas[right].filename = "same.lua"
    state.metas[right].dirpath_pieces[2] = "right"

    local text = component.render(component.refresh(context), context, 1000)
    t.assert_true(text:find("same.lua left/", 1, true) ~= nil, text)
    t.assert_true(text:find("same.lua right/", 1, true) ~= nil, text)
  end
end)

t:test("disambiguation sorts only buffers with duplicate filenames", function()
  local component, state = setup(100)
  local first, middle, last = state.bufs[1].bufnr, state.bufs[50].bufnr, state.bufs[100].bufnr
  state.metas[first].filename = "same.lua"
  state.metas[middle].filename = "same.lua"
  state.metas[middle].dirpath_pieces[1] = "other"
  state.metas[last].filename = "same.lua"
  state.metas[last].dirpath_pieces[2] = "test"
  local sort = table.sort
  t:patch_table(table, "sort", function(items, compare)
    t.assert_eq(3, #items, "unique filenames do not need directory sorting")
    return sort(items, compare)
  end)
  local snapshot = component.refresh(context)
  t.assert_eq("project/src/", snapshot.disambiguated_paths[first])
  t.assert_eq("other/src/", snapshot.disambiguated_paths[middle])
  t.assert_eq("test/", snapshot.disambiguated_paths[last])
end)

t:test("modified refresh does not query the global buffer list", function()
  local component, state = setup(2)
  local bufnr = state.bufs[1].bufnr
  vim.api.nvim_set_option_value("modified", true, { buf = bufnr })
  ---@return nil
  local function global_query()
    error("a tab snapshot must not collect data for unrelated buffers")
  end
  t:patch_table(vim.api, "nvim_eval", global_query)
  t:patch_table(vim.fn, "getbufinfo", global_query)

  local snapshot = component.refresh(context)
  t.assert_true(snapshot.bufs[1].modified)
  t.assert_false(snapshot.bufs[2].modified)
end)

t:test("new snapshots update absolute order, metadata and modified state", function()
  local component, state = setup(3, 2)
  local first = state.bufs[1].bufnr
  local previous = component.refresh(context)
  state.relative = false
  state.metas[first].filename = "renamed.lua"
  state.bufs[1].pinned = true
  vim.api.nvim_set_option_value("modified", true, { buf = first })
  local text = component.render(component.refresh(context), context, 1000)
  t.assert_true(text:find(" 1.F renamed.lua  ", 1, true) ~= nil, text)
  t.assert_true(text:find("▎2.F file0002.lua", 1, true) ~= nil)
  t.assert_true(text:find("▏3.F file0003.lua", 1, true) ~= nil)
  t.assert_false(component.render(previous, context, 1000):find("renamed.lua", 1, true) ~= nil)
end)

t:test("missing metadata and deleted buffers do not break layout", function()
  local component, state = setup(3)
  state.metas[state.bufs[1].bufnr] = nil
  vim.api.nvim_buf_delete(state.bufs[2].bufnr, { force = true })
  local text = component.render(component.refresh(context), context, 120)
  t.assert_true(text:find("file0003.lua", 1, true) ~= nil)
  t.assert_false(text:find("file0001.lua", 1, true) ~= nil)
  t.assert_false(text:find("file0002.lua", 1, true) ~= nil)
end)

t:test("modified markers follow native buffer state, including option-only changes", function()
  local component, state = setup(1)
  local bufnr = state.bufs[1].bufnr
  for _, options in ipairs({
    { modified = true },
    { modified = false },
    { fileformat = "dos" },
    { modified = false },
    { endofline = false },
    { buftype = "nofile", modified = true },
  }) do
    for name, value in pairs(options) do
      vim.api.nvim_set_option_value(name, value, { buf = bufnr })
    end
    local modified = vim.api.nvim_get_option_value("modified", { buf = bufnr })
    local text = component.render(component.refresh(context), context, 120)
    t.assert_eq(modified, text:find("  ", 1, true) ~= nil, vim.inspect(options))
  end
end)

t:test("snapshots do not copy variables from unrelated modified buffers into Lua", function()
  local component = setup(1)
  local bufnr = vim.api.nvim_create_buf(true, false)
  t:defer(function()
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)
  local payload = {}
  for index = 1, 100000 do
    payload[index] = "cached data"
  end
  vim.api.nvim_buf_set_var(bufnr, "synthetic_cache", payload)
  vim.api.nvim_set_option_value("modified", true, { buf = bufnr })

  -- Hold collection so transient copies cannot disappear before the allocation check.
  collectgarbage("stop")
  local resume_gc = t:defer(function()
    collectgarbage("restart")
  end)
  local before = collectgarbage("count")
  local snapshot = component.refresh(context)
  local allocated = collectgarbage("count") - before
  resume_gc()

  t.assert_true(allocated < 128, string.format("one-buffer snapshot allocated %.1f KiB", allocated))
  local text = component.render(snapshot, context, 120)
  t.assert_true(text:find("file0001.lua", 1, true) ~= nil)
  t.assert_false(text:find("  ", 1, true) ~= nil, "unrelated modified buffers do not affect this snapshot")
end)

t:test("no source buffer uses absolute order and a narrow window can hide the list", function()
  local component, state = setup(2)
  state.selected = nil
  local snapshot = component.refresh(context)
  t.assert_true(component.render(snapshot, context, 120):find(" 1.F file0001.lua", 1, true) ~= nil)
  local text, hltext = component.render(snapshot, context, 1)
  t.assert_eq("", text)
  t.assert_eq("", hltext)
end)

t:run()
