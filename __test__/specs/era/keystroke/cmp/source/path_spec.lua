local harness = require("__test__.support.harness")
local runtime = require("__test__.support.cmp.runtime")
local fixture = require("__test__.support.cmp.fixture")
runtime.setup()
local t = harness.new()
local Path = require("era.keystroke.cmp.source.path")

t:test("path parsing distinguishes workspace references and file-relative paths", function()
  t:patch_table(dot.path, "cwd", function()
    return "/workspace"
  end)
  local target = assert(Path.target(runtime.context("review @lua/era/cm")))
  t.assert_eq("/workspace/lua/era", target.dirname, "workspace directory")
  t.assert_eq(#"review @lua/era/", target.start_col, "basename start")
  t.assert_eq("path_at", target.source, "source label")
  target = assert(Path.target(runtime.context('"./folder with space/fi')))
  t.assert_true(target.dirname:match("folder with space$") ~= nil, "quoted space")
  t.assert_eq(nil, Path.target(runtime.context("object.member")), "ordinary identifier")
  for _, quote in ipairs({ '"', "'", "`" }) do
    t.assert_nil(Path.target(runtime.context("local text = " .. quote .. "word")), "plain quoted text")
  end
end)

t:test("path parsing after a long token stays fast", function()
  local token = fixture.base64(16 * 1024)
  t.assert_nil(Path.target(runtime.context("![img](data:image/png;base64," .. token .. ") w")), "no path")
  local target = assert(Path.target(runtime.context(token .. ") ./lua/era/cm")))
  t.assert_eq(#token + #") ./lua/era/", target.start_col, "start of the basename")
end)

t:test("path targets reject invalid UTF-8 origins without invoking native path conversion", function()
  local bufnr = fixture.buffer(t, { "" })
  t.assert_eq(nil, Path.target(runtime.context('"/tmp/\255/a')), "typed directory")
  vim.api.nvim_buf_set_name(bufnr, "/tmp/\255/current.lua")
  t.assert_eq(nil, Path.target(runtime.context('"./a')), "buffer filename")
  vim.api.nvim_buf_set_name(bufnr, "")
  t:patch_table(dot.path, "cwd", function()
    return "/tmp/\255"
  end)
  t.assert_eq(nil, Path.target(runtime.context("@a")), "workspace directory")
  t:patch_table(dot.path, "cwd", function()
    return "/workspace"
  end)
  t:patch_table(vim.env, "CMP_UTF8_TARGET", "/tmp/\255")
  t.assert_eq(nil, Path.target(runtime.context('"$CMP_UTF8_TARGET/a')), "expanded environment directory")
  t.assert_eq("/workspace", assert(Path.target(runtime.context("@a"))).dirname, "valid targets remain usable")
end)

t:test("directory scans skip invalid UTF-8 file and symlink names while preserving valid entries", function()
  local directory = t:tempdir()
  vim.fn.mkdir(directory .. "/child", "p")
  vim.fn.writefile({}, directory .. "/alpha.txt")
  -- APFS refuses names that are not UTF-8; such names only exist on byte-oriented filesystems.
  local written, err = pcall(vim.fn.writefile, {}, directory .. "/a\255.txt")
  if not written and tostring(err):find("illegal byte sequence", 1, true) then
    t.skip("the filesystem refuses names that are not UTF-8")
  end
  assert(written, err)
  assert(vim.uv.fs_symlink(directory .. "/child", directory .. "/linked"))
  assert(vim.uv.fs_symlink(directory .. "/child", directory .. "/l\255"))
  local result
  t:defer(Path.complete(runtime.context('"' .. directory .. "/a"), function(response)
    result = response
  end))
  t.wait_until(function()
    return result ~= nil
  end, 5000, "directory scan completes despite invalid names")
  t.assert_eq(false, result.incomplete, "scan reaches the end and settles pending stats")
  local labels = {}
  for _, item in ipairs(result.items) do
    labels[#labels + 1] = item.raw.label
  end
  table.sort(labels)
  t.assert_eq("alpha.txt,child/,linked/", table.concat(labels, ","), "valid files and symlinks survive")
end)

t:test("directory scans include late entries and resolve symlink directories", function()
  local directory = t:tempdir()
  for index = 1, 225 do
    vim.fn.writefile({}, directory .. "/item" .. index)
  end
  vim.fn.mkdir(directory .. "/child")
  assert(vim.uv.fs_symlink(directory .. "/child", directory .. "/linked"))
  t:patch_table(dot.path, "cwd", function()
    return directory
  end)
  local result
  local cancel = Path.complete(runtime.context("@"), function(response)
    result = response
  end)
  t:defer(cancel)
  t.wait_until(function()
    return result ~= nil
  end, 5000, "asynchronous directory result")
  t.assert_eq(false, result.incomplete, "full directory")
  t.assert_eq(227, #result.items, "no truncation before filtering")
  local linked = false
  for _, item in ipairs(result.items) do
    linked = linked or item.raw.label == "linked/"
  end
  t.assert_true(linked, "directory symlink")
end)

t:test("cancelled path scans never publish and the same context can retry", function()
  local directory = t:tempdir()
  t:patch_table(dot.path, "cwd", function()
    return directory
  end)
  local calls = 0
  local context = runtime.context("@")
  local cancel = Path.complete(context, function()
    calls = calls + 1
  end)
  cancel()
  cancel()
  vim.wait(30)
  t.assert_eq(0, calls, "cancelled callback")
  local retry = Path.complete(context, function()
    calls = calls + 1
  end)
  t:defer(retry)
  t.wait_until(function()
    return calls == 1
  end, 5000, "retry")
end)

t:test("path documentation reads regular files and skips current FIFO targets", function()
  local directory = t:tempdir()
  vim.fn.writefile({ "preview body" }, directory .. "/regular.txt")
  vim.fn.writefile({}, directory .. "/changed")
  local created = vim.system({ "mkfifo", directory .. "/pipe" }):wait()
  t.assert_eq(0, created.code, created.stderr)
  assert(vim.uv.fs_symlink(directory .. "/pipe", directory .. "/pipe_link"))
  assert(vim.uv.fs_symlink(directory .. "/regular.txt", directory .. "/regular_link"))
  t:patch_table(dot.path, "cwd", function()
    return directory
  end)
  local result
  t:defer(Path.complete(runtime.context("@"), function(response)
    result = response
  end))
  t.wait_until(function()
    return result ~= nil
  end, 5000, "file and FIFO candidates")
  t.assert_eq(5, #result.items, "special files remain selectable")
  assert(vim.uv.fs_unlink(directory .. "/changed"))
  created = vim.system({ "mkfifo", directory .. "/changed" }):wait()
  t.assert_eq(0, created.code, created.stderr)
  local regular = { [directory .. "/regular.txt"] = true, [directory .. "/regular_link"] = true }
  local invalid_opens = 0
  local open = vim.uv.fs_open
  t:patch_table(vim.uv, "fs_open", function(path, flags, mode, callback)
    if not regular[path] then
      invalid_opens = invalid_opens + 1
      -- Keep a regression from hanging the test process in a real blocking FIFO open.
      callback("fixture rejects non-file read")
      return nil
    end
    return open(path, flags, mode, callback)
  end)
  for _, item in ipairs(result.items) do
    local resolved
    local cancel = Path.resolve(item, function(raw)
      resolved = raw
    end)
    if cancel ~= nil then
      t:defer(cancel)
    end
    t.wait_until(function()
      return resolved ~= nil
    end, 5000, item.raw.label .. " documentation")
    if regular[item.raw.data.full_path] then
      t.assert_true(resolved.documentation.value:find("preview body", 1, true) ~= nil, "regular file content")
    else
      t.assert_eq(item.raw, resolved, "non-file response is unchanged")
    end
  end
  t.assert_eq(0, invalid_opens, "no FIFO is opened, including replaced files and symlinks")
  local calls = 0
  local cancel = Path.resolve(result.items[1], function()
    calls = calls + 1
  end)
  assert(cancel)()
  vim.wait(20)
  t.assert_eq(0, calls, "cancellation before stat returns does not publish")
end)

t:run()
