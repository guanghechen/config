local path = require("ghc.core.util.path")

local function config()
  require("bookmarks").setup({
    save_file = path.gen_session_related_filepath({ group = "bookmark" }), -- bookmarks save file path
    keywords = {
      ["@t"] = "  ", -- mark annotation startswith @t ,signs this icon as `Todo`
      ["@w"] = "⚠️ ", -- mark annotation startswith @w ,signs this icon as `Warn`
      ["@f"] = "⛏ ", -- mark annotation startswith @f ,signs this icon as `Fix`
      ["@n"] = "󰠮 ", -- mark annotation startswith @n ,signs this icon as `Note`
    },
    on_attach = function() end,
  })
  require("telescope").load_extension("bookmarks")
end

return config
