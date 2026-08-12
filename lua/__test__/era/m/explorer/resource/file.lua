---@diagnostic disable: undefined-global
--- Test for era.m.explorer.resource.file module
--- Run with: nvim -l lua/__test__/era/m/explorer/resource/file.lua

local bootstrap = require("__test__.bootstrap")
local harness = require("__test__.harness")

local t = harness.new("era.m.explorer.resource.file")
local is_win = package.config:sub(1, 1) == "\\" ---@type boolean
local fs_descendant_result = false ---@type boolean|nil
local fs_descendant_error = nil ---@type string|nil
local use_trash = false ---@type boolean
local normalize_calls = 0 ---@type integer
local to_os_calls = 0 ---@type integer
local from_os_calls = 0 ---@type integer
local canonical_descendant_calls = 0 ---@type integer

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

---@param filepath string
---@return string
local function to_os(filepath)
  return is_win and filepath:gsub("/", "\\") or filepath
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
      IS_OSX = false,
      IS_NIX = false,
      IS_WIN = is_win,
      IS_WSL = false,
      PATH_SEP = package.config:sub(1, 1),
    },
    os = {
      path = {
        normalize = function(filepath, keep_trailing_slash)
          normalize_calls = normalize_calls + 1
          return normalize(filepath, keep_trailing_slash)
        end,
        to_os = function(filepath)
          to_os_calls = to_os_calls + 1
          return to_os(filepath)
        end,
        from_os = function(filepath, keep_trailing_slash)
          from_os_calls = from_os_calls + 1
          return normalize(filepath, keep_trailing_slash)
        end,
      },
    },
    reporter = {
      error = function() end,
      warn = function() end,
    },
  },
  yoz = {
    canonical_path = {
      is_descendant = function(from, to)
        canonical_descendant_calls = canonical_descendant_calls + 1
        from = normalize(from, false)
        to = normalize(to, false)
        return to == from or to:sub(1, #from + 1) == from .. "/"
      end,
    },
    fs = {
      is_descendant = function()
        return fs_descendant_result, fs_descendant_error
      end,
    },
  },
})

local FileManager = require("era.m.explorer.resource.file")

---@return string
local function canonical_tempname()
  return stl.os.path.from_os(vim.fn.tempname(), false)
end

---@return string root
---@return string target
---@return string link
local function create_directory_link_fixture()
  local root = canonical_tempname() ---@type string
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

---@return string base
---@return string root
---@return string physical
local function create_root_alias_fixture()
  local base = canonical_tempname() ---@type string
  local root = base .. "/explorer" ---@type string
  local physical = base .. "/external/physical" ---@type string
  vim.fn.mkdir(root, "p")
  vim.fn.mkdir(physical .. "/nested", "p")
  vim.fn.writefile({ "nested" }, physical .. "/nested/file")
  vim.fn.writefile({ "direct" }, physical .. "/direct")

  local flags = is_win and { dir = true } or nil
  local alias_ok, alias_err = vim.uv.fs_symlink("../external/physical", root .. "/alias", flags)
  if not alias_ok then
    error("failed to create root alias fixture: " .. tostring(alias_err))
  end
  local specific_ok, specific_err = vim.uv.fs_symlink("../external/physical/nested", root .. "/specific", flags)
  if not specific_ok then
    error("failed to create specific root alias fixture: " .. tostring(specific_err))
  end

  return base, root, physical
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

t:test("create: refuses to truncate an existing file", function()
  local root = canonical_tempname() ---@type string
  local filepath = root .. "/existing.txt" ---@type string
  vim.fn.mkdir(root, "p")
  vim.fn.writefile({ "sentinel" }, filepath)

  local node = FileManager.new({ name = "test" }):create(filepath)

  t.assert_nil(node, "existing target should be rejected")
  t.assert_eq("sentinel", vim.fn.readfile(filepath)[1], "existing content")
  vim.fn.delete(root, "rf")
end)

t:test("create: refuses an existing directory", function()
  local root = canonical_tempname() ---@type string
  local dirpath = root .. "/existing/" ---@type string
  vim.fn.mkdir(dirpath, "p")

  local node = FileManager.new({ name = "test" }):create(dirpath)

  t.assert_nil(node, "existing target should be rejected")
  t.assert_true(vim.uv.fs_stat(dirpath) ~= nil, "existing directory should remain")
  vim.fn.delete(root, "rf")
end)

