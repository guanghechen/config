eve.debug.log({
  a = vim.o.columns,
  b = #" ",
  c = vim.api.nvim_strwidth(" "),
  d = #eve.nvimbar.txt(" ", "Number"),
  e = vim.api.nvim_strwidth(eve.nvimbar.txt(" ", "Comment")),
  f = vim.api.nvim_win_get_width(0),
})

local winnrs = vim.api.nvim_tabpage_list_wins(0)
eve.debug.log("winnrs:", winnrs)
eve.debug.log({
  x1 = vim.api.nvim_win_get_width(winnrs[1]),
  x2 = vim.api.nvim_win_get_width(winnrs[2]),
})
