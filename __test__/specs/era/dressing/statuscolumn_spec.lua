--- Run with: nvim -l __test__/run.lua __test__/specs/era/dressing/statuscolumn_spec.lua
---@diagnostic disable: undefined-global
--- Test for era.dressing.statuscolumn module

local harness = require("__test__.support.harness")

local t = harness.new("era.dressing.statuscolumn")

---@param callback                     function
---@param name                         string
---@return any, integer
local function get_upvalue(callback, name)
  local index = 1
  while true do
    local upvalue_name, value = debug.getupvalue(callback, index)
    if upvalue_name == nil then
      break
    end
    if upvalue_name == name then
      return value, index
    end
    index = index + 1
  end
  error("missing upvalue: " .. name)
end

---@return fun(winnr: integer, bufnr: integer, lnum: integer, wanted: era.dressing.statuscolumn.IWanted): era.dressing.statuscolumn.ISign[]
local function load_line_signs()
  local Statuscolumn = assert(loadfile("lua/era/dressing/statuscolumn.lua"))()
  local render = get_upvalue(Statuscolumn.statuscolumn, "statuscolumn") ---@type function
  local line_signs = get_upvalue(render, "line_signs") ---@type function
  return line_signs
end

local function setup_window()
  local previous_global = vim.api.nvim_get_option_value("statuscolumn", { scope = "global" })
  t:defer(function()
    vim.api.nvim_set_option_value("statuscolumn", previous_global, { scope = "global" })
  end)
  local bufnr = vim.api.nvim_create_buf(false, true)
  t:defer(function()
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)
  local winnr = vim.api.nvim_open_win(bufnr, true, { split = "right" })
  t:defer(function()
    if vim.api.nvim_win_is_valid(winnr) then
      vim.api.nvim_win_close(winnr, true)
    end
  end)
  return winnr, bufnr
end

t:test("dressing initializes once and preserves later window and global overrides", function()
  t:patch_global("era", { dressing = { statuscolumn = {
    statuscolumn = function()
      return ""
    end,
  } } })
  local other_winnr = vim.api.nvim_get_current_win()
  local previous_local = vim.api.nvim_get_option_value("statuscolumn", { win = other_winnr, scope = "local" })
  t:defer(function()
    vim.api.nvim_set_option_value("statuscolumn", previous_local, { win = other_winnr, scope = "local" })
  end)
  vim.api.nvim_set_option_value("statuscolumn", "other window", { win = other_winnr, scope = "local" })
  local winnr = setup_window()
  local Statuscolumn = assert(loadfile("lua/era/dressing/statuscolumn.lua"))()
  local expression = "%!v:lua.era.dressing.statuscolumn.statuscolumn()"

  Statuscolumn.dressing()
  t.assert_eq(expression, vim.api.nvim_get_option_value("statuscolumn", { scope = "global" }), "global default")
  t.assert_eq(
    expression,
    vim.api.nvim_get_option_value("statuscolumn", { win = winnr, scope = "local" }),
    "current window"
  )
  t.assert_eq("other window", vim.api.nvim_get_option_value("statuscolumn", { win = other_winnr, scope = "local" }))

  vim.api.nvim_set_option_value("statuscolumn", "", { win = winnr, scope = "local" })
  vim.api.nvim_set_option_value("statuscolumn", "later global", { scope = "global" })
  Statuscolumn.dressing()
  t.assert_eq(
    "",
    vim.api.nvim_get_option_value("statuscolumn", { win = winnr, scope = "local" }),
    "cleared window column"
  )
  t.assert_eq(
    "later global",
    vim.api.nvim_get_option_value("statuscolumn", { scope = "global" }),
    "later global default"
  )
end)

t:test("rendering and fold-click callbacks resolve through the dressing namespace", function()
  t:patch_global("era", require("era"))
  t:patch_table(package.loaded, "era.dressing.statuscolumn", nil)
  t:patch_table(vim.uv, "new_timer", function()
    return {
      is_active = function()
        return true
      end,
      start = function() end,
    }
  end)
  local winnr, bufnr = setup_window()
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "first", "second" })
  vim.api.nvim_set_option_value("number", true, { win = winnr })
  vim.api.nvim_set_option_value("relativenumber", false, { win = winnr })
  vim.api.nvim_set_option_value("signcolumn", "no", { win = winnr })
  vim.api.nvim_set_option_value("foldcolumn", "0", { win = winnr })

  t.assert_eq("era.dressing.statuscolumn", era.dressing.__mods.statuscolumn, "module registration")
  t.assert_nil(era.m.__mods.statuscolumn, "old registration removed")
  local Statuscolumn = era.dressing.statuscolumn
  local render = Statuscolumn.statuscolumn
  local rendered
  t:patch_table(Statuscolumn, "statuscolumn", function()
    rendered = render()
    return rendered
  end)

  Statuscolumn.dressing()
  local expression = vim.api.nvim_get_option_value("statuscolumn", { win = winnr, scope = "local" })
  local result = vim.api.nvim_eval_statusline(expression, { winid = winnr, use_statuscol_lnum = 2 })
  t.assert_eq("2", vim.trim(result.str), "native statuscolumn evaluation")
  t.assert_true(
    rendered:find("%@v:lua.era.dressing.statuscolumn.click_fold@", 1, true) == 1,
    "fold-click callback path"
  )
  t.assert_eq("function", type(era.dressing.statuscolumn.click_fold), "fold-click callback resolves")