t:test("create: creates missing entries with nested parents", function()
  local root = canonical_tempname() ---@type string
  local filepath = root .. "/files/nested.txt" ---@type string
  local dirpath = root .. "/directories/nested/" ---@type string
  local manager = FileManager.new({ name = "test" })

  local file_node = manager:create(filepath)
  local dir_node = manager:create(dirpath)

  t.assert_true(file_node ~= nil, "file should be created")
  t.assert_eq("F", file_node.nodetype, "file node type")
  t.assert_true(dir_node ~= nil, "directory should be created")
  t.assert_eq("D", dir_node.nodetype, "directory node type")
  vim.fn.delete(root, "rf")
end)

t:test("create: close failure does not delete a replacement", function()
  local root = canonical_tempname() ---@type string
  local filepath = root .. "/target.txt" ---@type string
  local fs_close = vim.uv.fs_close
  vim.fn.mkdir(root, "p")

  t:patch_table(vim.uv, "fs_close", function(fd)
    assert(fs_close(fd))
    assert(vim.uv.fs_unlink(filepath))
    local replacement_fd = assert(vim.uv.fs_open(filepath, "wx", 438)) ---@type integer
    assert(vim.uv.fs_write(replacement_fd, "sentinel", 0))
    assert(fs_close(replacement_fd))
    return nil, "injected close failure", "EIO"
  end)

  local node = FileManager.new({ name = "test" }):create(filepath)

  t.assert_nil(node, "close failure should fail create")
  t.assert_true(vim.uv.fs_stat(filepath) ~= nil, "replacement should remain")
  t.assert_eq("sentinel", vim.fn.readfile(filepath)[1], "replacement content")
  vim.fn.delete(root, "rf")
end)

