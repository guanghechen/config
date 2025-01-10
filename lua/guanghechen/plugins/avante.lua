local env = require("eve.builtin.env")

return {
  "avante.nvim",
  build = env.IS_WIN and "pwsh -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource false" or "make",
  cmd = {
    "AvanteAsk",
    "AvanteBuild",
    "AvanteChat",
    "AvanteClear",
    "AvanteEdit",
    "AvanteFocus",
    "AvanteRefresh",
    "AvanteSwitchProvider",
    "AvanteToggle",
  },
  dependencies = {
    "dressing.nvim",
    "plenary.nvim",
    "nui.nvim",
    "nvim-cmp",
    "mini.icons",
    "copilot.lua",
    "img-clip.nvim",
    "render-markdown.nvim",
  },
  opts = {
    provider = "copilot",
    auto_suggestions_provider = "copilot",

    ---

    mappings = {
      ask = "<leader>aa",
      edit = "<leader>ae",
      refresh = "<leader>ar",

      suggestion = {
        accept = "<c-enter>",
        next = "<c-j>",
        prev = "<c-k>",
        dismiss = "<esc>",
      },
    },
    windows = {
      ask = {
        floating = false,
        start_insert = false,
        border = "rounded",
        focus_on_apply = "theirs",
      },
    },
  },
}
