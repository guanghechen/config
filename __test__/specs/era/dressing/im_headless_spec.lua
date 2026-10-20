local harness = require("__test__.support.harness")
local UI = require("__test__.support.ui")
local t = harness.new()

t:test("RPC-only Yuivim handles Insert events independently of focus", function()
  local ui = UI.new()
  t:defer(function()
    ui:close()
  end)
  ui:start({})
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
    end, 1000, "input did not reach mode " .. mode)
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
  end, 1000, "embedded Neovim exits")
  t.assert_eq(0, ui.exit_code, "embedded Neovim exited cleanly")
end)

t:run()
