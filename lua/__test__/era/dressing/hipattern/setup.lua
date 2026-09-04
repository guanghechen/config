--- Run with: nvim -l lua/__test__/era/dressing/hipattern/setup.lua

local harness = require("__test__.harness")

local t = harness.new("era.dressing.hipattern.setup")

t:test("dressing enables every existing visible buffer", function()
  local first = vim.api.nvim_get_current_buf() ---@type integer
  vim.api.nvim_buf_set_lines(first, 0, -1, false, { "TODO" })
  vim.api.nvim_set_option_value("filetype", "lua", { buf = first })

  vim.cmd("vertical new")
  local second = vim.api.nvim_get_current_buf() ---@type integer
  vim.api.nvim_buf_set_lines(second, 0, -1, false, { "ERROR" })
  vim.api.nvim_set_option_value("filetype", "lua", { buf = second })

  local Hipattern = require("era.dressing.hipattern")
  Hipattern.dressing()

  t.wait_until(function()
    return Hipattern.is_enabled(first)
      and Hipattern.is_enabled(second)
      and #vim.api.nvim_buf_get_extmarks(first, -1, 0, -1, {}) == 1
      and #vim.api.nvim_buf_get_extmarks(second, -1, 0, -1, {}) == 1
  end, 1000, "visible buffers enabled")
end)

t:run()
