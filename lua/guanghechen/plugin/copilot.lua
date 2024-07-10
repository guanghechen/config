return {
  "zbirenbaum/copilot.lua",
  cmd = "Copilot",
  build = ":Copilot auth signin",
  event = { "InsertEnter" },
  cond = function()
    return ghc.context.session.flight_copilot:snapshot()
  end,
  opts = {
    suggestion = { enabled = false },
    panel = { enabled = false },
    filetypes = {
      markdown = true,
      help = true,
    },
  },
}
