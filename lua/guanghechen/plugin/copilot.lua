local context_session = require("guanghechen.core.context.session")

return {
  "zbirenbaum/copilot.lua",
  cmd = "Copilot",
  build = ":Copilot auth signin",
  event = { "InsertEnter" },
  cond = function()
    return context_session.flight_copilot:get_snapshot()
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
