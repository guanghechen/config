---@diagnostic disable: undefined-global
--- Run with: nvim -l lua/__test__/era/plugin/render-markdown.lua

local bootstrap = require("__test__.bootstrap")
local harness = require("__test__.harness")

local t = harness.new("era.plugin.render-markdown")

bootstrap.with_stl(t, {
  filetype = {
    get_markdown_filetypes = function()
      return { "markdown" }
    end,
  },
})
bootstrap.with_dot(t, {
  var = { N_CMP_DOCUMENTATION = "dot_cmp_documentation" },
})

local plugin = assert(loadfile("lua/era/plugin/render-markdown.lua"))()

t:test("ignores ephemeral completion documentation buffers", function()
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.b[bufnr][dot.var.N_CMP_DOCUMENTATION] = true

  local initial = vim.g.render_markdown_config ---@type table
  t.assert_true(initial.ignore(bufnr), "initial plugin setup")
  t.assert_true(plugin.opts.ignore(bufnr), "completion documentation")
  vim.b[bufnr][dot.var.N_CMP_DOCUMENTATION] = nil
  t.assert_false(plugin.opts.ignore(bufnr), "ordinary markdown")

  vim.g.render_markdown_config = nil
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:run()
