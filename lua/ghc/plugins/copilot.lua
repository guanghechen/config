return {
  name = "copilot.lua",
  cmd = "Copilot",
  build = ":Copilot auth",
  event = { "BufReadPost" },
  opts = {
    suggestion = {
      enabled = false,
      auto_trigger = true,
      hide_during_completion = true,
      keymap = {
        accept = false,
      },
    },
    panel = {
      enabled = false,
    },
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
