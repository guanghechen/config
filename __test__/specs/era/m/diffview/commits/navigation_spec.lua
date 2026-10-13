---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.era.m.diffview.commits.navigation" ---@type string

require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new("era.m.diffview.commits.navigation")
local native = require("__test__.support.result_tree")
local commits = require("era.m.diffview.pane.commits")
local panels = require("era.m.diffview.pane.tree")

local first = {
  hash = "aaaa",
  abbrev_hash = "aaaa",
  author = "A",
  date = 0,
  message = "first",
  files = {
    { filepath = "src/a.lua", status = "M" },
    { filepath = "src/sub/b.lua", status = "A" },
    { filepath = "z.lua", status = "D" },
  },
}
local second = { hash = "bbbb", abbrev_hash = "bbbb", author = "B", date = 0, message = "second" }

---@param mode                          ?string
---@param input                         ?table[]
---@param compressed                    ?boolean
---@return era.view.ResultTree, integer
local function render(mode, input, compressed)
  input = input or { first, second }
  local include_files = {}
  for _, commit in ipairs(input) do
    include_files[commit.hash] = true
  end
  local bufnr = commits.create_buffer()
  local owner = panels.new()
  t:defer(function()
    owner:dispose()
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)
  native.await(commits.apply_to_buffer(
    bufnr,
    commits.render(input, {
      viewtype = mode or "tree",
      foldempty = compressed == true,
      layout = 2,
      include_files = include_files,
    }),
    owner
  ))
  return owner, bufnr
end

---@param owner                         era.view.ResultTree
---@param key                           string
---@param value                         boolean
---@return nil
local function expand(owner, key, value)
  owner:set_expansion(key, value, false)
  native.await(owner:ready())
end

t:test("commits begin collapsed and their file trees share native row navigation", function()
  local owner, bufnr = render()
  t.assert_eq(2, owner:linecount())
  expand(owner, "commit:aaaa", true)
  t.assert_eq(7, owner:linecount())
  local frame = commits.get_navigation(bufnr)
  t.assert_eq(1, commits.resolve_parent_lnum(frame, 2))
  t.assert_eq(2, commits.resolve_parent_lnum(frame, 3))
  t.assert_eq(3, commits.resolve_parent_lnum(frame, 4))
  t.assert_eq(6, commits.resolve_last_child_or_sibling_lnum(frame, 1))
  t.assert_eq("src/sub/b.lua", commits.get_item_at_line(bufnr, 4).entry.filepath)
end)

t:test("the same directory under different commits keeps independent expansion", function()
  local peer = vim.tbl_extend("force", second, { files = first.files })
  local owner, bufnr = render("tree", { first, peer })
  expand(owner, "commit:aaaa", true)
  expand(owner, "commit:bbbb", true)
  local a = panels.key("commit:aaaa", "src", true)
  local b = panels.key("commit:bbbb", "src", true)
  expand(owner, a, false)
  t.assert_false(owner:expanded(a))
  t.assert_true(owner:expanded(b))
  t.assert_nil(owner:retrieve_lnum(panels.key("commit:aaaa", "src/a.lua", false)))
  local row = owner:retrieve_lnum(panels.key("commit:bbbb", "src/a.lua", false))
  t.assert_eq("bbbb", commits.get_item_at_line(bufnr, row).commit.hash)
end)

t:test("compressed directory rows retain the deepest semantic path", function()
  local commit = vim.tbl_extend("force", first, { files = { first.files[2] } })
  local owner, bufnr = render("tree", { commit }, true)
  expand(owner, "commit:aaaa", true)
  t.assert_eq(3, owner:linecount())
  t.assert_eq("src/sub", commits.get_item_at_line(bufnr, 2).filepath)
  expand(owner, panels.key("commit:aaaa", "src/sub", true), false)
  t.assert_eq(2, owner:linecount())
end)

t:test("List files remain attached to their commit and use full Git paths", function()
  local owner, bufnr = render("list")
  expand(owner, "commit:aaaa", true)
  t.assert_eq(5, owner:linecount())
  for row = 2, 4 do
    local item = commits.get_item_at_line(bufnr, row)
    t.assert_eq("file", item.type)
    t.assert_eq("aaaa", item.commit.hash)
    t.assert_eq(1, commits.resolve_parent_lnum(owner:frame(), row))
    t.assert_eq(item.entry.filepath, owner:frame():rows(row, row).labels[1])
  end
end)