end)

t:test("expires caches with a demand-driven one-shot timer", function()
  local timer = {
    active = false,
    callback = nil,
    starts = {},
  }
  local timer_count = 0
  local winnr = 1

  function timer:is_active()
    return self.active
  end

  function timer:start(timeout, repeat_interval, callback)
    self.active = true
    self.callback = callback
    self.starts[#self.starts + 1] = { timeout, repeat_interval }
  end

  t:patch_table(vim.uv, "new_timer", function()
    timer_count = timer_count + 1
    return timer
  end)
  t:patch_table(vim.api, "nvim_win_get_buf", function()
    return 1
  end)
  t:patch_table(vim.api, "nvim_get_option_value", function(name)
    if name == "signcolumn" then
      return "no"
    end
    if name == "foldcolumn" then
      return "0"
    end
    return false
  end)

  vim.g.statusline_winid = winnr
  local Statuscolumn = assert(loadfile("lua/era/dressing/statuscolumn.lua"))()

  Statuscolumn.statuscolumn()
  t.assert_eq(1, timer_count, "timer allocation count")
  t.assert_eq(1, #timer.starts, "initial timer start count")
  t.assert_eq(50, timer.starts[1][1], "expiration delay")
  t.assert_eq(0, timer.starts[1][2], "repeat interval")

  winnr = 2
  vim.g.statusline_winid = winnr
  Statuscolumn.statuscolumn()
  t.assert_eq(1, #timer.starts, "active timer remains scheduled once")

  timer.active = false
  assert(timer.callback)()
  Statuscolumn.statuscolumn()
  t.assert_eq(1, timer_count, "timer reuse count")
  t.assert_eq(2, #timer.starts, "timer restart count")
end)

t:test("shares complete sign data across windows with different components", function()
  local scan_count = 0
  t:patch_table(vim.api, "nvim_buf_get_extmarks", function()
    scan_count = scan_count + 1
    return {
      { 1, 0, 0, { sign_text = "S ", sign_hl_group = "DiagnosticSignError", priority = 100 } },
      { 2, 0, 0, { sign_text = "G ", sign_hl_group = "m_git_sign_add", priority = 10 } },
    }
  end)
  t:patch_table(vim.fn, "getmarklist", function()
    return {}
  end)

  local line_signs = load_line_signs()
  local git_signs = line_signs(1, 1, 1, { sign = false, git = true, mark = false, fold = false })
  local all_signs = line_signs(2, 1, 1, { sign = true, git = true, mark = false, fold = false })

  t.assert_eq(1, scan_count, "buffer sign scan count")
  t.assert_eq(1, #git_signs, "filtered sign count")
  t.assert_eq("git", git_signs[1].type, "filtered sign type")
  t.assert_eq(2, #all_signs, "complete sign count")
  t.assert_eq("sign", all_signs[1].type, "highest priority sign type")
  t.assert_eq("git", all_signs[2].type, "lower priority sign type")
end)

t:test("does not append fold signs to cached sign arrays", function()
  t:patch_global("stl", {
    icon = {
      fillchars = { foldclose = ">", foldopen = "v" },
    },
  })
  t:patch_table(vim.api, "nvim_buf_get_extmarks", function()
    return {
      { 1, 0, 0, { sign_text = "S ", sign_hl_group = "DiagnosticSignError", priority = 100 } },
    }
  end)
  t:patch_table(vim.fn, "getmarklist", function()
    return {}
  end)

  local line_signs = load_line_signs()
  local _, fold_info_index = get_upvalue(line_signs, "fold_info")
  debug.setupvalue(line_signs, fold_info_index, function()
    return { start = 1, level = 1, llevel = 1, lines = 0 }
  end)

  local wanted = { sign = true, git = true, mark = true, fold = true }
  local first_signs = line_signs(1, 1, 1, wanted)
  local second_signs = line_signs(2, 1, 1, wanted)

  t.assert_eq(2, #first_signs, "first render sign count")
  t.assert_eq(2, #second_signs, "second render sign count")
  t.assert_false(first_signs == second_signs, "render-local sign arrays")
end)

t:run()
