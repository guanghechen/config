---@diagnostic disable: unused-function, unused-local
local function b()
  local handle_find_files_cmd = io.popen("fd --hidden --type=file --color=never --follow > a.txt")
  if handle_find_files_cmd then
    handle_find_files_cmd:close()

    local pipe_grep_text_cmd = io.popen(
      "rg --iglob=a.txt --hidden --color=never --no-heading --no-filename --line-number --column --follow -- rc"
    )
    if pipe_grep_text_cmd then
      local file_list = pipe_grep_text_cmd:read("*a")
      pipe_grep_text_cmd:close()
      vim.notify(file_list)
    end
  end
end

local function c()
  ---@param ... string
  ---@return string
  local function xxx(...)
    local args = { ... }
    return table.concat(args, "#")
  end
  print(xxx("a", "b", "c"))
  print(("aa")[1])

  for i = 1, 3 do
    print(i)
  end
end

local function d()
  local path = require("guanghechen.util.path")
  print(path.is_absolute("/a/b/c"))
  print(vim.inspect(path.split("/a/b/c")))
  print(path.relative("/a/b/c", "/a/b/c/d/e.txt"))
  print(path.relative("/a/b/c", "/a/b/c/e.txt"))
  print(path.relative("/a/b/c", "/a/b/e.txt"))
  print(path.relative("/a/b/c", "e.txt"))
  print(path.relative("a/b/c", "/a/b/c/e.txt"))
  print(path.normalize("a/b/c"))
  print(path.normalize("a/b/..//c"))
  print(path.normalize("/../a/../../../b/d/e/..//c"))
end

local function e()
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
    music = {
      chinese = { 1, 2, 3 },
      english = { "a", "b", "c" },
    },
  })
  print(text)
end

local function f()
  local circular = require("guanghechen.queue.CircularQueue").new({ capacity = 3 })
  circular:enqueue("A")
  circular:enqueue("B")
  circular:enqueue("C")

  print("size:" .. vim.inspect(circular:size()))
  print("1:" .. vim.inspect(circular:at(1)))
  print("2:" .. vim.inspect(circular:at(2)))
  print("3:" .. vim.inspect(circular:at(3)))
  print("elements:" .. vim.inspect(circular:collect()))

  circular:enqueue("D")
  print("size:" .. vim.inspect(circular:size()))
  print("1:" .. vim.inspect(circular:at(1)))
  print("2:" .. vim.inspect(circular:at(2)))
  print("3:" .. vim.inspect(circular:at(3)))
  print("elements:" .. vim.inspect(circular:collect()))

  circular:dequeue_back()
  print("size:" .. vim.inspect(circular:size()))
  print("1:" .. vim.inspect(circular:at(1)))
  print("2:" .. vim.inspect(circular:at(2)))
  print("3:" .. vim.inspect(circular:at(3)))
  print("elements:" .. vim.inspect(circular:collect()))

  circular:enqueue("E")
  circular:enqueue("F")
  print("size:" .. vim.inspect(circular:size()))
  print("1:" .. vim.inspect(circular:at(1)))
  print("2:" .. vim.inspect(circular:at(2)))
  print("3:" .. vim.inspect(circular:at(3)))
  print("elements:" .. vim.inspect(circular:collect()))

  local result0 = {}
  for element in circular:iterator() do
    table.insert(result0, element)
  end
  print("result0:" .. vim.inspect(result0))

  local result1 = {}
  for element in circular:iterator_reverse() do
    table.insert(result1, element)
  end
  print("result1:" .. vim.inspect(result1))

  while circular:size() > 1 do
    circular:dequeue_back()
  end
  print("elements:" .. vim.inspect(circular:collect()))
end

local function g()
  local History = require("guanghechen.history.History")
  local history = History.new({
    name = "haha",
    max_count = 50,
    comparator = function(x, y)
      if x == y then
        return 0
      end
      return x < y and -1 or 1
    end,
  })

  history:push("A")
  history:push("B")
  history:print()

  history:back()
  history:print()

  history:push("C")
  history:print()

  history:back()
  history:back()
  history:back()
  history:back()
  history:print()
end

local function h()
  local guanghechen = require("guanghechen")
  vim.notify(vim.inspect(guanghechen.util.os.is_mac()))

  local fake_clipboard_filepath = guanghechen.util.tmux.get_tmux_env_value("ghc_use_fake_clipboard")
  vim.notify(vim.inspect(fake_clipboard_filepath))

  vim.notify(vim.inspect(guanghechen.util.clipboard.get_clipboard()))
end

h()
