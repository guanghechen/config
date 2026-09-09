local harness = require("__test__.support.harness")
local Runtime = require("__test__.fixtures.era.m.textobject.runtime")
local t = harness.new("era.m.textobject.keymap")

local owned = {} ---@type table<string, function>
for _, key in ipairs({ "an", "in", "ai", "ii" }) do
  local callback = function() end
  owned[key] = callback
  vim.keymap.set({ "x", "o" }, key, callback, { desc = "existing " .. key })
end
local Textobject = Runtime.setup(t)

t:test("setup preserves native and indentscope mappings and is idempotent", function()
  Textobject.setup()
  for key, callback in pairs(owned) do
    for _, mode in ipairs({ "x", "o" }) do
      t.assert_eq(callback, vim.fn.maparg(key, mode, false, true).callback, key .. " ownership")
    end
  end
  for _, key in ipairs({ "[f", "]F", "[a", "]A", "[b", "]c", "[s", "]z", "g[", "g]" }) do
    for _, mode in ipairs({ "n", "x", "o" }) do
      t.assert_true(type(vim.fn.maparg(key, mode, false, true).callback) == "function", key .. " " .. mode)
    end
  end
end)

t:test("diff class motions fall back to native mappings", function()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local previous = vim.api.nvim_get_option_value("diff", { win = winnr }) ---@type boolean
  t:defer(function()
    vim.api.nvim_set_option_value("diff", previous, { win = winnr })
  end)
  vim.api.nvim_set_option_value("diff", true, { win = winnr })
  for _, key in ipairs({ "[c", "]c", "[C", "]C" }) do
    local mapping = vim.fn.maparg(key, "n", false, true)
    t.assert_eq(key, mapping.callback(), key .. " fallback")
  end
end)

t:test("slowly typed custom objects are remapped after the prefix timeout", function()
  local channel = vim.fn.jobstart(
    { vim.v.progpath, "--embed", "--headless", "-u", "NONE", "-i", "NONE", "-n" },
    { rpc = true }
  )
  t:defer(function()
    vim.fn.jobstop(channel)
  end)
  vim.rpcrequest(
    channel,
    "nvim_exec_lua",
    [[
    vim.opt.runtimepath:prepend(...)
    _G.stl = { nvim = { fn = require("stl.nvim.fn") } }
    _G.era = { m = { wk = { add = function() end } } }
    era.m.textobject = require("era.m.textobject")
    era.m.textobject.setup()
    vim.api.nvim_buf_set_lines(0, 0, -1, true, { "word other" })
    vim.o.timeoutlen = 1
    vim.keymap.set("o", "iz", function() vim.cmd("normal! viw") end)
  ]],
    { vim.uv.cwd() }
  )
  vim.rpcrequest(channel, "nvim_input", "yi")
  -- Real input keeps operator-pending alive, unlike feedkeys(..., "x").
  vim.wait(30)
  vim.rpcrequest(channel, "nvim_input", "z")
  t.wait_until(function()
    return vim.rpcrequest(channel, "nvim_eval", "getreg('\"')") == "word"
  end, 1000, "custom object after timeout")
end)

t:run()
