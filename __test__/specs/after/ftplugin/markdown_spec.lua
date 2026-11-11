require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new()

-- Filetype plugins under this checkout's after/ run after Neovim's own, as they do from a user's runtimepath.
vim.opt.runtimepath:append(vim.fs.joinpath(vim.fn.getcwd(), "after"))
vim.cmd("filetype plugin on")

---The lines of a new Markdown buffer after typing `keys`.
---@param keys                          string
---@return string[]
local function typed(keys)
  t:buffer(nil, { listed = true, current = true })
  vim.api.nvim_set_option_value("filetype", "markdown", { buf = 0 })
  vim.api.nvim_feedkeys(vim.keycode(keys), "xt", false)
  return vim.api.nvim_buf_get_lines(0, 0, -1, false)
end

t:test("markdown continues a list item or a quote on <CR> and o", function()
  t.assert_same({ "- one", "- two" }, typed("i- one<CR>two<Esc>"), "dash on <CR>")
  t.assert_same({ "* one", "* two" }, typed("i* one<CR>two<Esc>"), "star on <CR>")
  t.assert_same({ "1. one", "1. two" }, typed("i1. one<CR>two<Esc>"), "number on <CR>")
  t.assert_same({ "> one", "> two" }, typed("i> one<CR>two<Esc>"), "quote on <CR>")
  t.assert_same({ "- one", "- two" }, typed("i- one<Esc>otwo<Esc>"), "dash on o")
  t.assert_same({ "plain", "two" }, typed("iplain<CR>two<Esc>"), "no leader after plain text")
end)

t:run()
