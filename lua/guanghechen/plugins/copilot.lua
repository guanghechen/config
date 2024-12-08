return {
  name = "copilot.lua",
  cmd = "Copilot",
  build = ":Copilot auth",
  event = { "InsertEnter" },
  opts = {
    suggestion = {
      enabled = false,
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
