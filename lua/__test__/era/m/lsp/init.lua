---@diagnostic disable: undefined-global
--- Test for era.m.lsp module
--- Run with: nvim -l lua/__test__/era/m/lsp/init.lua

local bootstrap = require("__test__.bootstrap")
local harness = require("__test__.harness")

local t = harness.new("era.m.lsp")

bootstrap.with_stl(t, {
  nvim = {
    fn = {
      augroup = function()
        return 1
      end,
    },
  },
})

t:patch_table(package.loaded, "era.m.lsp.action", {
  code_action = function() end,
})
t:patch_table(package.loaded, "era.m.lsp.diagnostic", {
  setup = function() end,
})

local Lsp = require("era.m.lsp")

t:test("dressing: enables LSPs for existing and future buffers without re-editing", function()
  local filetypes = {
    [11] = "lua",
    [12] = "python",
    [13] = "rust",
  } ---@type table<integer, string>
  local enabled = {} ---@type table<string, integer>
  local filetype_callback = nil ---@type fun(args: { match: string })|nil
  local edits = 0 ---@type integer

  t:patch_table(vim.api, "nvim_create_autocmd", function(event, opts)
    if event == "FileType" then
      filetype_callback = opts.callback
    end
    return 1
  end)
  t:patch_table(vim.api, "nvim_list_bufs", function()
    return { 11, 12, 13, 14 }
  end)
  t:patch_table(vim.api, "nvim_buf_is_valid", function(bufnr)
    return bufnr ~= 14
  end)
  t:patch_table(vim.api, "nvim_buf_is_loaded", function(bufnr)
    return bufnr ~= 13
  end)
  t:patch_table(vim.api, "nvim_get_option_value", function(name, opts)
    t.assert_eq("filetype", name, "buffer option")
    return filetypes[opts.buf] or ""
  end)
  t:patch_table(vim.lsp, "enable", function(name)
    enabled[name] = (enabled[name] or 0) + 1
  end)
  t:patch_table(vim.lsp.buf, "code_action", vim.lsp.buf.code_action)
  t:patch_table(vim.cmd, "edit", function()
    edits = edits + 1
  end)

  Lsp.dressing()

  t.assert_eq(1, enabled.lua_ls, "existing Lua buffer")
  t.assert_eq(1, enabled.basedpyright, "existing Python buffer")
  t.assert_eq(1, enabled.ruff, "existing Python buffer secondary LSP")
  t.assert_nil(enabled.rust_analyzer, "unloaded buffer")
  t.assert_true(filetype_callback ~= nil, "future FileType callback")

  filetype_callback({ match = "typescript" })
  t.assert_eq(1, enabled.vtsls, "future TypeScript buffer")
  t.assert_eq(1, enabled.eslint, "future TypeScript secondary LSP")
  t.assert_eq(1, enabled.tailwindcss, "future TypeScript secondary LSP")

  filetype_callback({ match = "lua" })
  Lsp.dressing()

  t.assert_eq(1, enabled.lua_ls, "repeated enable")
  t.assert_eq(0, edits, "buffer re-edit")
end)

t:run()
