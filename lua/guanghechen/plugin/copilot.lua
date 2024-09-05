return {
  name = "copilot.lua",
  cmd = "Copilot",
  build = function()
    vim.defer_fn(function()
      vim.cmd("Copilot auth signin")
    end, 1000)
  end,
  event = { "InsertEnter" },
  cond = function()
    return ghc.context.session.flight_copilot:snapshot()
  end,
  opts = {
    suggestion = { enabled = false },
    panel = { enabled = false },
    filetypes = {
      help = true,
      lua = true,
      markdown = true,
      typescript = true,
      typescriptreact = true,
      javascript = true,
      javascriptreact = true,
      text = true,
      ["*"] = false,
    },
  },
}
