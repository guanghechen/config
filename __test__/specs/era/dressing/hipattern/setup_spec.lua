local harness = require("__test__.support.harness")

local t = harness.new()

t:test("dressing enables every existing visible buffer", function()
  local first = vim.api.nvim_get_current_buf() ---@type integer
  local first_lines = vim.api.nvim_buf_get_lines(first, 0, -1, false) ---@type string[]
  local first_filetype = vim.api.nvim_get_option_value("filetype", { buf = first }) ---@type string
  local first_modified = vim.api.nvim_get_option_value("modified", { buf = first }) ---@type boolean
  t:defer(function()
    vim.api.nvim_buf_set_lines(first, 0, -1, false, first_lines)
    vim.api.nvim_set_option_value("filetype", first_filetype, { buf = first })
    vim.api.nvim_set_option_value("modified", first_modified, { buf = first })
  end)
  vim.api.nvim_buf_set_lines(first, 0, -1, false, { "TODO" })
  vim.api.nvim_set_option_value("filetype", "lua", { buf = first })

  vim.cmd("vertical new")
  local second = vim.api.nvim_get_current_buf() ---@type integer
  t:defer(function()
    vim.api.nvim_buf_delete(second, { force = true })
  end)
  vim.api.nvim_buf_set_lines(second, 0, -1, false, { "ERROR" })
  vim.api.nvim_set_option_value("filetype", "lua", { buf = second })

  local Hipattern = require("era.dressing.hipattern")
  Hipattern.dressing()

  t.wait_until(function()
    return Hipattern.is_enabled(first)
      and Hipattern.is_enabled(second)
      and #vim.api.nvim_buf_get_extmarks(first, -1, 0, -1, {}) == 1
      and #vim.api.nvim_buf_get_extmarks(second, -1, 0, -1, {}) == 1
  end, 5000, "visible buffers enabled")
end)

t:run()
