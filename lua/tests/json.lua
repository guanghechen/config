local obj = {
  name = "wulala",
  favorites = {
    "apple",
    "/a/a/b/c/d/e",
    "banana\n",
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
vim.notify(vim.fn.json_encode(obj))
vim.notify(fml.core.json.stringify_prettier(obj))

vim.notify(vim.json.encode("banana\nahaha\tdfe"))
vim.notify(vim.fn.json_encode("banana\nahaha\tdfe"))
vim.notify(fml.core.json.stringify_prettier("banana\nahaha\tdfe"))
