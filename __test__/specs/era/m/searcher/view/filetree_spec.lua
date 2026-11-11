require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new()
local fs = require("__test__.support.fs")
local treeview = require("__test__.support.treeview")
local Paths = require("era.view.result_paths")
local Files = require("era.m.searcher.view.filetree")

---@param count                         integer
---@return era.m.searcher.FiletreeView
---@return string
local function fixture(count)
  local tree = Files.new({ name = "search locations", tree = Paths.new() })
  t:defer(function()
    tree:dispose()
  end)
  tree:reset_filepaths("/search-locations", { "matches.lua" })
  local key = Paths.key("/search-locations/matches.lua")
  for index = 1, count do
    tree:add_location(key, { locationuuid = "match:" .. index, lnum = index, col = 1, text = "match" })
  end
  return tree, key
end

t:test("removing visible matches preserves hidden order and the published metadata", function()
  local tree, key = fixture(5)
  tree:mark_node_invisible("match:2")
  tree:mark_node_invisible("match:4")
  treeview.publish(tree)
  local published = tree:retrieve(key)
  tree:remove_visible_locations(published)
  t.assert_eq(5, #published.locations, "the displayed snapshot remains immutable until publication")
  t.assert_eq(5, #tree:retrieve(key).locations)
  t.assert_eq(2, #tree.entries[key].locations)
  t.assert_eq("match:2", tree.entries[key].locations[1].locationuuid)
  t.assert_eq("match:4", tree.entries[key].locations[2].locationuuid)
  t.assert_nil(tree.entries["match:1"])
  t.assert_nil(tree.entries["match:3"])
  t.assert_nil(tree.entries["match:5"])
  treeview.publish(tree)
  t.assert_eq(2, #tree:retrieve(key).locations)
  tree:reset_hidden()
  tree:remove_visible_locations(tree:retrieve(key))
  treeview.publish(tree)
  t.assert_eq(0, #tree:retrieve(key).locations)
  t.assert_nil(tree.entries["match:2"])
  t.assert_nil(tree.entries["match:4"])
end)

t:test("clearing a dense file keeps only its excluded match", function()
  local tree, key = fixture(10000)
  tree:mark_node_invisible("match:10000")
  tree:remove_visible_locations(tree.entries[key])
  t.assert_eq(1, #tree.entries[key].locations)
  t.assert_eq("match:10000", tree.entries[key].locations[1].locationuuid)
end)

t:test("result rows take whole last characters and keep the CRLF breaks a match spans", function()
  local root = t:tempdir()
  local mark = stl.icon.listchars.eol ---@type string
  local files =
    { ["zh.txt"] = "这是中文文本\n", ["crlf.txt"] = "ab\r\ncd\r\n", ["mark.txt"] = "a" .. mark .. "b\n" }
  for name, text in pairs(files) do
    fs.write(vim.fs.joinpath(root, name), text)
  end
  local tree = Files.new({ name = "search rows", tree = Paths.new() })
  t:defer(function()
    tree:dispose()
  end)
  ---@return table[]
  local function rows(name, pattern, regex, replacement)
    local result = assert(tree:search({
      cwd = root,
      specified_filepath = vim.fs.joinpath(root, name),
      excludes = {},
      includes = {},
      flag_case_sensitive = true,
      flag_exclude = false,
      flag_gitignore = false,
      flag_regex = regex,
      flag_replace = replacement ~= nil,
      max_filesize = "1M",
      search_pattern = pattern,
      replace_pattern = replacement,
    }))
    return vim.tbl_map(function(item)
      return { item.text, item.highlights }
    end, result.items)
  end

  t.assert_same({
    {
      "这是中文X文本",
      { { coll = 6, colr = 12, hlname = "m_ss_search" }, { coll = 12, colr = 13, hlname = "m_ss_replace" } },
    },
  }, rows("zh.txt", "中文", false, "X"))
  t.assert_same(
    { { "这是中文文本", { { coll = 6, colr = 12, hlname = "m_ss_matches" } } } },
    rows("zh.txt", "中文", false)
  )
  local highlights = {
    { coll = 2, colr = 2 + #mark, hlname = "m_ss_search" },
    { coll = 2 + #mark, colr = 3 + #mark, hlname = "m_ss_replace" },
  }
  t.assert_same({
    { "ab" .. mark .. "X", highlights },
    { "cd" .. mark .. "X", highlights },
  }, rows("crlf.txt", [[\r\n]], true, "X"))

  -- The text holds the line break mark itself: the match stands for no break.
  t.assert_same({
    {
      "a" .. mark .. "bX",
      {
        { coll = 0, colr = 2 + #mark, hlname = "m_ss_search" },
        { coll = 2 + #mark, colr = 3 + #mark, hlname = "m_ss_replace" },
      },
    },
  }, rows("mark.txt", "a" .. mark .. "b", false, "X"))
end)

t:test("search publication rebuild preserves only-selected projection", function()
  local view = Files.new({ name = "selected publication", tree = Paths.new() })
  t:defer(function()
    view:dispose()
  end)
  local root = "/search-publication"
  local filepath = root .. "/matches.txt"
  local fileuuid = Paths.key(filepath)
  view:reset_filepaths(root, { filepath })
  treeview.publish(view)
  view:set_selected(fileuuid, true)
  treeview.publish(view)
  view:reset_filepaths(root, { filepath })

  treeview.publish(view)
  t.assert_true(view:isselected(fileuuid), "selected file restored")
  treeview.publish(view, { mode = "list", only_selected = true })
  t.assert_true(view:linecount() > 0, "only-selected projection")
  t.assert_eq(fileuuid, view:retrieve_uuid(view:linecount()), "selected file projection")
end)

t:test("native search paths cross the OS boundary and publish canonical identities", function()
  local tree = Files.new({ name = "canonical search paths", tree = Paths.new() })
  t:defer(function()
    tree:dispose()
  end)
  ---@type era.m.searcher.view.filetree.ISearchParams
  local params = {
    cwd = "C:/workspace/project",
    specified_filepath = "C:/workspace/project/src/main.lua",
    excludes = {},
    includes = { "*.lua" },
    flag_case_sensitive = true,
    flag_exclude = false,
    flag_gitignore = false,
    flag_regex = false,
    flag_replace = false,
    max_filesize = "1M",
    max_matches = 500,
    search_pattern = "needle",
    replace_pattern = nil,
  }

  t:patch_table(yoz.canonical_path, "to_os_path", function(filepath)
    return "OS<" .. filepath .. ">"
  end)
  local options = tree:build_search_options(params)
  t.assert_eq("OS<C:/workspace/project>", options.cwd, "native search cwd")
  t.assert_eq("OS<C:/workspace/project/src/main.lua>", options.specified_filepath, "native specified filepath")

  ---@diagnostic disable-next-line: missing-fields
  local result = tree:normalize_search_result(params, {
    items = {
      { p = [[src\main.lua]], matches = {} },
      { p = [[D:\archive\outside.lua]], matches = {} },
    },
    limit_reached = false,
  })
  local expected = {
    "C:/workspace/project/src/main.lua",
    "D:/archive/outside.lua",
  } ---@type string[]
  for _, filepath in ipairs(expected) do
    local filematch = result.filematch_map[Paths.key(filepath)]
    t.assert_true(filematch ~= nil, "published filepath: " .. filepath)
    t.assert_eq(filepath, filematch and filematch.filepath, "canonical published filepath")
    t.assert_false(filematch and filematch.relative:find("\\", 1, true) ~= nil, "canonical relative filepath")
  end
end)

t:run()
