-- Active indent guide and indent text objects. When you're browsing
-- code, this highlights the current level of indentation, and animates
-- the highlighting.
return {
  url = "https://github.com/guanghechen/mirror.git",
  branch = "nvim@mini.indentscope",
  name = "mini.indentscope",
  main = "mini.indentscope",
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
        fml.constant.FT_SEARCH_INPUT,
        fml.constant.FT_SEARCH_MAIN,
        fml.constant.FT_TERM,
        "help",
        "alpha",
        "dashboard",
        "neo-tree",
        "Trouble",
        "trouble",
        "lazy",
        "mason",
        "notify",
      },
      callback = function()
        vim.b.miniindentscope_disable = true
      end,
    })
  end,
}
