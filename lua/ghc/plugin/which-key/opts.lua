local opts = {
  plugins = { spelling = true },
  defaults = {
    mode = { "n", "v" },
    ["g"] = { name = "+goto" },
    ["gs"] = { name = "+surround" },
    ["z"] = { name = "+fold" },
    ["]"] = { name = "+next" },
    ["["] = { name = "+prev" },
    ["<leader>b"] = { name = "+buffer" },
    ["<leader>c"] = { name = "+code" },
    ["<leader>e"] = { name = "+explorer" },
    ["<leader>f"] = { name = "+find/file" },
    ["<leader>g"] = { name = "+find/git" },
    ["<leader>gh"] = { name = "git action" },
    ["<leader>q"] = { name = "+quit/session" },
    ["<leader>s"] = { name = "+search" },
    ["<leader>sn"] = { name = "+noice" },
    ["<leader>t"] = { name = "+tab/terminal" },
    ["<leader>u"] = { name = "+ui" },
    ["<leader>w"] = { name = "+window" },
    ["<leader>x"] = { name = "+diagnostics/quickfix" },
  },
}

return opts
