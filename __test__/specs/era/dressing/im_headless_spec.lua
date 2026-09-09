---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.era.dressing.im_headless" ---@type string

local harness = require("__test__.support.harness")
local t = harness.new("era.dressing.im headless RPC")

t:test("RPC-only Yuivim handles Insert events independently of focus", function()
  local root = assert(vim.uv.cwd())
  local channel = vim.fn.jobstart({ vim.v.progpath, "--embed", "--headless", "-u", "NONE", "-i", "NONE", "-n" }, {
    cwd = root,
    rpc = true,
  })
  t.assert_true(channel > 0, "embedded Neovim started")
  t:defer(function()
    if vim.fn.jobwait({ channel }, 0)[1] == -1 then
      vim.fn.jobstop(channel)
      vim.fn.jobwait({ channel }, 1000)
    end
  end)

  vim.rpcrequest(
    channel,
    "nvim_exec_lua",
    [[
    local root = ...
    vim.opt.runtimepath:prepend(root)
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
  ]],
    { root }
  )

  ---@param code                        string
  ---@return any
  local function eval(code)
    return vim.rpcrequest(channel, "nvim_exec_lua", code, {})
  end

  ---@param keys                        string
  ---@param mode                        string
  ---@return nil
  local function input(keys, mode)
    vim.rpcrequest(channel, "nvim_input", keys)
    t.wait_until(function()
      return vim.rpcrequest(channel, "nvim_get_mode").mode == mode
    end, 1000, "input did not reach mode " .. mode)
  end

  t.assert_eq(0, #vim.rpcrequest(channel, "nvim_list_uis"), "no Neovim UI attached")
  t.assert_eq(0, eval("return im_rpc_state.captures"), "startup does not switch the source")
  input("i", "i")
  input("<Esc>", "n")
  vim.rpcrequest(channel, "nvim_exec_autocmds", "VimResume", {})
  t.assert_eq(1, eval("return im_rpc_state.captures"), "InsertLeave selects English without focus")
  input("i", "i")
  t.assert_eq(1, eval("return im_rpc_state.restores"), "InsertEnter restores without focus")
  t.assert_eq("non_english.entry", eval("return im_rpc_state.source"))
  input("<Esc>", "n")

  vim.rpcrequest(channel, "nvim_exec_autocmds", "FocusGained", {})
  vim.rpcrequest(channel, "nvim_exec_autocmds", "FocusGained", {})
  t.assert_eq(3, eval("return im_rpc_state.captures"), "explicit focus independently selects English once")
  t.assert_eq("english", eval("return im_rpc_state.source"))

  input("i", "i")
  eval("im_rpc_state.source = 'non_english.editing'")
  input("<Esc>", "n")
  t.assert_eq(4, eval("return im_rpc_state.captures"), "actual InsertLeave captures the source")
  t.assert_eq("english", eval("return im_rpc_state.source"))
  input("i", "i")
  t.assert_eq(3, eval("return im_rpc_state.restores"), "actual InsertEnter restores the source")
  t.assert_eq("non_english.editing", eval("return im_rpc_state.source"))

  vim.rpcrequest(channel, "nvim_exec_autocmds", "FocusLost", {})
  eval("im_rpc_state.source = 'external.current'")
  input("<Esc>", "n")
  input("i", "i")
  t.assert_eq(5, eval("return im_rpc_state.captures"), "InsertLeave still captures after FocusLost")
  t.assert_eq(4, eval("return im_rpc_state.restores"), "InsertEnter still restores after FocusLost")
  t.assert_eq("external.current", eval("return im_rpc_state.source"), "external source is preserved")
  t.assert_eq(0, #vim.rpcrequest(channel, "nvim_list_uis"), "the complete lifecycle needs no UI")
  t.assert_eq("", eval("return vim.v.errmsg"), "no runtime errors")

  vim.rpcnotify(channel, "nvim_command", "qa!")
  t.assert_eq(0, vim.fn.jobwait({ channel }, 1000)[1], "embedded Neovim exited cleanly")
end)

t:run()
