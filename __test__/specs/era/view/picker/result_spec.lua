require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new()
local treeview = require("__test__.support.treeview")

---@param count                         ?integer
---@return era.view.ResultTree
local function tree(count)
  local source = require("era.view.result_source").new("root", { label = "root" })
  for row = 1, count or 2 do
    source:insert("root", tostring(row), { label = "item " .. row })
  end
  local value = require("era.view.result_tree").new({
    name = "result contract",
    tree = source,
    present = function(_, data)
      return { label = data.label }
    end,
  })
  value:insert("root", { nodetype = "container" })
  for row = 1, count or 2 do
    value:insert(tostring(row), { nodetype = "leaf" })
  end
  t:defer(function()
    value:dispose()
  end)
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
  vim.wait(100)
  t.wait_until(function()
    return value.lnum_current:snapshot() == 2
  end, 5000, "position after reopening")
  t.assert_eq(2, value.lnum_current:snapshot())
  t.assert_eq("", vim.api.nvim_get_option_value("winbar", { win = winnr }))
  value:set_lnum_current(3)
  value:dispose()
  vim.wait(100)
end)

t:test("status and diagnostic policies survive a failed publication", function()
  local owner = tree()
  local fail = false
  local reported
  t:patch_table(stl.reporter, "error", function(value)
    reported = value.from
  end)
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
  end, 1000)
  local bufnr = value:get_bufnr()
  local before = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, true), "\n")
  fail = true
  value._scheduler_content._task()
  t.assert_eq("result contract -> picker.result", reported)
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

t:run()
