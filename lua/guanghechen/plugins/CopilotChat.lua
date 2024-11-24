---@class guanghechen.plugins.copilot_chat.prompt_actions.IItem
---@field public prompt                 ?string
---@field public callback               ?fun(): nil

local username = os.getenv("USER") or os.getenv("USERNAME") or "unknown" ---@type string

return {
  name = "CopilotChat.nvim",
  cmd = "CopilotChat",
  init = function()
    vim.api.nvim_create_autocmd("BufEnter", {
      pattern = "copilot-chat",
      callback = function()
        vim.opt_local.relativenumber = false
        vim.opt_local.number = false
      end,
    })
  end,
  build = function()
    pcall(function()
      vim.cmd("make tiktoken")
    end)
  end,
  opts = {
    auto_insert_mode = true,
    question_header = eve.icons.os.current .. " " .. username .. " ",
    answer_header = eve.icons.kind.Copilot .. " Copilot ",
    -- proxy = os.getenv("http_proxy"),
    window = {
      width = 0.4,
    },
    prompts = {
      Translate = {
        prompt = "Translate and refine these words, if it's mainly written in English, then translate and refine it to Chinese, otherwise translate and refine to English",
        system_prompt = [[You are a helpful assistant.
You are highly proficient in both Chinese and English, and you are capable of translating or
converting them smartly, concisely, elegantly, and without losing the accuracy of the information.
Accuracy is extremely important, a point on which you steadfastly insist.
In the following dialogue, should my message contain at least one Chinese character,
please translate the whole sentence into English; otherwise, translate the whole sentence into Chinese."
]],
        description = "Translate English to Chinese and vice versa",
      },
    },
  },
  dependencies = {
    "copilot.lua",
    "plenary.nvim",
  },
  keys = {
    {
      "<M-s>",
      "<C-a>s",
      "<CR>",
      ft = "copilot-chat",
      desc = "Submit Prompt",
      remap = false,
    },
  },
}
