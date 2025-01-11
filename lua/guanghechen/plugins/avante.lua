local env = require("eve.builtin.env")
local state = require("eve.state")

local configs = {
  basic = {
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
  providers = {
    copilot = {
      provider = "copilot",
      auto_suggestions_provider = "copilot",
    },
    deepseek = {
      provider = "openai",
      auto_suggestions_provider = "openai",
      openai = {
        endpoint = "https://api.deepseek.com/v1",
        model = "deepseek-chat",
        timeout = 30000,
        temperature = 0,
        max_tokens = 4096,
        ["local"] = false,
      },
    },
  },
}

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
  config = function()
    local last_ai_provider = nil ---@type eve.e.AiProvider|nil

    ---@return nil
    local function setup()
      local ai_provider = state.flight.ai_provider:snapshot() ---@type eve.e.AiProvider
      if ai_provider ~= last_ai_provider then
        last_ai_provider = ai_provider
        local opts =
          vim.tbl_deep_extend("force", {}, configs.basic, configs.providers[ai_provider] or configs.providers.copilot)
        require("avante").setup(opts)
      end
    end

    setup()
  end,
}
