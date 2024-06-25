local Replacer = require("kyokuya.replace.replacer")

ghc.context.theme.toggle_scheme({ mode = "darken", force = true })

---@type kyokuya.replace.Replacer
local replacer = Replacer.new({
  nsnr = 0,
  winnr = 0,
  reuse = true,
  data = {
    mode = "replace",
    cwd = fml.path.cwd(),
    flag_regex = true,
    flag_case_sensitive = true,
    search_pattern = "Hello, (world|世界)!(?:\\n|\\r\\n)H",
    replace_pattern = 'hello\nabc哈哈def\n - "$1"x',
    search_paths = "rust/",
    include_patterns = "*.txt, *.rs",
    exclude_patterns = ".git/, c.txt",
  },
})

local function run()
  local cur_winnr = vim.api.nvim_get_current_win()
  local cur_bufnr = vim.api.nvim_get_current_buf()
  local cur_win_width = vim.api.nvim_win_get_width(cur_winnr)

  if cur_win_width * 1.25 > vim.o.columns then
    vim.cmd("vsplit")
  end

  replacer:replace()
  vim.api.nvim_set_current_win(cur_winnr)
  vim.api.nvim_set_current_buf(cur_bufnr)
end

run()

---@param str     string
---@param left    integer
---@param right   integer
local function f(str, left, right)
  local sub = string.sub(str, left, right)
  vim.notify(vim.inspect({ sub = sub, width = vim.fn.strwidth(sub) }))
end
f("Hello, 世界!\nHello, 世界!\nHello, 世界!\nHello, 世界!\n", 0, 16)
