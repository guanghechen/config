---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.ark.vendor.init" ---@type string

local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")
local t = harness.new("ark.vendor routing")

for _, case in ipairs({
  { flags = {}, vendor = "neovim" },
  { flags = { vscode = true }, vendor = "vscode" },
  { flags = { neovide = true }, vendor = "neovide" },
  { flags = { yozvim = true }, vendor = "yozvim" },
  { flags = { yui = true }, vendor = "yui" },
  { flags = { yui = false }, vendor = "neovim" },
  { flags = { yui = true, yozvim = true }, vendor = "yui" },
  { flags = { yui = true, neovide = true }, vendor = "neovide" },
  { flags = { yui = true, vscode = true }, vendor = "vscode" },
}) do
  t:test("routes " .. vim.inspect(case.flags) .. " to " .. case.vendor, function()
    local calls = {} ---@type string[]
    t:patch_table(vim, "g", vim.deepcopy(case.flags))
    bootstrap.with_dot(t, { path = {
      is_git_repo = function()
        return false
      end,
    } })
    t:patch_global("require", function(name)
      calls[#calls + 1] = name
      if name == "ark.bootstrap" then
        return {
          setup = function()
            calls[#calls + 1] = "bootstrap.setup"
          end,
        }
      end
      return true
    end)

    assert(loadfile("init.lua"))()

    t.assert_true(
      vim.deep_equal({ "ark.bootstrap", "bootstrap.setup", "ark.vendor." .. case.vendor }, calls),
      "one vendor is selected after bootstrap"
    )
    t.assert_true(vim.deep_equal(case.flags, vim.g), "host identity is not rewritten")
  end)
end

t:test("Yui starts the real minimal profile without taking over host features", function()
  local previous_yui = vim.g.yui
  vim.g.yui = true
  t:defer(function()
    vim.g.yui = previous_yui
  end)
  -- Keep the composed runtime independent of persisted user/workspace settings.
  t:patch_table(require("dot"), "get_default_storage", function()
    return {}
  end)
  local errors = {} ---@type string[]
  t:patch_table(vim, "notify", function(message, level)
    if level == vim.log.levels.ERROR then
      errors[#errors + 1] = message
    end
  end)
  for _, name in ipairs({ "ark.vendor.local.plugin", "ark.vendor.local.dressing" }) do
    t:patch_table(package.preload, name, function()
      return {}
    end)
  end

  assert(loadfile("init.lua"))()
  t.assert_true(era.dressing.get_load_times().im ~= nil, "IM is registered synchronously")
  t.wait_until(function()
    return package.loaded["era.m.surrounds"] ~= nil
  end, 3000, "deferred minimal setup did not complete")

  t.assert_true(package.loaded["ark.vendor.yui"], "Yui entry loaded")
  t.assert_nil(package.loaded["ark.vendor.yozvim"], "Yui owns its initialization")
  t.assert_true(package.loaded["ark.vendor.yui.option"], "Yui options loaded")
  t.assert_true(package.loaded["ark.vendor.yui.keymap"], "Yui keymaps loaded")
  t.assert_nil(package.loaded["ark.vendor.yozvim.option"], "Yozvim options remain independent")
  t.assert_nil(package.loaded["ark.vendor.yozvim.keymap"], "Yozvim keymaps remain independent")
  t.assert_true(package.loaded["era.m.splitjoin"], "splitjoin retained")
  t.assert_nil(vim.g.yozvim, "Yui does not impersonate Yozvim")
  local dressing_names = vim.tbl_keys(era.dressing.get_load_times())
  table.sort(dressing_names)
  t.assert_true(vim.deep_equal({ "im" }, dressing_names), "only IM dressing is enabled")
  local winnr = vim.api.nvim_get_current_win()
  local bufnr = vim.api.nvim_get_current_buf()
  t.assert_eq("no", vim.api.nvim_get_option_value("signcolumn", { win = winnr }))
  t.assert_false(vim.api.nvim_get_option_value("cursorline", { win = winnr }))
  t.assert_eq(
    dot.context.option.relativenumber:snapshot(),
    vim.api.nvim_get_option_value("relativenumber", { win = winnr })
  )
  t.assert_eq(dot.context.option.expandtab:snapshot(), vim.api.nvim_get_option_value("expandtab", { buf = bufnr }))
  t.assert_eq(1000, vim.o.timeoutlen)
  t.assert_nil(vim.api.nvim_get_commands({ builtin = false }).Plugin, "plugin manager is not initialized")
  vim.api.nvim_exec_autocmds("FileType", { pattern = "python", modeline = false })
  for _, name in ipairs({
    "ark.vendor.neovim",
    "ark.vendor.local.plugin",
    "ark.vendor.local.dressing",
    "dot.autocmd",
    "era.plugin",
    "era.m.plugin",
    "era.m.plugin.loader",
    "era.dressing.commentstring",
    "era.dressing.ui_attach",
    "era.dressing.notifier",
    "era.m.git",
    "era.m.lsp",
    "era.m.python_venv",
    "era.m.textobject",
  }) do
    t.assert_nil(package.loaded[name], "host-owned feature was loaded: " .. name)
  end
  t.assert_eq(0, #errors, table.concat(errors, "\n"))
end)

t:run()
