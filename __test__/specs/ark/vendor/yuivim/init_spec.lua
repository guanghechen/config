local harness = require("__test__.support.harness")
local UI = require("__test__.support.ui")
local t = harness.new()

t:test("Yuivim starts the real minimal profile without taking over host features", function()
  local previous_yuivim = vim.g.yuivim
  vim.g.yuivim = true
  t:defer(function()
    vim.g.yuivim = previous_yuivim
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
    return package.loaded["era.keystroke.surrounds"] ~= nil
  end, 5000, "deferred minimal setup did not complete")

  t.assert_true(package.loaded["ark.vendor.yuivim"], "Yuivim entry loaded")
  t.assert_nil(package.loaded["ark.vendor.yozvim"], "Yuivim owns its initialization")
  t.assert_true(package.loaded["ark.vendor.yuivim.option"], "Yuivim options loaded")
  t.assert_true(package.loaded["ark.vendor.yuivim.keymap"], "Yuivim keymaps loaded")
  t.assert_nil(package.loaded["ark.vendor.yozvim.option"], "Yozvim options remain independent")
  t.assert_nil(package.loaded["ark.vendor.yozvim.keymap"], "Yozvim keymaps remain independent")
  t.assert_true(package.loaded["era.keystroke.splitjoin"], "splitjoin retained")
  t.assert_nil(vim.g.yozvim, "Yuivim does not impersonate Yozvim")
  local dressing_names = vim.tbl_keys(era.dressing.get_load_times())
  table.sort(dressing_names)
  t.assert_same({ "im" }, dressing_names, "only IM dressing is enabled")
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
    "era.keystroke.textobject",
  }) do
    t.assert_nil(package.loaded[name], "host-owned feature was loaded: " .. name)
  end
  t.assert_eq(0, #errors, table.concat(errors, "\n"))
end)

t:test("RPC-only Yuivim handles Insert events independently of focus", function()
  local ui = UI.open(t, {})
  ui:lua([[
    vim.g.yuivim = true
    require("ark.bootstrap").setup()
    dot.get_default_storage = function() return {} end

    -- Simulate the native backend so the test cannot change OS input methods.
    stl.env.IS_OSX, stl.env.IS_WIN, stl.env.IS_WSL = true, false, false
    local state = { source = "non_english.entry", captures = 0, restores = 0 }
    _G.im_rpc_state = state
    yoz.im = {
      capture = function() return state.source end,
      capture_and_select_english = function()
        state.captures = state.captures + 1
        local previous = state.source
        state.source = "english"
        return previous, true
      end,
      restore = function(source)
        state.restores = state.restores + 1
        state.source = source
        return true
      end,
      is_english = function(source) return source == "english" end,
    }
    require("ark.vendor.yuivim")
  ]])

  ---@param keys                        string
  ---@param mode                        string
  ---@return nil
  local function input(keys, mode)
    ui:rpc("nvim_input", keys)
    ui:wait_until(function()
      return ui:rpc("nvim_get_mode").mode == mode
    end, 5000, "input did not reach mode " .. mode)
  end

  t.assert_eq(0, #ui:rpc("nvim_list_uis"), "no Neovim UI attached")
  t.assert_eq(0, ui:lua("return im_rpc_state.captures"), "startup does not switch the source")
  input("i", "i")
  input("<Esc>", "n")
  ui:rpc("nvim_exec_autocmds", "VimResume", {})
  t.assert_eq(1, ui:lua("return im_rpc_state.captures"), "InsertLeave selects English without focus")
  input("i", "i")
  t.assert_eq(1, ui:lua("return im_rpc_state.restores"), "InsertEnter restores without focus")
  t.assert_eq("non_english.entry", ui:lua("return im_rpc_state.source"))
  input("<Esc>", "n")

  ui:rpc("nvim_exec_autocmds", "FocusGained", {})
  ui:rpc("nvim_exec_autocmds", "FocusGained", {})
  t.assert_eq(3, ui:lua("return im_rpc_state.captures"), "explicit focus independently selects English once")
  t.assert_eq("english", ui:lua("return im_rpc_state.source"))

  input("i", "i")
  ui:lua("im_rpc_state.source = 'non_english.editing'")
  input("<Esc>", "n")
  t.assert_eq(4, ui:lua("return im_rpc_state.captures"), "actual InsertLeave captures the source")
  t.assert_eq("english", ui:lua("return im_rpc_state.source"))
  input("i", "i")
  t.assert_eq(3, ui:lua("return im_rpc_state.restores"), "actual InsertEnter restores the source")
  t.assert_eq("non_english.editing", ui:lua("return im_rpc_state.source"))

  ui:rpc("nvim_exec_autocmds", "FocusLost", {})
  ui:lua("im_rpc_state.source = 'external.current'")
  input("<Esc>", "n")
  input("i", "i")
  t.assert_eq(5, ui:lua("return im_rpc_state.captures"), "InsertLeave still captures after FocusLost")
  t.assert_eq(4, ui:lua("return im_rpc_state.restores"), "InsertEnter still restores after FocusLost")
  t.assert_eq("external.current", ui:lua("return im_rpc_state.source"), "external source is preserved")
  t.assert_eq(0, #ui:rpc("nvim_list_uis"), "the complete lifecycle needs no UI")
  t.assert_eq("", ui:lua("return vim.v.errmsg"), "no runtime errors")

  ui:notify("nvim_command", "qa!")
  t.wait_until(function()
    return ui.exit_code ~= nil
  end, 5000, "embedded Neovim exits")
  t.assert_eq(0, ui.exit_code, "embedded Neovim exited cleanly")
end)

t:run()
