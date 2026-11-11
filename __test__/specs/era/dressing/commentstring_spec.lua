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

t:test("language map supplies just comments", function()
  local default_comments = "s1:/*,mb:*,ex:*/" ---@type string
  patch_option_info(default_comments)
  with_module(function(_, option)
    return option == "comments" and default_comments or ""
  end, function(Commentstring)
    t:buffer({ "recipe" }, { filetype = "just", current = true })
    Commentstring.dressing()
    t.assert_eq("# %s", vim.filetype.get_option("just", "commentstring"), "just commentstring")
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
    t:buffer({ "  <Component />" }, { filetype = "typescriptreact", current = true })
    Commentstring.dressing()
    t.assert_eq("{/* %s */}", vim.filetype.get_option("tsx", "commentstring"), "tsx commentstring")
  end)
end)

t:test("uncomment preserves the existing block spacing", function()
  local default_comments = "s1:/*,mb:*,ex:*/" ---@type string
  patch_option_info(default_comments)
  with_module(function(_, option)
    return option == "comments" and default_comments or ""
  end, function(Commentstring)
    t:buffer({ "/*  value   */" }, { filetype = "rust", current = true })
    Commentstring.dressing()
    t.assert_eq("/*  %s   */", vim.filetype.get_option("rust", "commentstring"), "block spacing")
  end)
end)

t:test("comments option supplies an additional line pattern", function()
  patch_option_info("")
  with_module(function(_, option)
    return option == "comments" and ":##" or ""
  end, function(Commentstring)
    t:buffer({ "value" }, { filetype = "unknown", current = true })
    Commentstring.dressing()
    t.assert_eq("## %s", vim.filetype.get_option("unknown", "commentstring"), "comments fallback")
  end)
end)

t:run()
