local harness = require("__test__.support.harness")

local t = harness.new()
local module_name = "era.dressing.commentstring" ---@type string

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

local block_comments = "s1:/*,mb:*,ex:*/" ---@type string

-- The commentstring a buffer of `filetype` showing `lines` gets for `language`, from a native `comments` option.
for _, case in ipairs({
  {
    name = "language map supplies just comments",
    default_comments = block_comments,
    comments = block_comments,
    lines = { "recipe" },
    filetype = "just",
    language = "just",
    expected = "# %s",
  },
  {
    name = "tsx uses the nearest node-specific commentstring",
    default_comments = block_comments,
    comments = block_comments,
    node_type = "jsx_element",
    lines = { "  <Component />" },
    filetype = "typescriptreact",
    language = "tsx",
    expected = "{/* %s */}",
  },
  {
    name = "uncomment preserves the existing block spacing",
    default_comments = block_comments,
    comments = block_comments,
    lines = { "/*  value   */" },
    filetype = "rust",
    language = "rust",
    expected = "/*  %s   */",
  },
  {
    name = "comments option supplies an additional line pattern",
    default_comments = "",
    comments = ":##",
    lines = { "value" },
    filetype = "unknown",
    language = "unknown",
    expected = "## %s",
  },
}) do
  t:test(case.name, function()
    patch_option_info(case.default_comments)
    if case.node_type ~= nil then
      local node = {} ---@type table
      function node:type()
        return case.node_type
      end
      function node:parent()
        return nil
      end
      t:patch_table(vim.treesitter, "get_node", function()
        return node
      end)
    end

    with_module(function(_, option)
      return option == "comments" and case.comments or ""
    end, function(Commentstring)
      t:buffer(case.lines, { filetype = case.filetype, current = true })
      Commentstring.dressing()
      t.assert_eq(case.expected, vim.filetype.get_option(case.language, "commentstring"), "commentstring")
    end)
  end)
end

t:run()
