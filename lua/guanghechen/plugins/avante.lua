local env = require("eve.builtin.env")
local Subscriber = require("eve.collection.subscriber")
local state = require("eve.state")

local AI_PROVIDER_MAP = {
  aoai = "azure",
  copilot = "copilot",
  deepseek = "deepseek",
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
  opts = function()
    local ai_provider = state.flight.ai_provider:snapshot() ---@type eve.e.AiProvider
    local provider_name = AI_PROVIDER_MAP[ai_provider] or "copilot" ---@type string
    return {
      azure = {
        endpoint = vim.env.AZURE_OPENAI_ENDPOINT,
        deployment = "gpt-4o",
        model = "gpt-4o",
        api_version = "2024-08-01-preview",
      },
      vendors = {
        deepseek = {
          __inherited_from = "openai",
          api_key_name = "DEEPSEEK_API_KEY",
          endpoint = "https://api.deepseek.com",
          model = "deepseek-coder",
        },
      },

      provider = provider_name,
      auto_suggestions_provider = "copilot",

      ------------------------------------------------------------------------------------------------

      mappings = {
        ask = "<leader>aa",
        edit = "<leader>ae",
        refresh = "<leader>ar",

        sidebar = {
          close = { "q" },
        },
        submit = {
          normal = "<CR>",
          -- insert = { "<C-s>", "<M-s>", "<C-a>s" },
          insert = "<C-s>",
        },
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
    }
  end,
  config = function(_, opts)
    package.loaded["dressing.nvim"] = {}

    require("avante").setup(opts)
    state.flight.ai_provider:subscribe(
      Subscriber.new({
        on_next = function(ai_provider)
          local provider_name = AI_PROVIDER_MAP[ai_provider] or "copilot"
          vim.cmd("AvanteSwitchProvider " .. provider_name)
        end,
      }),
      true
    )

    -- local FileSelector = require("avante.file_selector")
    -- function FileSelector:native_ui(handler)
    --   local filepaths = self:get_filepaths()
    --
    --   vim.ui.select(filepaths, {
    --     prompt = "(Avante) Add a file:",
    --     format_item = function(item)
    --       return item
    --     end,
    --   }, function(item)
    --     if item then
    --       handler({ item })
    --     else
    --       handler(nil)
    --     end
    --   end)
    -- end
  end,
}
