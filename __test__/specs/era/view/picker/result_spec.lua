require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new()
local bootstrap = require("__test__.support.bootstrap")
local picker = require("__test__.support.picker")
local treeview = require("__test__.support.treeview")

---@param count                         ?integer
---@return era.view.ResultTree
local function tree(count)
  local source = require("era.view.result_source").new("root", { label = "root" })
  for row = 1, count or 2 do
    source:insert("root", tostring(row), { label = "item " .. row })
  end
  local value = picker.result_tree(t, "result contract", source)
  value:insert("root", { nodetype = "container" })
  for row = 1, count or 2 do
    value:insert(tostring(row), { nodetype = "leaf" })
  end
  return value
end

---@param owner                         era.view.ResultTree
---@param policy                        string
---@param options                       ?table
---@return era.view.PickerResult
local function result(owner, policy, options)
  local value = era.view.PickerResult.new(vim.tbl_extend("force", {
    uuid = "result contract " .. policy,
    name = "result contract",
    diagnostic_scope = policy .. ".result",
    augroup_prefix = policy .. ".result",
    winline_hl = "f_wl_" .. policy,
    tree = owner,
    keymaps = {},
    flags = {},
    draw = function()
      return owner:publish({ mode = "list", rootuuid = "root" })
    end,
  }, options or {}))
  t:defer(function()
    value:dispose()
  end)
  return value
end

for _, kind in ipairs({ "picker", "searcher" }) do
  t:test(kind .. " aliases the shared native surface", function()
    t.assert_true(era.m[kind].Result == era.view.PickerResult)
  end)
  t:test(kind .. " uses bounded signs when every row is selected", function()
    local owner = tree(512)
    local value = result(owner, kind)
    value:create_win({ border = "", number = false, winhighlight = "" }, { row = 0, col = 0, width = 40, height = 4 })
    treeview.await(owner:ready())
    vim.wait(100)
    local calls = 0
    local sign_place = vim.fn.sign_place
    t:patch_table(vim.fn, "sign_place", function(...)
      calls = calls + 1
      return sign_place(...)
    end)
    owner:toggle_select("root", true, true)
    treeview.await(owner:ready())
    -- Signs placed per selected row would land within this window.
    vim.wait(100)
    t.assert_true(owner:isselected("512"))
    t.assert_true(calls <= 2, "selection must not place a persistent sign per result")
  end)
end

t:test("an omitted winbar preserves positions across refresh, resize and reopening", function()
  local owner = tree(3)
  local value = result(owner, "picker", { winbar = false })
  local options = { border = "single", number = false, winhighlight = "" }
  local dimension = { row = 0, col = 0, width = 40, height = 4 }
  local winnr = value:create_win(options, dimension)
  treeview.await(owner:ready())
  value:set_lnum_current(2)
  value:mark_nvimbar_dirty()
  value:resize({ row = 0, col = 0, width = 50, height = 5 })
  treeview.await(owner:ready())
  -- The window lets a late winbar appear; positions may publish after it.
  vim.wait(100)
  t.wait_until(function()
    return value.lnum_current:snapshot() == 2 and value.lnum_total:snapshot() == 3
  end, 5000, "positions after resize")
  t.assert_eq(2, value.lnum_current:snapshot())
  t.assert_eq(3, value.lnum_total:snapshot())
  t.assert_eq("", vim.api.nvim_get_option_value("winbar", { win = winnr }))
  value:hide()
  winnr = value:create_win(options, dimension)
  treeview.await(owner:ready())
  -- The window lets a late winbar appear; the position may publish after it.
  vim.wait(100)
  t.wait_until(function()
    return value.lnum_current:snapshot() == 2
  end, 5000, "position after reopening")
  t.assert_eq(2, value.lnum_current:snapshot())
  t.assert_eq("", vim.api.nvim_get_option_value("winbar", { win = winnr }))
  local errmsg = vim.v.errmsg
  t:defer(function()
    vim.v.errmsg = errmsg
  end)
  value:set_lnum_current(3)
  value:dispose()
  -- A callback the cursor change queued would fail after dispose within this window.
  vim.wait(100)
  t.assert_eq(errmsg, vim.v.errmsg, "a cursor change queued before dispose raises no editor error")
end)

