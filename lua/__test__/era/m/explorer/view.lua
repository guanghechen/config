---@diagnostic disable: undefined-global
--- Test for era.m.explorer.view
--- Run with: nvim -l lua/__test__/era/m/explorer/view.lua

local bootstrap = require("__test__.bootstrap")
local harness = require("__test__.harness")

local t = harness.new("era.m.explorer.view")

local function normalize(filepath, keep_trailing_slash)
  local normalized = filepath:gsub("\\", "/"):gsub("/+", "/") ---@type string
  if keep_trailing_slash == false and normalized ~= "/" then
    normalized = normalized:gsub("/+$", "")
  end
  return normalized
end

local GitStatus = require("era.m.git.status")

bootstrap.with_runtime(t, {
  dot = {
    path = {
      normalize = normalize,
    },
  },
  era = {
    m = {
      git = {
        state = {
          aggregated = function()
            return { status_table = {} }
          end,
          is_ignored = function()
            return false
          end,
        },
        status = GitStatus,
      },
    },
  },
})

local View = require("era.m.explorer.view")

t:test("render node: resolves Git status once", function()
  local resolve_calls = 0 ---@type integer
  t:patch_table(GitStatus, "resolve", function()
    resolve_calls = resolve_calls + 1
    return "M", "m_ft_git_change"
  end)

  local view = View.new("git-resolve-test")
  local node = {
    filepath = "/project/file.lua",
    nodename = "file.lua",
    nodetype = "F",
  } ---@type era.m.explorer.Node
  local ctx = {
    diag_counts = {},
    show_diagnostics = false,
    show_git_status = true,
    show_icons = false,
  } ---@type era.m.explorer.view.IRenderContext

  local _, highlights, git_info = view:__render_node__(ctx, node, "", 1, nil, false, false)

  t.assert_eq(1, resolve_calls, "resolve count")
  t.assert_eq("m_ft_git_change", highlights[1].hlname, "node name highlight")
  t.assert_true(git_info ~= nil, "Git status info")
  t.assert_eq(" M", git_info.text, "Git status text")
end)

t:run()
