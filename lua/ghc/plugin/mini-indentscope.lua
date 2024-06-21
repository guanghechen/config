-- Active indent guide and indent text objects. When you're browsing
-- code, this highlights the current level of indentation, and animates
-- the highlighting.
return {
  "echasnovski/mini.indentscope",
  version = false, -- wait till new 0.7.0 release to put it back on semver
  event = { "VeryLazy" },
  opts = {
    symbol = "╎",
    options = {
      try_as_border = true,
    },
  },
  init = function()
    vim.api.nvim_create_autocmd("FileType", {
      pattern = {
        "help",
        "alpha",
        "dashboard",
        "neo-tree",
        "Trouble",
        "trouble",
        "lazy",
        "mason",
        "notify",
        "lazyterm",
        "spectre_pane",
        "term",
        "kyokuya-replace",
      },
      callback = function()
        vim.b.miniindentscope_disable = true
      end,
    })
  end,
}
