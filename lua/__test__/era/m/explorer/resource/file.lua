---@diagnostic disable: undefined-global
--- Test for era.m.explorer.resource.file module
--- Run with: nvim -l lua/__test__/era/m/explorer/resource/file.lua

local bootstrap = require("__test__.bootstrap")
local harness = require("__test__.harness")

local t = harness.new("era.m.explorer.resource.file")
local is_win = package.config:sub(1, 1) == "\\" ---@type boolean
local use_trash = false ---@type boolean

local function normalize(filepath, keep_trailing_slash)
  local had_trailing_slash = filepath:sub(-1) == "/" or filepath:sub(-1) == "\\" ---@type boolean
  local normalized = filepath:gsub("\\", "/"):gsub("/+", "/") ---@type string
  if keep_trailing_slash == false and normalized ~= "/" and not normalized:match("^[A-Za-z]:/$") then
    normalized = normalized:gsub("/+$", "")
  elseif keep_trailing_slash ~= false and had_trailing_slash and normalized:sub(-1) ~= "/" then
    normalized = normalized .. "/"
  end
  return normalized
end

bootstrap.with_runtime(t, {
  dot = {
    context = {
      explorer = {
        trash = {
          snapshot = function()
            return use_trash
          end,
        },
      },
    },
  },
  era = {
    m = {
      lsp = {
        event = {
          on_rename = function(_, _, callback)
            return callback()
          end,
          rename_buf = function() end,
        },
      },
    },
  },
  stl = {
    env = {
      IS_MAC = false,
      IS_NIX = false,
      IS_WIN = is_win,
      IS_WSL = false,
      PATH_SEP = package.config:sub(1, 1),
    },
    os = {
      path = {
        normalize = normalize,
        to_os = function(filepath)
          return is_win and filepath:gsub("/", "\\") or filepath
        end,
      },
    },
    reporter = {
      error = function() end,
      warn = function() end,
    },
  },
})

local FileManager = require("era.m.explorer.resource.file")

---@return string root
---@return string target
---@return string link
local function create_directory_link_fixture()
  local root = vim.fn.tempname() ---@type string
  local target = root .. "/target" ---@type string
  local link = root .. "/link" ---@type string
  vim.fn.mkdir(target, "p")
  vim.fn.writefile({ "sentinel" }, target .. "/sentinel")

  local ok, err = vim.uv.fs_symlink("target", link, is_win and { dir = true } or nil)
  if not ok then
    error("failed to create symlink fixture: " .. tostring(err))
  end
  return root, target, link
end

---@param root string
---@return era.m.explorer.resource.INode
local function load_link_node(root)
  local manager = FileManager.new({ name = "test", show_hidden = true })
  for _, node in ipairs(manager:load(root .. "/")) do
    if node.nodename == "link" then
      return node
    end
  end
  error("link node was not loaded")
end

t:test("load: directory symlink is expandable", function()
  local root = create_directory_link_fixture()
  local node = load_link_node(root)

  t.assert_eq("D", node.nodetype, "node type")
  t.assert_eq(root .. "/link/", node.filepath, "node filepath")
  vim.fn.delete(root, "rf")
end)

t:test("remove: deletes the symlink without touching its target", function()
  local root, target, link = create_directory_link_fixture()
  local node = load_link_node(root)
  local removed = false ---@type boolean

  local ok = FileManager.new({ name = "test" }):remove(node.filepath, function()
    removed = true
  end)

  t.assert_true(ok, "remove result")
  t.assert_true(removed, "remove callback")
  t.assert_nil(vim.uv.fs_lstat(link), "symlink should be removed")
  t.assert_true(vim.uv.fs_stat(target .. "/sentinel") ~= nil, "target should remain")
  vim.fn.delete(root, "rf")
end)

t:test("move: moves the symlink without moving its target", function()
  local root, target, link = create_directory_link_fixture()
  local node = load_link_node(root)
  local moved = root .. "/moved" ---@type string

  local ok = FileManager.new({ name = "test" }):move(node.filepath, moved .. "/")

  t.assert_true(ok, "move result")
  t.assert_nil(vim.uv.fs_lstat(link), "source symlink should be gone")
  t.assert_eq("link", vim.uv.fs_lstat(moved).type, "destination should remain a symlink")
  t.assert_true(vim.uv.fs_stat(target .. "/sentinel") ~= nil, "target should remain")
  vim.fn.delete(root, "rf")
end)

t:test("copy: copies the symlink without copying its target directory", function()
  local root, target = create_directory_link_fixture()
  local node = load_link_node(root)
  local copied = root .. "/copied" ---@type string

  local ok = FileManager.new({ name = "test" }):copy(node.filepath, copied .. "/")

  t.assert_true(ok, "copy result")
  t.assert_eq("link", vim.uv.fs_lstat(copied).type, "copy should remain a symlink")
  t.assert_eq("target", vim.uv.fs_readlink(copied), "link target")
  t.assert_true(vim.uv.fs_stat(target .. "/sentinel") ~= nil, "target should remain")
  vim.fn.delete(root, "rf")
end)

t:test("copy: reuses scandir types for regular descendants", function()
  local root = vim.fn.tempname() ---@type string
  local source = root .. "/source" ---@type string
  local target = root .. "/target" ---@type string
  vim.fn.mkdir(source .. "/nested", "p")
  vim.fn.writefile({ "content" }, source .. "/nested/file")
  local lstat_calls = 0 ---@type integer
  local fs_lstat = vim.uv.fs_lstat

  t:patch_table(vim.uv, "fs_lstat", function(filepath)
    lstat_calls = lstat_calls + 1
    return fs_lstat(filepath)
  end)

  local ok = FileManager.new({ name = "test" }):copy(source .. "/", target .. "/")

  t.assert_true(ok, "copy result")
  t.assert_eq(2, lstat_calls, "only target existence and source identity should use lstat")
  t.assert_true(vim.uv.fs_stat(target .. "/nested/file") ~= nil, "nested file should be copied")
  vim.fn.delete(root, "rf")
end)

t:test("remove with trash: passes a slash-free symlink path to the native tool", function()
  local root, target, link = create_directory_link_fixture()
  local node = load_link_node(root)
  local command = nil ---@type string[]|nil
  use_trash = true

  t:patch_table(stl.env, "IS_MAC", true)
  t:patch_table(stl.env, "IS_NIX", false)
  t:patch_table(stl.env, "IS_WIN", false)
  t:patch_table(stl.env, "IS_WSL", false)
  t:patch_table(vim, "system", function(argv)
    command = argv
    return {
      wait = function()
        return { code = 0, stderr = "" }
      end,
    }
  end)

  local ok = FileManager.new({ name = "test" }):remove(node.filepath, function() end)
  use_trash = false

  t.assert_true(ok, "remove result")
  t.assert_true(command ~= nil, "trash command")
  t.assert_eq(link, command[3], "trash target should not have a trailing slash")
  t.assert_true(vim.uv.fs_lstat(link) ~= nil, "mocked trash should leave the symlink")
  t.assert_true(vim.uv.fs_stat(target .. "/sentinel") ~= nil, "target should remain")
  vim.fn.delete(root, "rf")
end)

t:run()
