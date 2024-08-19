local util_lsp = require("guanghechen.util.lsp")

return {
  url = "https://github.com/guanghechen/mirror.git",
  branch = "nvim@copilot-cmp",
  name = "copilot-cmp",
  main = "copilot-cmp",
  opts = {},
  config = function(_, opts)
    local copilot_cmp = require("copilot_cmp")
    copilot_cmp.setup(opts)
    -- attach cmp source whenever copilot attaches
    -- fixes lazy-loading issues with the copilot cmp source
    util_lsp.on_attach(function(client)
      if client.name == "copilot" then
        copilot_cmp._on_insert_enter({})
      end
    end)
  end,
  dependencies = {
    "zbirenbaum/copilot.lua",
  },
}
