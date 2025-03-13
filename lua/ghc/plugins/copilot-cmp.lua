local fn = require("eve.builtin.fn")

return {
  name = "copilot-cmp",
  opts = {},
  config = function(_, opts)
    local copilot_cmp = require("copilot_cmp")
    copilot_cmp.setup(opts)

    -- attach cmp source whenever copilot attaches
    -- fixes lazy-loading issues with the copilot cmp source
    vim.api.nvim_create_autocmd("LspAttach", {
      group = eve.std.nvim.augroup("copilot_cmp_on_lsp_attach"),
      callback = function(args)
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        if client and client.name == "copilot" then
          copilot_cmp._on_insert_enter({})
        end
      end,
    })
  end,
  dependencies = {
    "copilot.lua",
  },
}
