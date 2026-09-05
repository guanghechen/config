--- Run with: nvim -l __test__/run.lua __test__/specs/era/m/explorer/tree_spec.lua
---@diagnostic disable: undefined-global
--- Test for era.m.explorer.tree selection semantics

local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")

local t = harness.new("era.m.explorer.tree")
local canonical_normalize_calls = {} ---@type { filepath: string, keep_trailing_slash: boolean|nil }[]

local function normalize(filepath, keep_trailing_slash)
  local had_trailing_slash = filepath:sub(-1) == "/" or filepath:sub(-1) == "\\" ---@type boolean
  local normalized = filepath:gsub("\\", "/"):gsub("/+", "/") ---@type string
  if keep_trailing_slash == false and normalized ~= "/" then
    normalized = normalized:gsub("/+$", "")
  elseif keep_trailing_slash ~= false and had_trailing_slash and normalized:sub(-1) ~= "/" then
    normalized = normalized .. "/"
  end
  return normalized
end

local function canonical_normalize(filepath, keep_trailing_slash)
  canonical_normalize_calls[#canonical_normalize_calls + 1] = {
    filepath = filepath,
    keep_trailing_slash = keep_trailing_slash,
  }
  return normalize(filepath, keep_trailing_slash)
end

local Observable = {}

function Observable.from_value(initial)
  local value = initial ---@type any
  return {
    next = function(_, next_value)
      value = next_value
    end,
    snapshot = function()
      return value
    end,
  }
end

local Node = require("era.m.explorer.node")

bootstrap.with_runtime(t, {
  dot = {
    path = {
      cwd = function()
        return "/project"
      end,
      dirname = function(filepath)
        local target = normalize(filepath, false)
        return target:match("^(.*)/[^/]+$") or target
      end,
      normalize = normalize,
    },
  },
  era = {
    m = {
      explorer = {
        Node = Node,
      },
      git = {
        state = {
          is_ignored = function()
            return false
          end,
          preload_ignored = function() end,
        },
      },
    },
  },
  stl = {
    c = {
      Observable = Observable,
    },
    icon = {
      symbols = {
        selection = "S",
        selection_copy = "C",
        selection_cut = "X",
      },
    },
    os = {
      path = {
        normalize = canonical_normalize,
      },
    },
    reporter = {
      error = function() end,
      warn = function() end,
    },
  },
})

local Tree = require("era.m.explorer.tree")
local View = require("era.m.explorer.view")

---@return era.m.explorer.Tree
---@return table<string, integer>
---@return fun(items: era.m.explorer.resource.INode[]): nil
local function create_tree()
  local load_calls = {} ---@type table<string, integer>
  local dir_items = {
    { nodename = "child", nodetype = "F" },
  } ---@type era.m.explorer.resource.INode[]

  local resource_manager = {
    compare = function(left, right)
      if left.nodename == right.nodename then
        return 0
      end
      return left.nodename < right.nodename and -1 or 1
    end,
    load = function(_, filepath)
      load_calls[filepath] = (load_calls[filepath] or 0) + 1
      if filepath == "/project/" then
        return { { nodename = "dir", nodetype = "D" } }
      end
      if filepath == "/project/dir/" then
        return dir_items
      end
      return {}
    end,
    locate = function(_, filepath)
      local nodename = normalize(filepath, false):match("([^/]+)$") or ""
      return { nodename = nodename, nodetype = "D" }
    end,
  }

  local tree = Tree.new({
    name = "selection-test",
    initial_root = "/project/",
    resource_manager = resource_manager,
    o_flag_foldempty = Observable.from_value(false),
    o_flag_hidden = Observable.from_value(true),
  })
  tree:refresh(false)

  return tree, load_calls, function(items)
    dir_items = items
  end
end

