local t = require("__test__.support.harness").new()
local root = assert(vim.uv.cwd()) ---@type string

---Runs `init-debug-lsp.lua` in a child over a file list with nothing readable, so it writes an empty report to
---`output` and exits. The child starts outside any repository, with its state, data and cache in a temporary directory.
---@param output                        string
---@return vim.SystemCompleted
local function check(output)
  local home = t:tempdir()
  return vim
    .system({
      vim.v.progpath,
      "--headless",
      "-u",
      "NONE",
      "-i",
      "NONE",
      "-n",
      "--cmd",
      "set runtimepath^=" .. root,
      "-c",
      "lua FILE_PATHS = { '" .. home .. "/missing.lua' }",
      "-c",
      "lua OUTPUT_FILE = '" .. output .. "'",
      "-c",
      "luafile " .. root .. "/init-debug-lsp.lua",
    }, {
      cwd = home,
      env = { XDG_STATE_HOME = home .. "/state", XDG_DATA_HOME = home .. "/data", XDG_CACHE_HOME = home .. "/cache" },
      text = true,
      -- A check that keeps running after a failure times out here with code 124, within the suite's own limit.
      timeout = 10000,
    })
    :wait()
end

t:test("an LSP check that cannot write its report exits non-zero rather than keep running", function()
  local dir = t:tempdir()
  local readonly = dir .. "/readonly"
  vim.fn.mkdir(readonly, "p")
  vim.uv.fs_chmod(readonly, tonumber("555", 8))
  t:defer(function()
    vim.uv.fs_chmod(readonly, tonumber("755", 8))
  end)

  local written = check(dir .. "/report/out.json")
  t.assert_eq(0, written.code, written.stderr)
  t.assert_true(vim.uv.fs_stat(dir .. "/report/out.json") ~= nil, "report written")
  -- One output cannot be written in its folder, the other cannot have its folder created.
  for _, output in ipairs({ readonly .. "/out.json", readonly .. "/report/out.json" }) do
    local failed = check(output)
    t.assert_eq(1, failed.code, output .. ": " .. failed.stderr)
  end
end)

t:run()
