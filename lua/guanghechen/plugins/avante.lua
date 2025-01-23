local env = require("eve.builtin.env")
local state = require("eve.state")

local configs = {
  basic = {
    auto_suggestions_provider = "copilot",
    mappings = {
      ask = "<leader>aa",
      edit = "<leader>ae",
      refresh = "<leader>ar",

      suggestion = {
        accept = "<C-cr>",
        next = "<C-j>",
        prev = "<C-k>",
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
    aoai = {
      provider = "azure",
      azure = {
        endpoint = vim.env.AZURE_OPENAI_ENDPOINT,
        deployment = "gpt-4o",
        model = "gpt-4o",
        api_version = "2024-08-01-preview",
      },
    },
    copilot = {
      provider = "copilot",
    },
    deepseek = {
      provider = "deepseek",
      vendors = {
        deepseek = {
          __inherited_from = "openai",
          api_key_name = "DEEPSEEK_API_KEY",
          endpoint = "https://api.deepseek.com",
          model = "deepseek-coder",
        },
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
    "plenary.nvim",
    "nui.nvim",
    "nvim-cmp",
    "mini.icons",
    "copilot.lua",
    "render-markdown.nvim",
  },
  config = function()
    package.loaded["dressing.nvim"] = {}

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
