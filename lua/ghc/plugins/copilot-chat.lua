local username = eve.env.USERNAME ---@type string

return {
  name = "copilot-chat.nvim",
  cmd = {
    "CopilotChatTranslate",
  },
  opts = {
    allow_insecure = false,
    auto_insert_mode = true,
    answer_header = " " .. eve.icon.kind.Copilot .. " Copilot ",
    question_header = " " .. eve.icon.os.current .. " " .. username .. " ",

    model = "o4-mini",

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
        prompt = "Translate and refine the given content.",
        system_prompt = "You are a highly proficient bilingual assistant in Chinese and English. You translate or convert content intelligently, concisely, and elegantly while ensuring absolute accuracy. Accuracy is your top priority. If my message contains at least one Chinese character, translate the entire sentence into English; otherwise, translate the entire sentence into Chinese.",
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
