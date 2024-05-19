local function b()
  local handle_find_files_cmd = io.popen("fd --hidden --type=file --color=never --follow > a.txt")
  if handle_find_files_cmd then
    handle_find_files_cmd:close()

    local pipe_grep_text_cmd = io.popen("rg --iglob=a.txt --hidden --color=never --no-heading --no-filename --line-number --column --follow -- rc")
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

e()
