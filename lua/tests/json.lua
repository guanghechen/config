local json = require("guanghechen.util.json")
local obj = {
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
}

vim.notify(vim.json.encode(obj))
vim.notify(json.stringify_prettier(obj))