t:test("Git graph and rich commit highlights survive native publication", function()
  local commit = vim.tbl_extend(
    "force",
    second,
    { author = "Jesse Duffield", graph = "◎─╮", message = ":sparkles: merge graph" }
  )
  local owner = render("tree", { commit })
  local frame = owner:frame()
  t.assert_true(frame:rows(1, 1).labels[1]:find("bbbb JD ◎─╮ ✨ merge graph", 1, true) ~= nil)
  local highlights = frame:node(frame:node_at(1)).fields.highlights
  t.assert_eq("m_dv_cm_hash", highlights[1].hlname)
  t.assert_eq(0, highlights[1].coll)
end)

t:test("inline List retains commit groups and the hidden directory expansion across mode switches", function()
  local peer = vim.tbl_extend("force", second, { files = first.files })
  local owner, bufnr = render("tree", { first, peer })
  expand(owner, "commit:aaaa", true)
  local directory = panels.key("commit:aaaa", "src", true)
  local nested = panels.key("commit:aaaa", "src/sub", true)
  expand(owner, directory, false)
  expand(owner, nested, false)
  local source = owner:frame():source()
  local directory_id, nested_id = source:id(directory), source:id(nested)
  local revision = source:revision()
  for _, mode in ipairs({ "list", "tree" }) do
    native.await(commits.apply_to_buffer(
      bufnr,
      commits.render({ first, peer }, {
        viewtype = mode,
        foldempty = true,
        layout = 2,
        include_files = { aaaa = true, bbbb = true },
      }),
      owner
    ))
    local frame = owner:frame()
    t.assert_eq(revision, frame:source():revision())
    t.assert_eq(directory_id, frame:source():id(directory))
    t.assert_eq(nested_id, frame:source():id(nested))
    t.assert_false(frame:flags(directory_id).expanded)
    t.assert_false(frame:flags(nested_id).expanded)
    t.assert_true(owner:expanded("commit:aaaa"))
    t.assert_false(owner:expanded("commit:bbbb"))
    t.assert_eq(mode == "list" and 5 or 4, owner:linecount())
    if mode == "list" then
      for row = 2, 4 do
        local item = commits.get_item_at_line(bufnr, row)
        t.assert_eq(item.entry.filepath, frame:rows(row, row).labels[1])
        t.assert_eq(1, commits.resolve_parent_lnum(frame, row))
      end
      expand(owner, "commit:aaaa", false)
      t.assert_eq(2, owner:linecount())
      expand(owner, "commit:aaaa", true)
      t.assert_eq(5, owner:linecount())
    end
  end
end)

t:test("panel recreation reuses native state and a requested cursor waits for its row", function()
  local owner, bufnr = render()
  expand(owner, "commit:aaaa", true)
  local key = panels.key("commit:aaaa", "src/sub/b.lua", false)
  owner:focus_key(key)
  t.wait_until(function()
    return owner:frame():header().cursor == owner:frame():source():id(key)
  end, 5000)
  local identity = owner.state
  vim.api.nvim_buf_delete(bufnr, { force = true })
  local next_bufnr = commits.create_buffer()
  local winnr =
    vim.api.nvim_open_win(next_bufnr, false, { relative = "editor", row = 0, col = 0, width = 60, height = 10 })
  t:defer(function()
    if vim.api.nvim_win_is_valid(winnr) then
      vim.api.nvim_win_close(winnr, true)
    end
  end)
  native.await(commits.apply_to_buffer(
    next_bufnr,
    commits.render({ first, second }, {
      layout = 2,
      viewtype = "tree",
      foldempty = false,
      include_files = { aaaa = true, bbbb = true },
    }),
    owner
  ))
  t.assert_true(identity == owner.state)
  t.assert_eq(owner:retrieve_lnum(key), vim.api.nvim_win_get_cursor(winnr)[1])
end)

t:run()
