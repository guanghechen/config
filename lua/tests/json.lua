local json = require("guanghechen.util.json")
local text = json.stringify_prettier({
  name = "wulala",
  favorites = {
    "apple",
    "banana",
    {
      name = "cat",
      age = 13,
    },
  },
  haha = {},
  music = {
    chinese = { 1, 2, 3 },
    english = { "a", "b", "c" },
  },
})

vim.notify(text or "")