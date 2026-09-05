--- Run with: nvim -l __test__/run.lua __test__/specs/stl/git/browse_spec.lua
---@diagnostic disable: undefined-global
--- Test for stl.git.browse module

local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")

local t = harness.new("stl.git.browse")

local normalize_sep = nil ---@type string|nil
local relative_args = nil ---@type { from: string, to: string, keep: boolean, sep: string }|nil

bootstrap.with_runtime(t, {
  stl = {
    env = { PATH_SEP = "\\" },
    git = {},
    reporter = { error = function() end },
  },
  yoz = {
    path = {
      normalize = function(filepath, _, sep)
        normalize_sep = sep
        return filepath
      end,
      relative = function(from, to, keep, sep)
        relative_args = { from = from, to = to, keep = keep, sep = sep }
        return "lua/era/m/im/wsl.lua"
      end,
    },
  },
})

local Browse = require("stl.git.browse")

t:test("open uses Git separators for Windows remote paths", function()
  local filepath = [[C:\repo\lua\era\m\im\wsl.lua]]
  local fields_opts = nil ---@type stl.git.browse.IBuildFieldsOpts|nil
  local opened = nil ---@type stl.git.browse.IRemote|nil

  t:patch_table(vim.api, "nvim_get_current_buf", function()
    return 1
  end)
  t:patch_table(vim.api, "nvim_buf_get_name", function()
    return filepath
  end)
  t:patch_table(vim.uv, "fs_stat", function()
    return { type = "file" }
  end)
  t:patch_table(Browse, "build_fields", function(opts)
    fields_opts = opts
    return { cwd = opts.cwd, scope = "file", line_start = 1, line_end = 1 }
  end)
  t:patch_table(Browse, "get_remotes", function()
    return { { name = "origin", url = "https://example.com/repo/blob/main/lua/era/m/im/wsl.lua" } }
  end)
  t:patch_table(Browse, "open_remote", function(remote)
    opened = remote
  end)

  Browse.open({ cwd = [[C:\repo]], commit = "abcdef0", line_start = 1, line_end = 1 })

  t.assert_eq("\\", normalize_sep, "filesystem separator")
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_eq([[C:\repo]], relative_args.from, "relative path root")
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_eq(filepath, relative_args.to, "relative path target")
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_false(relative_args.keep, "relative path trailing slash")
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_eq("/", relative_args.sep, "relative path separator")
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_eq("lua/era/m/im/wsl.lua", fields_opts.file, "remote Git path")
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_eq("origin", opened.name, "remote opened")
end)

t:run()
