---@diagnostic disable: undefined-global
--- Run with: nvim -l lua/__test__/stl/nvim/buf.lua

local bootstrap = require("__test__.bootstrap")
local harness = require("__test__.harness")

local t = harness.new("stl.nvim.buf")

bootstrap.with_global(t, "stl", {
  env = { IS_WIN = false },
})
bootstrap.with_global(t, "yoz", {
  path = {
    normalize = function()
      error("POSIX buffer paths must not use Windows-aware normalization")
    end,
  },
})

local buf = assert(loadfile("lua/stl/nvim/buf.lua"))()

t:test("POSIX lookup keeps literal backslashes distinct from separators", function()
  local prefix = vim.fn.tempname()
  local literal = prefix .. "/back\\slash.lua"
  local nested = prefix .. "/back/slash.lua"
  local literal_bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  local nested_bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  vim.api.nvim_buf_set_name(literal_bufnr, literal)
  vim.api.nvim_buf_set_name(nested_bufnr, nested)

  t.assert_eq(literal_bufnr, buf.locate_bufnr(literal), "literal backslash buffer")
  t.assert_eq(nested_bufnr, buf.locate_bufnr(nested), "nested path buffer")

  vim.api.nvim_buf_delete(literal_bufnr, { force = true })
  vim.api.nvim_buf_delete(nested_bufnr, { force = true })
end)

t:test("POSIX lookup keeps literal environment variables distinct from expanded paths", function()
  local literal = vim.fn.tempname() .. "/$HOME/file.lua"
  local expanded = vim.fs.normalize(literal)
  t.assert_true(literal ~= expanded, "fixture must exercise environment expansion")

  local literal_bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  local expanded_bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  vim.api.nvim_buf_set_name(literal_bufnr, literal)
  vim.api.nvim_buf_set_name(expanded_bufnr, expanded)

  t.assert_eq(literal_bufnr, buf.locate_bufnr(literal), "literal environment variable buffer")
  t.assert_eq(expanded_bufnr, buf.locate_bufnr(expanded), "expanded path buffer")

  vim.api.nvim_buf_delete(literal_bufnr, { force = true })
  vim.api.nvim_buf_delete(expanded_bufnr, { force = true })
end)

t:run()
