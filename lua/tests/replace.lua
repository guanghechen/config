local Replacer = ghc.command.replace.Replacer

ghc.context.shared.toggle_scheme({ mode = "darken", force = true })

---@type ghc.types.command.replace.IStateData
local test_data = {
  mode = "replace",
  cwd = fml.path.cwd(),
  flag_regex = true,
  flag_case_sensitive = true,
  search_pattern = "Hello, (world|世界)!(?:\\n|\\r\\n)H",
  replace_pattern = 'hello\nabc哈哈def\n - "$1"x',
  search_paths = "rust/",
  include_patterns = "*.txt, *.rs",
  exclude_patterns = ".git/, c.txt",
}

---@type ghc.types.command.replace.IStateData
local context_data = {
  mode = ghc.context.search.mode:get_snapshot(),
  cwd = ghc.context.search.cwd:get_snapshot(),
  flag_regex = ghc.context.search.flag_regex:get_snapshot(),
  flag_case_sensitive = ghc.context.search.flag_case_sensitive:get_snapshot(),
  search_pattern = ghc.context.search.search_pattern:get_snapshot(),
  replace_pattern = ghc.context.search.replace_pattern:get_snapshot(),
  search_paths = ghc.context.search.search_paths:get_snapshot(),
  include_patterns = ghc.context.search.include_patterns:get_snapshot(),
  exclude_patterns = ghc.context.search.exclude_patterns:get_snapshot(),
}

---vim.notify("test_data:\n" .. vim.inspect(test_data))
---vim.notify("context_data:\n" .. vim.inspect(context_data))

---@type ghc.command.replace.Replacer
local replacer = Replacer.new({
  winnr = 0,
  reuse = true,
  data = test_data,
})

local function run()
  local cur_winnr = vim.api.nvim_get_current_win()
  local cur_bufnr = vim.api.nvim_get_current_buf()
  local cur_win_width = vim.api.nvim_win_get_width(cur_winnr)

  if cur_win_width * 1.25 > vim.o.columns then
    vim.cmd("vsplit")
  end

  replacer:open()
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
