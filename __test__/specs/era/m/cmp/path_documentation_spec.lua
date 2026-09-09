local harness = require("__test__.support.harness")
local suite = harness.new("era.m.cmp.path_documentation")
local documentation = require("era.m.cmp.path_documentation")

---@param contents                      string
---@param name                          ?string
---@return string, string
local function fixture(contents, name)
  local directory = vim.fn.tempname()
  vim.fn.mkdir(directory, "p")
  directory = assert(vim.uv.fs_realpath(directory))
  suite:defer(function()
    vim.fn.delete(directory, "rf")
  end)
  local filepath = directory .. "/" .. (name or "sample.lua")
  local descriptor = assert(vim.uv.fs_open(filepath, "w", 384))
  suite:defer(function()
    if descriptor ~= nil then
      vim.uv.fs_close(descriptor)
    end
  end)
  assert(vim.uv.fs_write(descriptor, contents, 0))
  assert(vim.uv.fs_close(descriptor))
  descriptor = nil
  return filepath, directory
end

---@param filepath                      string
---@return string|nil
local function request(filepath)
  local ready = false
  local result
  local cancel = documentation.request(filepath, function(value)
    ready = true
    result = value
  end)
  suite:defer(cancel)
  suite.assert_true(
    vim.wait(1000, function()
      return ready
    end, 1),
    "documentation settles"
  )
  return result
end

suite:test("selected files read one bounded prefix and close their descriptor", function()
  local filepath = fixture(string.rep("a", 2048))
  suite:patch_table(vim.filetype, "match", function()
    error("preview must not invoke content-probing filetype handlers")
  end)
  local read = vim.uv.fs_read
  local close = vim.uv.fs_close
  local reads = 0
  local closes = 0
  suite:patch_table(vim.uv, "fs_read", function(descriptor, bytes, offset, callback)
    reads = reads + 1
    suite.assert_eq(1024, bytes, "bounded read size")
    suite.assert_eq(0, offset, "prefix only")
    return read(descriptor, bytes, offset, callback)
  end)
  suite:patch_table(vim.uv, "fs_close", function(...)
    closes = closes + 1
    return close(...)
  end)
  suite.assert_eq("```lua\n" .. string.rep("a", 1024) .. "\n```", request(filepath), "bounded fenced preview")
  suite.assert_eq(1, reads, "one content read")
  suite.assert_eq(1, closes, "descriptor closed once")
end)

suite:test("binary files and truncated UTF-8 do not corrupt documentation", function()
  suite.assert_eq("Binary file", request(fixture("binary\0data")), "binary detection")
  local filepath = fixture(string.rep("a", 1022) .. "你", "unicode.txt")
  local text = request(filepath)
  suite.assert_true(text:find(string.rep("a", 1022) .. "\n```", 1, true) ~= nil, "incomplete final codepoint removed")
  suite.assert_true(text:find("你", 1, true) == nil, "partial codepoint not expanded beyond read budget")
end)

suite:test("literal Markdown fences cannot terminate the preview early", function()
  local filepath = fixture("```lua\nreturn 1\n```", "sample.md")
  suite.assert_eq("````markdown\n```lua\nreturn 1\n```\n````", request(filepath), "content fences remain literal")
end)

suite:test("sensitive paths are rejected before any filesystem access", function()
  suite:patch_table(vim.uv, "fs_lstat", function()
    error("sensitive path must not reach filesystem IO")
  end)
  for _, filepath in ipairs({
    "/never/.ssh/key",
    "/never/.env",
    "/never/.env.production",
    "/never/local/env.lua",
    "/never/.git-credentials",
    "/never/request.http_request",
    "/never/response.http_response",
    "/never/credentials.json",
    "/never/secrets.yaml",
    "/never/key.pem",
    "/never/.npmrc",
    "/never/../file.lua",
    "relative.lua",
  }) do
    suite.assert_nil(request(filepath), filepath .. " is not previewable")
  end
end)

