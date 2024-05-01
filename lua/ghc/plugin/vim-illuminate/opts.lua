local opts = {
  delay = 200,
  filetypes_denylist = {
    "lazyterm",
    "neo-tree",
    "noice",
    "notify",
    "quickfix",
    "term",
  },
  large_file_cutoff = 2000,
  large_file_overrides = {
    providers = { "lsp" },
  },
}

return opts
