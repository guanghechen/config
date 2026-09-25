---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.era.m.explorer.exit" ---@type string

local t = require("__test__.support.harness").new("era.m.explorer.exit")

---@return __test__.support.UI, string
local function editor()
  local marker = vim.fn.tempname()
  local ui = require("__test__.support.ui").new()
  t:defer(function()
    ui:close()
    vim.fn.delete(marker)
  end)
  ui:rpc("nvim_ui_attach", 80, 24, { rgb = true, ext_linegrid = true })
  ui:rpc(
    "nvim_exec_lua",
    [=[
    local root, marker = ...
    vim.opt.runtimepath:prepend(root)
    stl = { nvim = { fn = require("stl.nvim.fn") }, reporter = { warn = function() end } }
    pending, prompts, cancellations, choice = true, 0, 0, 1
    vim.ui.select = function(items, _, done) prompts = prompts + 1; done(items[choice], choice) end
    require("era.m.explorer.exit").setup({
      pending = function() return pending end,
      poll = function() end,
      cancel_all = function()
        cancellations = cancellations + 1
        vim.defer_fn(function() pending = false end, 100)
      end,
    })
    vim.api.nvim_create_autocmd("VimLeavePre", { callback = function()
      vim.fn.writefile({ pending and "unsafe" or "stopped", tostring(cancellations) }, marker)
    end })
  ]=],
    { assert(vim.uv.cwd()), marker }
  )
  return ui, marker
end

t:test("Wait cancels the actual typed quit without replacing windows or cancelling tasks", function()
  local ui = editor()
  local winnr = ui:rpc("nvim_get_current_win")
  ui:rpc("nvim_input", ":qall!\r")
  t.wait_until(function()
    return ui:rpc("nvim_exec_lua", "return prompts", {}) == 1
  end, 3000)
  t.assert_eq(winnr, ui:rpc("nvim_get_current_win"))
  t.assert_eq(0, ui:rpc("nvim_exec_lua", "return cancellations", {}))
  t.assert_true(ui:rpc("nvim_exec_lua", "return pending", {}))
end)

t:test("closing one pane does not request process exit confirmation", function()
  local ui = editor()
  ui:rpc("nvim_command", "vnew")
  ui:rpc("nvim_input", ":q\r")
  t.wait_until(function()
    return #ui:rpc("nvim_list_wins") == 1
  end, 3000)
  t.assert_eq(0, ui:rpc("nvim_exec_lua", "return prompts", {}))
  t.assert_eq(0, ui:rpc("nvim_exec_lua", "return cancellations", {}))
end)

t:test("quit chains distinguish closing a pane from exiting the process", function()
  local ui = editor()
  ui:rpc("nvim_command", "vnew")
  ui:rpc("nvim_input", ":q | qall!\r")
  t.wait_until(function()
    return ui:rpc("nvim_exec_lua", "return prompts", {}) == 1
  end, 3000)
  t.assert_eq(2, #ui:rpc("nvim_list_wins"))
  t.assert_eq(0, ui:rpc("nvim_exec_lua", "return cancellations", {}))
  ui:rpc("nvim_input", ":echo 1 | q\r")
  t.wait_until(function()
    return #ui:rpc("nvim_list_wins") == 1
  end, 3000)
  t.assert_eq(1, ui:rpc("nvim_exec_lua", "return prompts", {}))
  ui:rpc("nvim_input", ":split | q\r")
  t.wait_until(function()
    return ui:rpc("nvim_get_mode").mode == "n"
  end, 3000)
  t.assert_eq(1, #ui:rpc("nvim_list_wins"))
  t.assert_eq(1, ui:rpc("nvim_exec_lua", "return prompts", {}))
end)

t:test("only and tab commands in a quit chain preserve the default Wait choice", function()
  for _, case in ipairs({
    { setup = "vnew", command = "only | q" },
    { setup = "vnew", command = "wincmd o | q" },
    { setup = "tabnew", command = "tabonly | q" },
    { setup = "tabnew", command = "tabclose | q" },
    { setup = "tabnew | vnew", command = "only | tabonly | q" },
  }) do
    local ui = editor()
    ui:rpc("nvim_command", case.setup)
    local windows = #ui:rpc("nvim_list_wins")
    ui:rpc("nvim_input", ":" .. case.command .. "\r")
    t.wait_until(function()
      return ui:rpc("nvim_exec_lua", "return prompts", {}) == 1
    end, 3000)
    t.assert_eq(windows, #ui:rpc("nvim_list_wins"), case.command)
    t.assert_eq(0, ui:rpc("nvim_exec_lua", "return cancellations", {}))
  end
end)

t:test("confirmed exit and direct scripted exit both wait for cancellation acknowledgement", function()
  for _, scripted in ipairs({ false, true }) do
    local ui, marker = editor()
    if scripted then
      pcall(ui.rpc, ui, "nvim_command", "qall!")
    else
      ui:rpc("nvim_exec_lua", "choice = 2", {})
      ui:rpc("nvim_input", ":qall!\r")
    end
    t.wait_until(function()
      return ui._exited
    end, 3000)
    t.assert_eq("stopped", vim.fn.readfile(marker)[1])
    t.assert_eq("1", vim.fn.readfile(marker)[2])
  end
end)

t:run()