t:test("status and diagnostic policies survive a failed publication", function()
  local owner = tree()
  local fail = false
  local reports = bootstrap.with_reporter(t)
  local value = result(owner, "picker", {
    status = function()
      return "READY", "picker_result_limit"
    end,
    draw = function()
      if fail then
        error("draw failure")
      end
      return owner:publish({ mode = "list", rootuuid = "root" })
    end,
  })
  local winnr = value:create_win(
    { border = "", number = false, winhighlight = "" },
    { row = 0, col = 0, width = 40, height = 4 }
  )
  treeview.await(owner:ready())
  t.wait_until(function()
    return vim.api.nvim_get_option_value("winbar", { win = winnr }):find("READY", 1, true) ~= nil
  end, 5000)
  local bufnr = value:get_bufnr()
  local before = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, true), "\n")
  fail = true
  value._scheduler_content._task()
  local reported = reports.error[#reports.error]
  t.assert_eq("result contract -> picker.result", reported and reported.from)
  t.assert_eq(before, table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, true), "\n"))
  t.assert_false(vim.api.nvim_get_option_value("modifiable", { buf = bufnr }))
  t.assert_false(vim.api.nvim_get_option_value("readonly", { buf = bufnr }))
end)

t:test("flag callbacks are unregistered when a result is disposed", function()
  local names = {}
  local original = dot.G.register_anonymous_fn
  t:patch_table(dot.G, "register_anonymous_fn", function(...)
    local path, unregister = original(...)
    names[#names + 1] = assert(path:match("^dot%.G%.(.+)$"))
    return path, unregister
  end)
  local calls = 0
  local value = result(tree(), "picker", {
    flags = {
      {
        desc = "flag",
        callback = function()
          calls = calls + 1
        end,
        snapshot = function()
          return "1", "Normal"
        end,
      },
    },
  })
  t.assert_eq(1, #names)
  dot.G[names[1]]()
  t.assert_eq(1, calls)
  value:dispose()
  t.assert_nil(dot.G[names[1]])
end)

---A result of the whole of `owner`, drawn as a tree, under `uuid`.
---@param owner                         era.view.ResultTree
---@param uuid                          string
---@return era.view.PickerResult
local function tree_result(owner, uuid)
  return result(owner, "picker", {
    uuid = uuid,
    draw = function()
      return owner:publish({ mode = "tree", rootuuid = "root" })
    end,
  })
end

t:test("Result publishes native counts and preserves state through hide and reopen", function()
  local tree = picker.file_tree(t)
  local value = tree_result(tree, "native result")
  value:create_win({ border = "none", number = true, winhighlight = "" }, { row = 0, col = 0, width = 40, height = 6 })
  treeview.await(tree:ready())
  t.assert_eq(2, value.lnum_total:snapshot())
  local state = tree.state
  tree:toggle_select("file", true, false)
  treeview.await(tree:ready())
  local old_bufnr = value:get_bufnr()
  local view = tree.view
  local writes = 0
  local set_lines = vim.api.nvim_buf_set_lines
  t:patch_table(vim.api, "nvim_buf_set_lines", function(bufnr, ...)
    if bufnr == old_bufnr then
      writes = writes + 1
    end
    return set_lines(bufnr, ...)
  end)
  value:hide()
  t.assert_true(vim.api.nvim_buf_is_valid(old_bufnr))
  t.assert_true(view:is_suspended())
  value:create_win({ border = "none", number = true, winhighlight = "" }, { row = 0, col = 0, width = 40, height = 6 })
  treeview.await(tree:ready())
  t.wait_until(function()
    return not view:status().preparing
  end, 5000)
  t.assert_true(tree.state == state)
  t.assert_true(tree:isselected("file"))
  t.assert_eq(2, value.lnum_total:snapshot())
  t.assert_eq(old_bufnr, value:get_bufnr())
  t.assert_true(tree.view == view)
  t.assert_eq(0, writes, "reopening unchanged results must not rebuild buffer text")
end)

for _, change in ipairs({ "producer", "published", "edited", "deleted" }) do
  t:test("a hidden result recovers a " .. change .. " buffer or source on reopen", function()
    local tree = picker.file_tree(t)
    local value = tree_result(tree, "hidden " .. change)
    value:create_win(
      { border = "none", number = false, winhighlight = "" },
      { row = 0, col = 0, width = 40, height = 6 }
    )
    treeview.await(tree:ready())
    local bufnr, state = value:get_bufnr(), tree.state
    value:hide()
    if change == "producer" or change == "published" then
      tree.source:update("file", { label = "changed.lua" })
      if change == "published" then
        for index = 1, 4 do
          tree.source:update("file", { label = "changed.lua", value = index })
          treeview.await(tree:publish({ mode = "tree", rootuuid = "root" }))
          t.assert_true(vim.tbl_count(tree._versions) <= 2, "hidden updates retain only current and displayed metadata")
        end
        t.assert_eq("changed.lua", tree:data("file").label)
        t.assert_true(vim.api.nvim_buf_get_lines(bufnr, 1, 2, true)[1]:find("file.lua", 1, true) ~= nil)
      end
    elseif change == "edited" then
      vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, { "external change" })
    else
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
    value:create_win(
      { border = "none", number = true, winhighlight = "" },
      { row = 0, col = 0, width = 55, height = 4 }
    )
    treeview.await(tree:ready())
    t.wait_until(function()
      return tree.view and not tree.view:status().preparing
    end, 5000)
    local expected = (change == "producer" or change == "published") and "changed.lua" or "file.lua"
    t.assert_true(vim.api.nvim_buf_get_lines(value:get_bufnr(), 1, 2, true)[1]:find(expected, 1, true) ~= nil)
    t.assert_true(state == tree.state)
    t.assert_eq(change ~= "deleted", bufnr == value:get_bufnr())
    t.assert_true(vim.api.nvim_get_option_value("number", { win = value:get_winnr() }))
    t.assert_false(vim.api.nvim_get_option_value("modifiable", { buf = value:get_bufnr() }))
    value:hide()
    local retained = value:get_bufnr()
    value:dispose()
    t.assert_false(vim.api.nvim_buf_is_valid(retained), "disposal releases the retained hidden buffer")
  end)
end

t:test("a late cursor acknowledgement preserves the current Visual endpoint", function()
  local tree = picker.file_tree(t)
  local value = tree_result(tree, "cursor acknowledgement")
  t:defer(function()
    vim.cmd.normal({ args = { vim.keycode("<Esc>") }, bang = true })
  end)
  value:create_win({ border = "none", number = false, winhighlight = "" }, { row = 0, col = 0, width = 40, height = 6 })
  treeview.await(tree:ready())
  value:focus()
  local acknowledged = tree:frame()
  vim.cmd.normal({ args = { "ggVj" }, bang = true })
  value.lnum_current:next(2, { silent = true })
  t.assert_eq(1, acknowledged:header().cursor_row)
  -- An unchanged-layout publication keeps Visual endpoints even when its cursor acknowledgement is older.
  tree.view._options.on_frame(acknowledged)
  t.assert_eq(2, value.lnum_current:snapshot())
  vim.wait(20)
  t.assert_eq("V", vim.api.nvim_get_mode().mode)
  t.assert_eq(2, vim.api.nvim_win_get_cursor(value:get_winnr())[1])
end)

t:run()