t:test("canonical resource paths cross only the OS boundary", function()
  local root = canonical_tempname() ---@type string
  local source = root .. "/source/" ---@type string
  local source_file = source .. "file" ---@type string
  local inserted = root .. "/inserted/" ---@type string
  local copied = root .. "/copied/" ---@type string
  local moved = root .. "/moved/" ---@type string
  local manager = FileManager.new({ name = "test", show_hidden = true })
  vim.fn.mkdir(root, "p")

  normalize_calls = 0
  canonical_descendant_calls = 0

  to_os_calls = 0
  t.assert_true(manager:create(source) ~= nil, "create directory")
  t.assert_true(manager:create(source_file) ~= nil, "create file")
  t.assert_true(to_os_calls > 0, "create OS conversion")

  to_os_calls = 0
  t.assert_true(manager:insert_if_missing(inserted), "insert directory")
  t.assert_true(to_os_calls > 0, "insert OS conversion")

  to_os_calls = 0
  t.assert_true(#manager:load(root .. "/") > 0, "load directory")
  t.assert_true(to_os_calls > 0, "load OS conversion")

  to_os_calls = 0
  t.assert_true(manager:locate(source_file) ~= nil, "locate file")
  t.assert_true(to_os_calls > 0, "locate OS conversion")

  to_os_calls = 0
  t.assert_eq("success", manager:copy(source, copied), "copy directory")
  t.assert_true(to_os_calls > 0, "copy OS conversion")

  to_os_calls = 0
  t.assert_true(manager:move(copied, moved), "move directory")
  t.assert_true(to_os_calls > 0, "move OS conversion")

  to_os_calls = 0
  t.assert_true(manager:remove(moved, function() end), "remove directory")
  t.assert_true(to_os_calls > 0, "remove OS conversion")

  t.assert_eq(0, normalize_calls, "canonical ingress normalization")
  t.assert_true(canonical_descendant_calls > 0, "canonical descendant backend")
  vim.fn.delete(root, "rf")
end)

t:test("load: directory symlink is expandable", function()
  local root = create_directory_link_fixture()
  local node = load_link_node(root)

  t.assert_eq("D", node.nodetype, "node type")
  t.assert_eq(root .. "/link/", node.filepath, "node filepath")
  vim.fn.delete(root, "rf")
end)

t:test("resolve_root_alias: rebuilds a canonical target through a root symlink", function()
  local base, root, physical = create_root_alias_fixture()
  local manager = FileManager.new({ name = "test", show_hidden = true })
  local fs_realpath = vim.uv.fs_realpath
  local successful_realpaths = 0 ---@type integer

  t:patch_table(vim.uv, "fs_realpath", function(filepath)
    local realpath, err, code = fs_realpath(filepath)
    if realpath ~= nil then
      successful_realpaths = successful_realpaths + 1
    end
    return realpath, err, code
  end)

  normalize_calls = 0
  from_os_calls = 0
  to_os_calls = 0

  local resolved = manager:resolve_root_alias(root .. "/", physical .. "/direct")

  t.assert_eq(root .. "/alias/direct", resolved)
  t.assert_eq(0, normalize_calls, "canonical ingress normalization")
  t.assert_eq(successful_realpaths, from_os_calls, "realpath OS conversion")
  t.assert_true(to_os_calls > 0, "realpath input OS conversion")
  vim.fn.delete(base, "rf")
end)

t:test("resolve_root_alias: prefers the most specific root symlink", function()
  local base, root, physical = create_root_alias_fixture()
  local manager = FileManager.new({ name = "test", show_hidden = true })

  local resolved = manager:resolve_root_alias(root .. "/", physical .. "/nested/file")

  t.assert_eq(root .. "/specific/file", resolved)
  vim.fn.delete(base, "rf")
end)

t:test("resolve_root_alias: preserves a canonical directory marker", function()
  local base, root, physical = create_root_alias_fixture()
  local manager = FileManager.new({ name = "test", show_hidden = true })

  local resolved = manager:resolve_root_alias(root .. "/", physical .. "/nested/")

  t.assert_eq(root .. "/specific/", resolved)
  vim.fn.delete(base, "rf")
end)

t:test("resolve_root_alias: ignores unrelated canonical targets", function()
  local base, root = create_root_alias_fixture()
  local unrelated = base .. "/external/unrelated" ---@type string
  vim.fn.mkdir(unrelated, "p")
  vim.fn.writefile({ "unrelated" }, unrelated .. "/file")

  local resolved = FileManager.new({ name = "test", show_hidden = true })
    :resolve_root_alias(root .. "/", unrelated .. "/file")

  t.assert_nil(resolved)
  vim.fn.delete(base, "rf")
end)

t:test("realpath boundary: rebuilds canonical aliases from OS paths", function()
  local root = "C:/workspace/" ---@type string
  local target = "C:/physical/nested/file" ---@type string
  local root_os_path = to_os("C:/workspace") ---@type string
  local target_os_path = to_os(target) ---@type string
  local alias_os_path = to_os("C:/workspace/alias") ---@type string
  local scan_handle = {} ---@type table
  local scan_count = 0 ---@type integer

  t:patch_table(vim.uv, "fs_realpath", function(filepath)
    if filepath == target_os_path then
      return to_os("C:/physical/nested/file")
    elseif filepath == root_os_path then
      return to_os("C:/workspace")
    elseif filepath == alias_os_path then
      return to_os("C:/physical/nested")
    end
    return nil
  end)
  t:patch_table(vim.uv, "fs_scandir", function(filepath)
    t.assert_eq(root_os_path, filepath, "scandir OS path")
    return scan_handle
  end)
  t:patch_table(vim.uv, "fs_scandir_next", function(handle)
    t.assert_eq(scan_handle, handle, "scandir handle")
    scan_count = scan_count + 1
    if scan_count == 1 then
      return "alias", "link"
    end
    return nil
  end)

  normalize_calls = 0
  from_os_calls = 0
  to_os_calls = 0
  canonical_descendant_calls = 0

  local resolved = FileManager.new({ name = "test", show_hidden = true }):resolve_root_alias(root, target)

  t.assert_eq("C:/workspace/alias/file", resolved)
  t.assert_eq(0, normalize_calls, "canonical ingress normalization")
  t.assert_eq(3, from_os_calls, "realpath OS conversion")
  t.assert_eq(3, to_os_calls, "filesystem input OS conversion")
  t.assert_eq(2, canonical_descendant_calls, "canonical descendant checks")
end)

t:test("sync_watches: reports each watch-limit transition once", function()
  local warnings = 0 ---@type integer
  local within_limit = {} ---@type string[]
  local over_limit = {} ---@type string[]

  for index = 1, 50 do
    within_limit[index] = string.format("/project/dir-%d/", index)
    over_limit[index] = within_limit[index]
  end
  over_limit[51] = "/project/dir-51/"

  t:patch_table(FileManager, "__start_watch__", function() end)
  t:patch_table(stl.reporter, "warn", function()
    warnings = warnings + 1
  end)

  local manager = FileManager.new({ name = "test" })
  manager:sync_watches(over_limit)
  manager:sync_watches(over_limit)
  t.assert_eq(1, warnings, "persistent over-limit state")

  manager:sync_watches(within_limit)
  manager:sync_watches(over_limit)
  t.assert_eq(2, warnings, "new over-limit transition")

  manager:pause_watch()
  manager:sync_watches(over_limit)
  t.assert_eq(3, warnings, "transition after watches resume")
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

  local status = FileManager.new({ name = "test" }):copy(node.filepath, copied .. "/")

  t.assert_eq("success", status, "copy status")
  t.assert_eq("link", vim.uv.fs_lstat(copied).type, "copy should remain a symlink")
  t.assert_eq("target", vim.uv.fs_readlink(copied), "link target")
  t.assert_true(vim.uv.fs_stat(target .. "/sentinel") ~= nil, "target should remain")
  vim.fn.delete(root, "rf")
end)

t:test("copy: reuses scandir types for regular descendants", function()
  local root = canonical_tempname() ---@type string
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

  local status = FileManager.new({ name = "test" }):copy(source .. "/", target .. "/")

  t.assert_eq("success", status, "copy status")
  t.assert_eq(2, lstat_calls, "only target existence and source identity should use lstat")
  t.assert_true(vim.uv.fs_stat(target .. "/nested/file") ~= nil, "nested file should be copied")
  t.assert_eq("content", vim.fn.readfile(target .. "/nested/file")[1], "nested file content")
  vim.fn.delete(root, "rf")
end)

t:test("copy: exclusive file copy preserves a target created after preflight", function()
  local root = canonical_tempname() ---@type string
  local source = root .. "/source" ---@type string
  local target = root .. "/target" ---@type string
  vim.fn.mkdir(root, "p")
  vim.fn.writefile({ "source" }, source)
  local fs_open = vim.uv.fs_open

  t:patch_table(vim.uv, "fs_open", function(filepath, flags, mode)
    if filepath == to_os(target) and flags == "wx" then
      vim.fn.writefile({ "sentinel" }, filepath)
    end
    return fs_open(filepath, flags, mode)
  end)

  local status = FileManager.new({ name = "test" }):copy(source, target)

  t.assert_eq("partial_failure", status, "copy status")
  t.assert_eq("sentinel", vim.fn.readfile(target)[1], "concurrent target content")
  vim.fn.delete(root, "rf")
end)

t:test("copy: exclusive target open failure without a target remains retryable", function()
  local root = canonical_tempname() ---@type string
  local source = root .. "/source" ---@type string
  local target = root .. "/target" ---@type string
  vim.fn.mkdir(root, "p")
  vim.fn.writefile({ "source" }, source)

  local fs_open = vim.uv.fs_open
  t:patch_table(vim.uv, "fs_open", function(filepath, flags, mode)
    if filepath == to_os(target) and flags == "wx" then
      return nil, "injected open failure", "EIO"
    end
    return fs_open(filepath, flags, mode)
  end)

  local status = FileManager.new({ name = "test" }):copy(source, target)

  t.assert_eq("retryable_failure", status, "copy status")
  t.assert_nil(vim.uv.fs_lstat(target), "target should not exist")
  vim.fn.delete(root, "rf")
end)

t:test("copy: transfer failure leaves the partial target visible", function()
  local root = canonical_tempname() ---@type string
  local source = root .. "/source" ---@type string
  local target = root .. "/target" ---@type string
  vim.fn.mkdir(root, "p")
  vim.fn.writefile({ "source" }, source)

  local fs_sendfile = vim.uv.fs_sendfile
  local send_count = 0 ---@type integer
  t:patch_table(vim.uv, "fs_sendfile", function(out_fd, in_fd, offset, size)
    send_count = send_count + 1
    if send_count == 1 then
      return fs_sendfile(out_fd, in_fd, offset, math.min(size, 3))
    end
    return nil, "injected copy failure", "EIO"
  end)

  local status = FileManager.new({ name = "test" }):copy(source, target)

  t.assert_eq("partial_failure", status, "copy status")
  t.assert_eq("sou", vim.fn.readfile(target)[1], "partial target content")
  vim.fn.delete(root, "rf")
end)

t:test("copy: premature transfer EOF is not reported as success", function()
  local root = canonical_tempname() ---@type string
  local source = root .. "/source" ---@type string
  local target = root .. "/target" ---@type string
  vim.fn.mkdir(root, "p")
  vim.fn.writefile({ "source" }, source)

  t:patch_table(vim.uv, "fs_sendfile", function()
    return 0
  end)

  local status = FileManager.new({ name = "test" }):copy(source, target)

  t.assert_eq("partial_failure", status, "copy status")
  t.assert_true(vim.uv.fs_lstat(target) ~= nil, "partial target should remain")
  vim.fn.delete(root, "rf")
end)

t:test("copy: target close failure does not delete a concurrent replacement", function()
  local root = canonical_tempname() ---@type string
  local source = root .. "/source" ---@type string
  local target = root .. "/target" ---@type string
  vim.fn.mkdir(root, "p")
  vim.fn.writefile({ "source" }, source)
  local fs_close = vim.uv.fs_close
  local fs_open = vim.uv.fs_open
  local target_fd = nil ---@type integer|nil

  t:patch_table(vim.uv, "fs_open", function(filepath, flags, mode)
    local fd, err, code = fs_open(filepath, flags, mode)
    if filepath == to_os(target) and flags == "wx" then
      target_fd = fd
    end
    return fd, err, code
  end)
  t:patch_table(vim.uv, "fs_close", function(fd)
    if fd ~= target_fd then
      return fs_close(fd)
    end

    assert(fs_close(fd))
    assert(vim.uv.fs_unlink(target))
    local replacement_fd = assert(fs_open(target, "wx", 438)) ---@type integer
    assert(vim.uv.fs_write(replacement_fd, "sentinel", 0))
    assert(fs_close(replacement_fd))
    return nil, "injected close failure", "EIO"
  end)

  local status = FileManager.new({ name = "test" }):copy(source, target)

  t.assert_eq("partial_failure", status, "copy status")
  t.assert_eq("sentinel", vim.fn.readfile(target)[1], "replacement content")
  vim.fn.delete(root, "rf")
end)

t:test("copy: missing source with a concurrent target is not retryable", function()
  local root = canonical_tempname() ---@type string
  local source = root .. "/missing" ---@type string
  local target = root .. "/target" ---@type string
  vim.fn.mkdir(root, "p")
  vim.fn.writefile({ "sentinel" }, target)

  local status = FileManager.new({ name = "test" }):copy(source, target)

  t.assert_eq("partial_failure", status, "copy status")
  t.assert_eq("sentinel", vim.fn.readfile(target)[1], "concurrent target content")
  vim.fn.delete(root, "rf")
end)

t:test("copy: exclusive directory create does not merge a concurrent target", function()
  local root = canonical_tempname() ---@type string
  local source = root .. "/source" ---@type string
  local target = root .. "/target" ---@type string
  vim.fn.mkdir(source, "p")
  vim.fn.writefile({ "source" }, source .. "/file")
  local fs_mkdir = vim.uv.fs_mkdir

  t:patch_table(vim.uv, "fs_mkdir", function(filepath, mode)
    if filepath == to_os(target) then
      assert(fs_mkdir(filepath, mode))
      vim.fn.writefile({ "sentinel" }, filepath .. "/sentinel")
    end
    return fs_mkdir(filepath, mode)
  end)

  local status = FileManager.new({ name = "test" }):copy(source .. "/", target .. "/")

  t.assert_eq("partial_failure", status, "copy status")
  t.assert_eq("sentinel", vim.fn.readfile(target .. "/sentinel")[1], "concurrent target content")
  t.assert_nil(vim.uv.fs_lstat(target .. "/file"), "source content should not be merged")
  vim.fn.delete(root, "rf")
end)

t:test("copy: scandir failure after target creation reports partial failure", function()
  local root = canonical_tempname() ---@type string
  local source = root .. "/source" ---@type string
  local target = root .. "/target" ---@type string
  vim.fn.mkdir(source, "p")
  local fs_scandir = vim.uv.fs_scandir

  t:patch_table(vim.uv, "fs_scandir", function(filepath)
    if filepath == to_os(source) then
      return nil, "injected scan failure", "EIO"
    end
    return fs_scandir(filepath)
  end)

  local status = FileManager.new({ name = "test" }):copy(source .. "/", target .. "/")

  t.assert_eq("partial_failure", status, "copy status")
  t.assert_true(vim.uv.fs_lstat(target) ~= nil, "target directory should remain")
  vim.fn.delete(root, "rf")
end)

t:test("copy: scandir iteration failure reports partial failure", function()
  local root = canonical_tempname() ---@type string
  local source = root .. "/source" ---@type string
  local target = root .. "/target" ---@type string
  vim.fn.mkdir(source, "p")

  t:patch_table(vim.uv, "fs_scandir_next", function()
    return nil, "injected scan failure", "EIO"
  end)

  local status = FileManager.new({ name = "test" }):copy(source .. "/", target .. "/")

  t.assert_eq("partial_failure", status, "copy status")
  t.assert_true(vim.uv.fs_lstat(target) ~= nil, "target directory should remain")
  vim.fn.delete(root, "rf")
end)

t:test("copy: recursive child failure promotes the directory result to partial", function()
  local root = canonical_tempname() ---@type string
  local source = root .. "/source" ---@type string
  local target = root .. "/target" ---@type string
  vim.fn.mkdir(source, "p")
  vim.fn.writefile({ "source" }, source .. "/file")

  t:patch_table(vim.uv, "fs_sendfile", function()
    return nil, "injected copy failure", "EIO"
  end)

  local status = FileManager.new({ name = "test" }):copy(source .. "/", target .. "/")

  t.assert_eq("partial_failure", status, "copy status")
  t.assert_true(vim.uv.fs_lstat(target) ~= nil, "target directory should remain")
  t.assert_true(vim.uv.fs_lstat(target .. "/file") ~= nil, "failed child target should remain visible")
  vim.fn.delete(root, "rf")
end)

t:test("copy: rejects a directory target inside the source before writing", function()
  local root = canonical_tempname() ---@type string
  local source = root .. "/source" ---@type string
  local target = source .. "/nested/copy" ---@type string
  vim.fn.mkdir(source, "p")
  vim.fn.writefile({ "sentinel" }, source .. "/sentinel")

  local status = FileManager.new({ name = "test" }):copy(source .. "/", target .. "/")

  t.assert_eq("retryable_failure", status, "copy status")
  t.assert_nil(vim.uv.fs_lstat(source .. "/nested"), "target parent should not be created")
  t.assert_true(vim.uv.fs_stat(source .. "/sentinel") ~= nil, "source should remain unchanged")
  vim.fn.delete(root, "rf")
end)

t:test("copy: rejects a filesystem descendant before writing", function()
  local root = canonical_tempname() ---@type string
  local source = root .. "/source" ---@type string
  local target = root .. "/alias/nested/copy" ---@type string
  vim.fn.mkdir(source, "p")
  vim.fn.writefile({ "sentinel" }, source .. "/sentinel")

  fs_descendant_result = true
  local copied = FileManager.new({ name = "test" }):copy(source .. "/", target .. "/")
  fs_descendant_result = false

  t.assert_eq("retryable_failure", copied, "copy status")
  t.assert_nil(vim.uv.fs_lstat(root .. "/alias"), "target parent should not be created")
  t.assert_true(vim.uv.fs_stat(source .. "/sentinel") ~= nil, "source should remain unchanged")
  vim.fn.delete(root, "rf")
end)

t:test("copy: rejects an unresolved filesystem descendant check", function()
  local root = canonical_tempname() ---@type string
  local source = root .. "/source" ---@type string
  local target = root .. "/target/copy" ---@type string
  vim.fn.mkdir(source, "p")
  vim.fn.writefile({ "sentinel" }, source .. "/sentinel")

  fs_descendant_result = nil
  fs_descendant_error = "permission denied"
  local copied = FileManager.new({ name = "test" }):copy(source .. "/", target .. "/")
  fs_descendant_result = false
  fs_descendant_error = nil

  t.assert_eq("retryable_failure", copied, "copy status")
  t.assert_nil(vim.uv.fs_lstat(root .. "/target"), "target should not be created")
  t.assert_true(vim.uv.fs_stat(source .. "/sentinel") ~= nil, "source should remain unchanged")
  vim.fn.delete(root, "rf")
end)

t:test("remove with trash: passes a slash-free symlink path to the native tool", function()
  local root, target, link = create_directory_link_fixture()
  local node = load_link_node(root)
  local command = nil ---@type string[]|nil
  use_trash = true

  t:patch_table(stl.env, "IS_OSX", true)
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
