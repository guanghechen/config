--- Run with: nvim -l __test__/run.lua __test__/specs/era/dressing/commentstring_spec.lua
---@diagnostic disable: undefined-global

local harness = require("__test__.support.harness")

local t = harness.new("era.dressing.commentstring")
local module_name = "era.dressing.commentstring" ---@type string

---@param line                          string
---@param filetype                      string
---@param callback                      fun(): nil
---@return nil
local function with_buffer(line, filetype, callback)
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local previous_bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  vim.api.nvim_win_set_buf(winnr, bufnr)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { line })
  vim.api.nvim_set_option_value("filetype", filetype, { buf = bufnr })

  local ok, err = pcall(callback)
  if vim.api.nvim_buf_is_valid(previous_bufnr) then
    vim.api.nvim_win_set_buf(winnr, previous_bufnr)
  end
  if vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end
  if not ok then
    error(err, 0)
  end
end

---@param native                        fun(filetype: string, option: string): boolean|integer|string
---@param callback                      fun(module: era.dressing.commentstring): nil
---@return nil
local function with_module(native, callback)
  t:patch_table(vim.filetype, "get_option", native)
  t:patch_table(package.loaded, module_name, nil)
  callback(require(module_name))
end

---@param default_comments              string
---@return nil
local function patch_option_info(default_comments)
  t:patch_table(vim.api, "nvim_get_option_info2", function(option)
    t.assert_eq("comments", option, "option info name")
    return { default = default_comments }
  end)
end

t:test("dressing delegates options other than commentstring", function()
  local calls = {} ---@type string[]
  with_module(function(filetype, option)
    calls[#calls + 1] = filetype .. ":" .. option
    return "native"
  end, function(Commentstring)
    Commentstring.dressing()

    t.assert_eq("native", vim.filetype.get_option("lua", "comments"), "delegated option")
    t.assert_eq("lua:comments", calls[1], "delegated call")
  end)
end)

t:test("dressing does not overwrite a later option wrapper", function()
  with_module(function()
    return ""
  end, function(Commentstring)
    Commentstring.dressing()
    local successor = function()
      return "successor"
    end
    vim.filetype.get_option = successor

    Commentstring.dressing()

    t.assert_eq(successor, vim.filetype.get_option, "successor wrapper")
  end)
end)

t:test("language map supplies just comments", function()
  local default_comments = "s1:/*,mb:*,ex:*/" ---@type string
  patch_option_info(default_comments)
  with_module(function(_, option)
    return option == "comments" and default_comments or ""
  end, function(Commentstring)
    with_buffer("recipe", "just", function()
      Commentstring.dressing()
      t.assert_eq("# %s", vim.filetype.get_option("just", "commentstring"), "just commentstring")
    end)
  end)
end)

t:test("tsx uses the nearest node-specific commentstring", function()
  local default_comments = "s1:/*,mb:*,ex:*/" ---@type string
  patch_option_info(default_comments)
  local node = {} ---@type table
  function node:type()
    return "jsx_element"
  end
  function node:parent()
    return nil
  end
  t:patch_table(vim.treesitter, "get_node", function()
    return node
  end)

  with_module(function(_, option)
    return option == "comments" and default_comments or ""
  end, function(Commentstring)
    with_buffer("  <Component />", "typescriptreact", function()
      Commentstring.dressing()
      t.assert_eq("{/* %s */}", vim.filetype.get_option("tsx", "commentstring"), "tsx commentstring")
    end)
  end)
end)

t:test("uncomment preserves the existing block spacing", function()
  local default_comments = "s1:/*,mb:*,ex:*/" ---@type string
  patch_option_info(default_comments)
  with_module(function(_, option)
    return option == "comments" and default_comments or ""
  end, function(Commentstring)
    with_buffer("/*  value   */", "rust", function()
      Commentstring.dressing()
      t.assert_eq("/*  %s   */", vim.filetype.get_option("rust", "commentstring"), "block spacing")
    end)
  end)
end)

t:test("comments option supplies an additional line pattern", function()
  patch_option_info("")
  with_module(function(_, option)
    return option == "comments" and ":##" or ""
  end, function(Commentstring)
    with_buffer("value", "unknown", function()
      Commentstring.dressing()
      t.assert_eq("## %s", vim.filetype.get_option("unknown", "commentstring"), "comments fallback")
    end)
  end)
end)

t:run()
