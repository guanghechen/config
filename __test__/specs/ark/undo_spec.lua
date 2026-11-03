local harness = require("__test__.support.harness")
local t = harness.new()

require("ark.keymap")

-- Types the text in Insert mode as typed keys, leaves it, then undoes until nothing is left.
---@param text                          string
---@return string[][]
local function undo_states(text)
  local showmode = vim.o.showmode ---@type boolean
  vim.o.showmode = false
  local previous = vim.api.nvim_get_current_buf() ---@type integer
  local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  t:defer(function()
    vim.o.showmode = showmode
    vim.api.nvim_set_current_buf(previous)
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)
  vim.api.nvim_set_current_buf(bufnr)
  vim.api.nvim_feedkeys(vim.keycode("i" .. text .. "<Esc>"), "tx", false)

  local states = { vim.api.nvim_buf_get_lines(bufnr, 0, -1, false) } ---@type string[][]
  while true do
    local seq = vim.fn.undotree().seq_cur ---@type integer
    vim.cmd("silent! undo")
    if vim.fn.undotree().seq_cur == seq then
      return states
    end
    states[#states + 1] = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  end
end

t:test("ASCII punctuation ends an undo step", function()
  t.assert_same({
    { "one,two.three;four" },
    { "one,two.three;" },
    { "one,two." },
    { "one," },
    { "" },
  }, undo_states("one,two.three;four"))
end)

t:test("full-width punctuation from an input method ends an undo step too", function()
  t.assert_same({
    { "你好，世界。天气不错；注意：真好！对吗？再见" },
    { "你好，世界。天气不错；注意：真好！对吗？" },
    { "你好，世界。天气不错；注意：真好！" },
    { "你好，世界。天气不错；注意：" },
    { "你好，世界。天气不错；" },
    { "你好，世界。" },
    { "你好，" },
    { "" },
  }, undo_states("你好，世界。天气不错；注意：真好！对吗？再见"))
end)

t:run()