suite:test("directories, symbolic-link components, and hard links are not read", function()
  local filepath, directory = fixture("ordinary text")
  assert(vim.uv.fs_symlink(filepath, directory .. "/link.lua"))
  assert(vim.uv.fs_mkdir(directory .. "/child", 448))
  vim.fn.writefile({ "child" }, directory .. "/child/file.lua", "b")
  assert(vim.uv.fs_symlink(directory .. "/child", directory .. "/alias"))
  suite:patch_table(vim.uv, "fs_open", function()
    error("non-regular path must not be opened")
  end)
  suite.assert_nil(request(directory), "directory skipped")
  suite.assert_nil(request(directory .. "/link.lua"), "leaf symlink skipped")
  suite.assert_nil(request(directory .. "/alias/file.lua"), "parent symlink skipped")
  assert(vim.uv.fs_link(filepath, directory .. "/hard.lua"))
  suite.assert_nil(request(filepath), "hard-linked file skipped")
end)

suite:test("an identity change between inspection and open prevents content reads", function()
  local filepath = fixture("ordinary text")
  local fstat = vim.uv.fs_fstat
  suite:patch_table(vim.uv, "fs_fstat", function(descriptor, callback)
    return fstat(descriptor, function(err, stat)
      if stat ~= nil then
        stat.ino = stat.ino + 1
      end
      callback(err, stat)
    end)
  end)
  suite:patch_table(vim.uv, "fs_read", function()
    error("replaced file must not be read")
  end)
  suite.assert_nil(request(filepath), "file identity must survive opening")
end)

---@param deferred                      string
---@return table
local function deferred_io(deferred)
  local state = { closes = 0, callbacks = 0 }
  local stat = { type = "file", dev = 1, ino = 2, nlink = 1 }
  suite:patch_table(vim.uv, "fs_lstat", function(path, callback)
    callback(nil, path == "/fixture" and { type = "directory" } or stat)
  end)
  suite:patch_table(vim.uv, "fs_open", function(_, _, _, callback)
    if deferred == "open" then
      state.deliver = function()
        callback(nil, 42)
      end
    else
      callback(nil, 42)
    end
  end)
  suite:patch_table(vim.uv, "fs_fstat", function(_, callback)
    if deferred == "stat" then
      state.deliver = function()
        callback(nil, stat)
      end
    else
      callback(nil, stat)
    end
  end)
  suite:patch_table(vim.uv, "fs_read", function(_, _, _, callback)
    state.deliver = function()
      callback(nil, "return 1")
    end
  end)
  suite:patch_table(vim.uv, "fs_close", function(_, callback)
    state.closes = state.closes + 1
    callback(nil)
  end)
  return state
end

suite:test("cancellation waits for in-flight IO before releasing its descriptor", function()
  for _, stage in ipairs({ "open", "stat", "read" }) do
    local state = deferred_io(stage)
    local cancel = documentation.request("/fixture/sample.lua", function()
      state.callbacks = state.callbacks + 1
    end)
    suite:defer(cancel)
    cancel()
    suite.assert_eq(0, state.closes, stage .. " does not close a descriptor still owned by IO")
    state.deliver()
    suite.assert_eq(1, state.closes, stage .. " releases the descriptor after completion")
    suite.assert_eq(0, state.callbacks, stage .. " cannot publish after cancellation")
    cancel()
    suite.assert_eq(1, state.closes, stage .. " cleanup is idempotent")
  end
end)

suite:test("timeout publishes no content and late IO still closes exactly once", function()
  local state = deferred_io("read")
  local timeout
  suite:patch_table(vim, "defer_fn", function(callback, delay)
    suite.assert_eq(200, delay, "bounded documentation lifetime")
    timeout = callback
    return {
      is_closing = function()
        return false
      end,
      stop = function() end,
      close = function() end,
    }
  end)
  documentation.request("/fixture/sample.lua", function(value)
    suite.assert_nil(value, "timeout yields no documentation")
    state.callbacks = state.callbacks + 1
  end)
  timeout()
  suite.assert_eq(1, state.callbacks, "one timeout result")
  suite.assert_eq(0, state.closes, "read retains the descriptor until completion")
  state.deliver()
  suite.assert_eq(1, state.callbacks, "late content is suppressed")
  suite.assert_eq(1, state.closes, "late read releases its descriptor")
end)

suite:run()