t:test("model: canonicalizes ingress once and composes child filepaths lexically", function()
  local tree = create_tree()

  canonical_normalize_calls = {}
  local dir = tree:locate("\\project\\dir\\")
  t.assert_true(dir ~= nil, "canonical lookup")
  t.assert_eq(1, #canonical_normalize_calls, "locate normalization count")
  t.assert_eq("\\project\\dir\\", canonical_normalize_calls[1].filepath, "locate normalization input")
  t.assert_false(canonical_normalize_calls[1].keep_trailing_slash, "backslash lookup trailing slash policy")

  canonical_normalize_calls = {}
  ---@diagnostic disable-next-line: missing-fields
  t.assert_true(tree:insert("\\project\\dir", { nodename = "added", nodetype = "F" }), "canonical insert")
  t.assert_eq(1, #canonical_normalize_calls, "insert normalization count")
  t.assert_eq("\\project\\dir", canonical_normalize_calls[1].filepath, "insert normalization input")
  t.assert_true(canonical_normalize_calls[1].keep_trailing_slash, "directory insert trailing slash policy")

  ---@diagnostic disable-next-line: need-check-nil
  local added_idx = dir.chidxmap.added
  t.assert_true(added_idx ~= nil, "inserted child index")
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_eq("/project/dir/added", dir.children[added_idx].filepath, "lexical child filepath")

  canonical_normalize_calls = {}
  t.assert_true(tree:attach("\\project\\dir\\nested\\"), "canonical attach")
  t.assert_eq(1, #canonical_normalize_calls, "attach normalization count")
  t.assert_eq("/project/dir/nested/", tree:get_root_filepath(), "canonical attached root")

  tree:dispose()
end)

t:test("selection: keeps explicit roots without loading directory descendants", function()
  local tree, load_calls, set_dir_items = create_tree()
  local dir = tree:locate("/project/dir/")
  t.assert_true(dir ~= nil, "directory fixture")
  dir.loaded = false
  dir.children = {}
  dir.chidxmap = {}
  ---@diagnostic disable-next-line: need-check-nil
  load_calls[dir.filepath] = nil
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_false(dir.loaded, "collapsed directory should start unloaded")

  ---@diagnostic disable-next-line: need-check-nil
  tree:toggle_selected(dir.filepath, "select")

  ---@diagnostic disable-next-line: need-check-nil
  t.assert_nil(load_calls[dir.filepath], "selection must not load the directory")
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_false(dir.loaded, "selection must preserve unloaded state")
  local selected = tree:get_selected_nodes()
  t.assert_eq(1, #selected, "top-level selection count")
  t.assert_true(selected[1] == dir, "directory should be the explicit selection root")

  ---@diagnostic disable-next-line: param-type-mismatch
  tree:load_node(dir, false)
  dir.expanded = true
  local child = tree:locate("/project/dir/child")
  t.assert_true(child ~= nil, "child fixture")
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_false(child.selected, "loaded descendant must not become explicitly selected")
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_true(tree:is_selected(child.filepath), "descendant should inherit selection")

  local bufnr = vim.api.nvim_create_buf(false, true)
  local view = View.new("selection-test")
  local result = view:render(bufnr, tree, tree:get_root_node(), {
    foldempty = false,
    only_selected = true,
    show_diagnostics = false,
    show_git_status = false,
    show_icons = false,
  })
  t.assert_eq(2, #result.lines, "only-selected view should show the selected directory and loaded child")
  t.assert_eq(2, #result.sign_info_list, "inherited descendant should display selection")

  ---@diagnostic disable-next-line: need-check-nil
  tree:toggle_selected(child.filepath, "unselect")
  t.assert_eq(0, #tree:get_selected_nodes(), "unselecting an inherited descendant should clear its root")

  ---@diagnostic disable-next-line: need-check-nil
  tree:toggle_selected(child.filepath, "select")
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_true(dir.has_selected, "directory should expose partial descendant selection")
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_false(dir.selected, "partial ancestor must not become explicitly selected")
  result = view:render(bufnr, tree, tree:get_root_node(), {
    foldempty = false,
    only_selected = true,
    show_diagnostics = false,
    show_git_status = false,
    show_icons = false,
  })
  t.assert_eq(2, #result.lines, "only-selected view should retain the path to an explicit child")
  t.assert_eq(1, #result.sign_info_list, "partial ancestor should not display as selected")

  ---@diagnostic disable-next-line: need-check-nil
  tree:toggle_selected(dir.filepath, "select")
  selected = tree:get_selected_nodes()
  t.assert_eq(1, #selected, "selecting an ancestor should replace descendant selections")
  t.assert_true(selected[1] == dir, "ancestor should become the only explicit root")
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_false(child.selected, "descendant selection should be cleared")

  ---@diagnostic disable-next-line: need-check-nil
  tree:toggle_selected(dir.filepath, "unselect")
  ---@diagnostic disable-next-line: need-check-nil
  tree:toggle_selected(child.filepath, "select")
  set_dir_items({})
  tree:refresh(true)
  t.assert_eq(0, #tree:get_selected_nodes(), "refresh should remove selections for vanished descendants")
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_false(dir.has_selected, "refresh should recompute partial selection state")

  vim.api.nvim_buf_delete(bufnr, { force = true })
  tree:dispose()
end)

t:test("selection: empty-directory folding preserves an explicit selection root", function()
  local tree, _, set_dir_items = create_tree()
  local dir = tree:locate("/project/dir/")
  t.assert_true(dir ~= nil, "directory fixture")

  ---@diagnostic disable-next-line: missing-fields
  set_dir_items({ { nodename = "nested", nodetype = "D" } })
  dir.expanded = true
  tree:refresh(true)
  ---@diagnostic disable-next-line: need-check-nil
  tree:toggle_selected(dir.filepath, "select")

  local bufnr = vim.api.nvim_create_buf(false, true)
  local view = View.new("selection-fold-test")
  local result = view:render(bufnr, tree, tree:get_root_node(), {
    foldempty = true,
    only_selected = true,
    show_diagnostics = false,
    show_git_status = false,
    show_icons = false,
  })

  ---@diagnostic disable-next-line: need-check-nil
  t.assert_true(result.layout:lnum(dir.filepath) ~= nil, "folding must not hide the explicit selection root")

  vim.api.nvim_buf_delete(bufnr, { force = true })
  tree:dispose()
end)

t:test("render: pending transfer renders without explicit selection", function()
  local tree = create_tree()
  local dir = tree:locate("/project/dir/")
  t.assert_true(dir ~= nil, "directory fixture")
  ---@diagnostic disable-next-line: param-type-mismatch
  tree:load_node(dir, false)
  dir.expanded = true

  local bufnr = vim.api.nvim_create_buf(false, true)
  local view = View.new("pending-transfer-test")
  local result = view:render(bufnr, tree, tree:get_root_node(), {
    foldempty = false,
    pending_transfer = {
      mode = "move",
      ---@diagnostic disable-next-line: need-check-nil
      sources = { { filepath = dir.filepath, nodename = dir.nodename, nodetype = dir.nodetype } },
      ---@diagnostic disable-next-line: need-check-nil
      source_filepaths = { [dir.filepath] = true },
    },
    show_diagnostics = false,
    show_git_status = false,
    show_icons = false,
  })

  t.assert_eq(0, #tree:get_selected_nodes(), "pending source is not explicit selection")
  t.assert_eq(2, #result.sign_info_list, "pending directory sign inheritance")
  t.assert_eq("m_ex_cut", result.sign_info_list[1].sign_hl_group, "pending move sign")
  t.assert_eq("m_ex_cut", result.sign_info_list[2].sign_hl_group, "pending descendant sign")

  vim.api.nvim_buf_delete(bufnr, { force = true })
  tree:dispose()
end)

t:test("selection: remains consistent when attaching below a selected directory", function()
  local tree = create_tree()
  local dir = tree:locate("/project/dir/")
  t.assert_true(dir ~= nil, "directory fixture")

  ---@diagnostic disable-next-line: need-check-nil
  tree:toggle_selected(dir.filepath, "select")
  t.assert_true(tree:attach("/project/dir/nested/"), "attach below selected directory")

  local root = tree:get_root_node()
  t.assert_true(tree:is_selected(root.filepath), "attached root should inherit its ancestor selection")

  local selected = tree:get_selected_nodes()
  t.assert_eq(1, #selected, "attached subtree should retain one top-level selection")
  t.assert_true(selected[1] == dir, "actions should still consume the explicit ancestor selection")

  local filepaths = tree:get_selected_filepaths()
  t.assert_eq(1, #filepaths, "selected filepath count")
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_eq(dir.filepath, filepaths[1], "selected filepath should remain the explicit root")

  tree:toggle_selected(root.filepath, "unselect")
  t.assert_eq(0, #tree:get_selected_nodes(), "unselecting the attached root should clear its covering selection")

  tree:dispose()
end)

t:test("refresh: reloads expanded directories after invalidation", function()
  local tree, load_calls, set_dir_items = create_tree()
  local dir = tree:locate("/project/dir/")
  t.assert_true(dir ~= nil, "directory fixture")

  dir.expanded = true
  tree:refresh(false)
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_eq(1, load_calls[dir.filepath], "expanded directory should load once")

  ---@diagnostic disable-next-line: missing-fields
  set_dir_items({ { nodename = "new-child", nodetype = "F" } })
  tree:mark_all_dirty()
  tree:refresh(false)

  ---@diagnostic disable-next-line: need-check-nil
  t.assert_eq(2, load_calls[dir.filepath], "invalidated directory should reload on refresh")
  t.assert_true(tree:locate("/project/dir/new-child") ~= nil, "reloaded directory should expose new entries")

  tree:dispose()
end)

t:run()
