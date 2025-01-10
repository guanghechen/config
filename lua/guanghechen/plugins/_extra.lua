local env = require("eve.builtin.env")

return {
  {
    "yetone/avante.nvim",
    event = "VeryLazy",
    lazy = false,
    version = false, -- set this to "*" if you want to always pull the latest change, false to update on release
    opts = {
      provider = "copilot",
      auto_suggestions_provider = "copilot",
    },
    build = env.IS_WIN and "pwsh -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource false" or "make",
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
  },
}
