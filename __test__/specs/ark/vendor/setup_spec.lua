local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")
require("ark.bootstrap").setup()

local t = harness.new()
local expression = "%!v:lua.era.dressing.statuscolumn.statuscolumn()"

for _, vendor in ipairs({ "neovim", "neovide" }) do
  t:test(vendor .. " initializes the gutter before plugins create splits and focus a picker", function()
    local dressing = assert(loadfile("lua/era/dressing/init.lua"))()
    local Statuscolumn = assert(loadfile("lua/era/dressing/statuscolumn.lua"))()
    t:patch_table(package.loaded, "era.dressing.statuscolumn", Statuscolumn)
    for name in pairs(dressing.__mods) do
      if name ~= "statuscolumn" then
        dressing[name] = { dressing = function() end }
      end
    end
    local modules = {}
    for _, name in ipairs({ "input", "lsp", "select", "image", "paste" }) do
      modules[name] = { dressing = function() end, setup = function() end }
    end
    local completed = false
    bootstrap.with_runtime(t, {
      era = {
        dressing = dressing,
        keystroke = {
          cmp = { setup = function() end },
          splitjoin = { setup = function() end },
          surrounds = { setup = function() end },
          textobject = { setup = function() end },
        },
        m = modules,
      },
      dot = {
        setup_context = function() end,
        setup_diagnostics = function() end,
        path = {
          is_git_repo = function()
            return false
          end,
        },
        context = {
          watch_changes = function()
            completed = true
          end,
        },
      },
    })

    local source_bufnr = t:buffer()
    local picker_bufnr = t:buffer()
    local file_bufnr = t:buffer({ "local value = 1" })
    local source_winnr = t:window(source_bufnr, { split = "right" }, true)
    vim.api.nvim_set_option_value("statuscolumn", "", {})
    local split_winnr, picker_winnr
    local original_require = require
    t:patch_global("require", function(name)
      if name == "era.plugin" then
        split_winnr = t:window(source_bufnr, { split = "below" }, true)
        picker_winnr = t:window(picker_bufnr, {
          relative = "editor",
          row = 0,
          col = 0,
          width = 20,
          height = 3,
          style = "minimal",
        }, true)
        return {}
      end
      if name:match("^ark%.vendor%.") or name == "dot.autocmd" or name == "era.command" then
        return {}
      end
      return original_require(name)
    end)

    assert(loadfile("lua/ark/vendor/" .. vendor .. "/init.lua"))()
    t.wait_until(function()
      return completed
    end, 5000, "deferred vendor setup did not complete")

    local picker_expression = vim.api.nvim_get_option_value("statuscolumn", { win = picker_winnr })
    vim.api.nvim_set_current_win(source_winnr)
    vim.api.nvim_win_close(picker_winnr, true)
    vim.api.nvim_win_set_buf(source_winnr, file_bufnr)

    t.assert_eq(expression, vim.api.nvim_get_option_value("statuscolumn", { win = source_winnr }))
    t.assert_eq(expression, vim.api.nvim_get_option_value("statuscolumn", { scope = "global" }))
    t.assert_eq(expression, vim.api.nvim_get_option_value("statuscolumn", { win = split_winnr }))
    t.assert_eq("", picker_expression, "minimal picker keeps its local override")
  end)
end

for _, vendor in ipairs({ "neovim", "neovide" }) do
  t:test(vendor .. " includes deferred surround mappings in the initial whichkey tree", function()
    for name in pairs(package.loaded) do
      if name:match("^era%.dressing%.whichkey") or name:match("^era%.keystroke%.surrounds") then
        t:patch_table(package.loaded, name, nil)
      end
    end
    t:patch_table(era.keystroke, "surrounds", nil)
    t:patch_table(dot, "setup_context", function() end)
    t:patch_table(dot, "setup_diagnostics", function() end)
    t:patch_table(dot.path, "is_git_repo", function()
      return false
    end)
    t:patch_table(dot.context, "watch_changes", function() end)

    -- Keep the actual vendor schedule, whichkey observer, and surround keymaps.
    local observe = stl.fn.observe
    t:patch_table(stl.fn, "observe", function(...)
      local subscription = observe(...)
      t:defer(subscription.unsubscribe)
      return subscription
    end)
    local setup = era.dressing.setup
    local lua_scroll_requested = false
    t:patch_table(era.dressing, "setup", function(names)
      for _, name in ipairs(names) do
        if name == "scroll" then
          lua_scroll_requested = true
        end
        if name == "whichkey" then
          setup({ name })
        end
      end
    end)
    for _, name in ipairs({ "input", "lsp", "select", "image", "paste" }) do
      t:patch_table(era.m, name, { dressing = function() end, setup = function() end })
    end
    t:patch_table(era.keystroke, "splitjoin", { setup = function() end })
    t:patch_table(era.keystroke, "cmp", { setup = function() end })
    t:patch_table(era.keystroke, "textobject", { setup = function() end })
    local original_require = require
    t:patch_global("require", function(name)
      if name:match("^ark%.vendor%.") or name == "dot.autocmd" or name == "era.command" or name == "era.plugin" then
        return {}
      end
      return original_require(name)
    end)

    t:defer(function()
      vim.api.nvim_del_augroup_by_name("WhichKey")
      vim.api.nvim_del_augroup_by_name("guanghechen_era_keystroke_surrounds")
    end)
    local bufnr = t:buffer(nil, { current = true })
    t:defer(function()
      era.dressing.whichkey.state.disable()
    end)

    assert(loadfile("lua/ark/vendor/" .. vendor .. "/init.lua"))()
    t.wait_until(function()
      return era.dressing.whichkey.state.ready and vim.fn.maparg("gsh", "n", false, true).desc ~= nil
    end, 5000, "deferred setup did not complete")

    t.assert_eq(vendor == "neovim", lua_scroll_requested, "only terminal Neovim requests Lua scrolling")
    local state = era.dressing.whichkey.state
    state.bufnr, state.mode = bufnr, "n"
    local node = state.get_node("gsh")
    t.assert_eq("surrounds: highlight", node and node.desc, "initial cache includes the late mapping")
  end)
end

t:run()
