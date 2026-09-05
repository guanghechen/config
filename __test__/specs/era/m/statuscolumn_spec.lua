--- Run with: nvim -l __test__/run.lua __test__/specs/era/m/statuscolumn_spec.lua
---@diagnostic disable: undefined-global
--- Test for era.m.statuscolumn module

local harness = require("__test__.support.harness")

local t = harness.new("era.m.statuscolumn")

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

---@return fun(winnr: integer, bufnr: integer, lnum: integer, wanted: era.m.statuscolumn.IWanted): era.m.statuscolumn.ISign[]
local function load_line_signs()
  local Statuscolumn = assert(loadfile("lua/era/m/statuscolumn.lua"))()
  local render = get_upvalue(Statuscolumn.statuscolumn, "statuscolumn") ---@type function
  local line_signs = get_upvalue(render, "line_signs") ---@type function
  return line_signs
end

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
  local Statuscolumn = assert(loadfile("lua/era/m/statuscolumn.lua"))()

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
