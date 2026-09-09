---@diagnostic disable: undefined-global

local harness = require("__test__.support.harness")
require("ark.bootstrap").setup()

local t = harness.new("ark.vendor.whichkey")

for _, vendor in ipairs({ "neovim", "neovide" }) do
  t:test(vendor .. " includes deferred surround mappings in the initial whichkey tree", function()
    for name in pairs(package.loaded) do
      if name:match("^era%.dressing%.whichkey") or name:match("^era%.m%.surrounds") then
        t:patch_table(package.loaded, name, nil)
      end
    end
    t:patch_table(era.m, "surrounds", nil)
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
    t:patch_table(era.dressing, "setup", function(names)
      for _, name in ipairs(names) do
        if name == "whichkey" then
          setup({ name })
        end
      end
    end)
    for _, name in ipairs({ "input", "lsp", "select", "image", "paste", "splitjoin", "textobject" }) do
      t:patch_table(era.m, name, { dressing = function() end, setup = function() end })
    end
    local original_require = require
    t:patch_global("require", function(name)
      if name:match("^ark%.vendor%.") or name == "dot.autocmd" or name == "era.command" or name == "era.plugin" then
        return {}
      end
      return original_require(name)
    end)

    local previous_bufnr = vim.api.nvim_get_current_buf()
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(bufnr)
    t:defer(function()
      era.dressing.whichkey.state.disable()
      vim.api.nvim_set_current_buf(previous_bufnr)
      vim.api.nvim_buf_delete(bufnr, { force = true })
      vim.api.nvim_del_augroup_by_name("WhichKey")
      vim.api.nvim_del_augroup_by_name("guanghechen_era_m_surrounds")
    end)

    assert(loadfile("lua/ark/vendor/" .. vendor .. "/init.lua"))()
    t.wait_until(function()
      return era.dressing.whichkey.state.ready and vim.fn.maparg("gsh", "n", false, true).desc ~= nil
    end, 1000, "deferred setup did not complete")

    local state = era.dressing.whichkey.state
    state.bufnr, state.mode = bufnr, "n"
    local node = state.get_node("gsh")
    t.assert_eq("surrounds: highlight", node and node.desc, "initial cache includes the late mapping")
  end)
end

t:run()
