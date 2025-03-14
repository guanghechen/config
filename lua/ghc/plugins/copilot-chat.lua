local icons = require("eve.constant.icon")

local username = eve.env.USERNAME ---@type string

return {
  name = "copilot-chat.nvim",
  opts = {
    allow_insecure = false,
    auto_insert_mode = true,
    answer_header = " " .. icons.kind.Copilot .. " Copilot ",
    question_header = " " .. icons.os.current .. " " .. username .. " ",

    -- model = "claude-3.7-sonnet",
    model = "o3-mini",

    -- proxy = os.getenv("http_proxy"),
    window = {
      layout = "float",
      width = 124,
      height = 0.6,
      row = 4,
      border = "rounded",
      title = " Copilot Chat ",
      title_pos = "center",
      footer = nil,
    },
    prompts = {
      Translate = {
        description = "Translate English to Chinese and vice versa.",
        prompt = "Translate and refine these words, if it's mainly written in English, then translate and refine it to Chinese, otherwise translate and refine to English",
        system_prompt = [[
You are a helpful assistant.
You are highly proficient in both Chinese and English, and you are capable of translating or
converting them smartly, concisely, elegantly, and without losing the accuracy of the information.
Accuracy is extremely important, a point on which you steadfastly insist.
In the following dialogue, should my message contain at least one Chinese character,
please translate the whole sentence into English; otherwise, translate the whole sentence into Chinese."
]],
      },
      ExplainNvimStartuptime = {
        description = "Explain the nvim startuptime output.",
        prompt = [[
This is the output produced by `nvim --startuptime`.

Please explain each column of the output, and summary the top 20 records that consumed the most time,
make a beautiful table format and sort the picked 20 records by the ascending order at the clock field.

The time consumed on each record should be the delta of it's clock field and the previous record's clock field.
]],
      },
    },
  },
  dependencies = {
    "copilot.lua",
    "plenary.nvim",
  },
  keys = {
    {
      "<cr>",
      mode = "n",
      ft = "copilot-chat",
      desc = "Submit Prompt",
      remap = false,
    },
    {
      "<C-a>s",
      "<D-s>",
      "<M-s>",
      mode = { "i", "n", "v" },
      ft = "copilot-chat",
      desc = "Submit Prompt",
      remap = false,
    },
  },
}
