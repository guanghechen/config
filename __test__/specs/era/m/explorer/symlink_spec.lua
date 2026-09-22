---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.era.m.explorer.symlink" ---@type string

local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")
local t = harness.new("era.m.explorer.symlink")

t:patch_global("yoz", require("yoz"))
t:patch_global("stl", require("stl"))
bootstrap.with_runtime(t, {
  era = {
    m = {
      explorer = { Node = require("era.m.explorer.node") },
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
})

local FileManager = require("era.m.explorer.resource.file")
local Tree = require("era.m.explorer.tree")
local View = require("era.m.explorer.view")
local to_os = yoz.canonical_path.to_os_path

---@class __test__.explorer.ISymlinkFixture
---@field public root                   string
---@field public manager                era.m.explorer.resource.FileManager
---@field public tree                   era.m.explorer.Tree
---@field public bufnr                  integer
---@field public view                   era.m.explorer.View

---@return __test__.explorer.ISymlinkFixture
local function fixture()
  local root = yoz.canonical_path.from_os_path(vim.fn.tempname(), false) ---@type string
  vim.fn.mkdir(to_os(root), "p")
  t:defer(function()
    vim.fn.delete(to_os(root), "rf")
  end)
  vim.fn.mkdir(to_os(root .. "/target/nested"), "p")
  vim.fn.mkdir(to_os(root .. "/container"), "p")
  vim.fn.writefile({ "target" }, to_os(root .. "/target/nested/file.lua"))
  vim.fn.writefile({ "plain" }, to_os(root .. "/plain.lua"))
  assert(vim.uv.fs_symlink("target", to_os(root .. "/dir-link"), { dir = true }))
  assert(vim.uv.fs_symlink("plain.lua", to_os(root .. "/file-link.lua")))
  assert(vim.uv.fs_symlink("missing", to_os(root .. "/broken-link"), { dir = true }))
  assert(vim.uv.fs_symlink(to_os("../target"), to_os(root .. "/container/alias"), { dir = true }))

  local manager = FileManager.new({ name = "symlink-test" })
  t:defer(function()
    manager:dispose()
  end)
  local tree = Tree.new({
    name = "symlink-test",
    initial_root = root .. "/",
    resource_manager = manager,
    o_flag_foldempty = stl.c.Observable.from_value(true),
    o_flag_hidden = stl.c.Observable.from_value(true),
  })
  t:defer(function()
    tree:dispose()
  end)
  tree:refresh(false)
  local bufnr = vim.api.nvim_create_buf(false, true)
  t:defer(function()
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)

  return { root = root, manager = manager, tree = tree, bufnr = bufnr, view = View.new("symlink-test") }
end

---@param f                             __test__.explorer.ISymlinkFixture
---@param show_icons                    ?boolean
---@return era.m.explorer.view.IRenderResult
local function render(f, show_icons)
  return f.view:render(f.bufnr, f.tree, f.tree:get_root_node(), {
    foldempty = true,
    defer_file_icons = true,
    show_diagnostics = false,
    show_git_status = false,
    show_icons = show_icons == true,
  })
end

t:test("file, directory and dangling links render suffix markers without file icons", function()
  local f = fixture()
  local result = render(f)
  for _, case in ipairs({
    { path = "dir-link/", kind = "D", link = true },
    { path = "file-link.lua", kind = "F", link = true },
    { path = "broken-link", kind = "F", link = true },
    { path = "target/", kind = "D", link = false },
    { path = "plain.lua", kind = "F", link = false },
  }) do
    local filepath = f.root .. "/" .. case.path
    local node = assert(f.manager:locate(filepath))
    t.assert_eq(case.kind, node.nodetype, case.path .. " interaction type")
    t.assert_eq(case.link, node.is_link, case.path .. " resource identity")
    local lnum = assert(result.layout:lnum(filepath))
    t.assert_eq(case.link, result.lines[lnum]:sub(-#" ") == " ", case.path .. " visible suffix")
  end
  t.assert_false(assert(f.manager:locate(f.root .. "/dir-link/nested/file.lua")).is_link, "plain linked descendant")
  t.assert_nil(f.manager:locate(f.root .. "/missing"), "missing target remains absent")
end)

t:test("scandir unknown types retain link identity", function()
  local f = fixture()
  local scandir_next = vim.uv.fs_scandir_next
  t:patch_table(vim.uv, "fs_scandir_next", function(handle)
    local name, kind = scandir_next(handle)
    return name, name ~= nil and "unknown" or kind
  end)
  local links = {} ---@type table<string, boolean>
  for _, node in ipairs(f.manager:load(f.root .. "/")) do
    links[node.nodename] = node.is_link
  end
  t.assert_true(links["dir-link"], "directory link")
  t.assert_true(links["file-link.lua"], "file link")
  t.assert_true(links["broken-link"], "dangling link")
  t.assert_false(links.target, "regular directory")
  t.assert_false(links["plain.lua"], "regular file")
end)

t:test("empty-directory folding keeps the link entry separate from its parent and descendants", function()
  local f = fixture()
  for _, path in ipairs({ "dir-link/nested/", "container/alias/nested/", "target/nested/" }) do
    f.tree:expand_path(f.root .. "/" .. path)
  end
  local result = render(f)
  for _, path in ipairs({ "dir-link/", "container/alias/" }) do
    local filepath = f.root .. "/" .. path
    local lnum = assert(result.layout:lnum(filepath))
    t.assert_eq(filepath, result.layout:id(lnum), "link remains the displayed node")
    t.assert_nil(result.layout:folded_ids(lnum), "link has its own row")
    t.assert_true(result.lines[lnum]:sub(-#" ") == " ", "expanded link suffix")
    local child_lnum = assert(result.layout:lnum(filepath .. "nested/"))
    t.assert_true(child_lnum ~= lnum, "child stays on a separate row")
    t.assert_false(result.lines[child_lnum]:sub(-#" ") == " ", "child does not inherit link identity")
  end
  local parent_lnum = assert(result.layout:lnum(f.root .. "/container/"))
  t.assert_eq(f.root .. "/container/", result.layout:id(parent_lnum), "ordinary parent remains separate")
  local ordinary_lnum = assert(result.layout:lnum(f.root .. "/target/nested/"))
  t.assert_true(result.lines[ordinary_lnum]:find("target/nested", 1, true) ~= nil, "ordinary paths still fold")

  t.assert_true(f.tree:attach(f.root .. "/dir-link/"), "attach directory link as root")
  t.assert_true(f.tree:get_root_node().is_link, "attached root retains link identity")
end)

t:test("attach rejects file and dangling-link roots while preserving the current directory", function()
  local f = fixture()
  t:patch_table(stl.reporter, "error", function() end)
  local root = f.tree:get_root_node()
  for _, path in ipairs({ "plain.lua/", "file-link.lua/", "broken-link/" }) do
    t.assert_false(f.tree:attach(f.root .. "/" .. path), path .. " is not a directory root")
    t.assert_true(root == f.tree:get_root_node(), "rejected root preserves the current directory")
    t.assert_eq(f.root .. "/", f.tree:get_root_filepath(), "current root keeps its directory path")
  end
end)

t:test("refresh detects same-name and same-type replacements in both directions", function()
  local f = fixture()
  for _, case in ipairs({ { name = "file-link.lua", directory = false }, { name = "dir-link", directory = true } }) do
    local path = f.root .. "/" .. case.name
    local filepath = path .. (case.directory and "/" or "")
    local node = assert(f.tree:locate(filepath))
    assert(vim.uv.fs_unlink(to_os(path)))
    if case.directory then
      assert(vim.uv.fs_mkdir(to_os(path), 493))
    else
      vim.fn.writefile({ "replacement" }, to_os(path))
    end
    f.tree:mark_all_dirty()
    f.tree:refresh(false)
    t.assert_true(node == f.tree:locate(filepath), "same-type replacement preserves node identity")
    local result = render(f)
    local lnum = assert(result.layout:lnum(filepath))
    t.assert_false(result.lines[lnum]:sub(-#" ") == " ", "regular replacement loses marker")

    if case.directory then
      assert(vim.uv.fs_rmdir(to_os(path)))
    else
      assert(vim.uv.fs_unlink(to_os(path)))
    end
    assert(vim.uv.fs_symlink(case.directory and "target" or "plain.lua", to_os(path), { dir = case.directory }))
    f.tree:mark_all_dirty()
    f.tree:refresh(false)
    result = render(f)
    lnum = assert(result.layout:lnum(filepath))
    t.assert_true(result.lines[lnum]:sub(-#" ") == " ", "recreated link regains marker")
  end
end)

t:test("dangling directory links survive refresh as their targets appear and disappear", function()
  local f = fixture()
  assert(vim.uv.fs_mkdir(to_os(f.root .. "/missing"), 493))
  f.tree:refresh(true)
  t.assert_eq("D", assert(f.tree:locate(f.root .. "/broken-link/")).nodetype, "restored target is expandable")
  f.tree:expand_path(f.root .. "/broken-link/")
  assert(vim.uv.fs_rmdir(to_os(f.root .. "/missing")))
  f.tree:refresh(true)
  local result = render(f)
  local filepath = f.root .. "/broken-link"
  t.assert_eq("F", assert(f.tree:locate(filepath)).nodetype, "dangling link returns to a file leaf")
  local lnum = assert(result.layout:lnum(filepath))
  t.assert_true(result.lines[lnum]:sub(-#" ") == " ", "dangling link keeps its marker")
end)

t:test("deferred icons keep link markers and their highlight ranges intact", function()
  local f = fixture()
  t:patch_table(stl, "fileicon", {
    get_directory_icon = function()
      return "D", "DirectoryIcon", false
    end,
    get_file_icon = function(_, filetype)
      return filetype == "" and "󰈚" or "", "FileIcon"
    end,
  })
  for _, ignored in ipairs({ false, true }) do
    local link_hl = ignored and "m_ex_symlink_ignored" or "m_ex_symlink"
    t:patch_table(era.m.git.state, "is_ignored", function()
      return ignored
    end)
    local result = render(f, true)
    f.view:update_file_icons(f.bufnr, result, 1, #result.deferred_file_icons)
    local lnum = assert(result.layout:lnum(f.root .. "/file-link.lua"))
    local line = vim.api.nvim_buf_get_lines(f.bufnr, lnum - 1, lnum, false)[1]
    t.assert_eq(result.lines[lnum], line, "buffer and result stay aligned")
    t.assert_true(line:find(" file-link.lua ", 1, true) ~= nil, "suffix and exact icon remain visible")

    local marker_highlight = nil ---@type stl.t.IHighlight|nil
    for _, highlight in ipairs(result.highlights) do
      if highlight.lnum == lnum and highlight.hlname == link_hl then
        marker_highlight = highlight
        break
      end
    end
    assert(marker_highlight, "link marker has an independent highlight")
    t.assert_eq(" ", line:sub(marker_highlight.coll + 1, marker_highlight.colr), "suffix range follows the icon")

    local marker_found = false
    local name_found = false
    for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(f.bufnr, f.view:get_namespace(), 0, -1, { details = true })) do
      if mark[2] == lnum - 1 and mark[4].end_col ~= nil then
        local text = line:sub(mark[3] + 1, mark[4].end_col)
        if text == " " then
          marker_found = true
          t.assert_eq(link_hl, mark[4].hl_group, "marker retains its status tint")
        elseif text == "file-link.lua" then
          name_found = true
          t.assert_eq(ignored and "m_ex_ignored" or "m_ft_filename", mark[4].hl_group, "name highlight")
        end
      end
    end
    t.assert_true(marker_found, "separate marker range")
    t.assert_true(name_found, "name range follows the changed icon width")
  end
end)

t:run()
