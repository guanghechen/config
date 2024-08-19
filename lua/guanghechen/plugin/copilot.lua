return {
  url = "https://github.com/guanghechen/mirror.git",
  branch = "nvim@copilot.lua",
  name = "copilot.lua",
  main = "copilot",
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
