-- Active indent guide and indent text objects. When you're browsing
-- code, this highlights the current level of indentation, and animates
-- the highlighting.
return {
  name = "mini.indentscope",
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
        fml.constant.FT_NEOTREE,
        fml.constant.FT_SEARCH_INPUT,
        fml.constant.FT_SEARCH_MAIN,
        fml.constant.FT_SEARCH_PREVIEW,
        fml.constant.FT_SELECT_INPUT,
        fml.constant.FT_SELECT_MAIN,
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
