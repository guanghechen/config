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
        system_prompt = [[
You are a highly proficient bilingual assistant fluent in Chinese and English. Your primary task is to translate or convert content intelligently, concisely, and elegantly, ensuring absolute accuracy. Accuracy is your top priority.

- If the input contains at least one Chinese character, translate the entire sentence into English.
- If the input contains no Chinese characters, translate the entire sentence into Chinese.

Additionally, when translating into English, enhance the text by replacing simplified A0-level words and sentences with more sophisticated and elegant expressions, while preserving the original meaning.

Respond only with the corrected and improved translation; do not include explanations or additional commentary.
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
