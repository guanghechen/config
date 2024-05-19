local util_path = require("guanghechen.util.path")

return {
  "tomasky/bookmarks.nvim",
  config = function()
    require("bookmarks").setup({
      save_file = util_path.locate_session_filepath({ filename = "bookmark.vim" }), -- bookmarks save file path
      keywords = {
        ["@t"] = "  ", -- mark annotation startswith @t ,signs this icon as `Todo`
        ["@w"] = "⚠️ ", -- mark annotation startswith @w ,signs this icon as `Warn`
        ["@f"] = "⛏ ", -- mark annotation startswith @f ,signs this icon as `Fix`
        ["@n"] = "󰠮 ", -- mark annotation startswith @n ,signs this icon as `Note`
      },
      on_attach = function() end,
    })
    require("telescope").load_extension("bookmarks")
  end,
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-telescope/telescope.nvim",
  },
}
