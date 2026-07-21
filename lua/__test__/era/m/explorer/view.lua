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
          preload_ignored = function() end,
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

t:test("render: writes range highlights directly as extmarks", function()
  t:patch_table(vim.hl, "range", function()
    error("vim.hl.range() must not be used")
  end)

  local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  local view = View.new("highlight-extmark-test")
  local child = {
    filepath = "/project/file.lua",
    nodename = "file.lua",
    nodetype = "F",
  } ---@type era.m.explorer.Node
  local root = {
    filepath = "/project/",
    nodename = "project",
    nodetype = "D",
    expanded = true,
    loaded = true,
    children = { child },
  } ---@type era.m.explorer.Node
  local tree = {
    ticks = { structure = 1 },
    is_selected = function()
      return false
    end,
  } ---@type era.m.explorer.Tree

  view:render(bufnr, tree, root, {
    show_diagnostics = false,
    show_git_status = false,
    show_icons = false,
  })

  local extmarks = vim.api.nvim_buf_get_extmarks(bufnr, view:get_namespace(), 0, -1, { details = true })
  local highlight_extmarks = {} ---@type any[]
  for _, extmark in ipairs(extmarks) do
    if extmark[4].hl_group ~= nil then
      highlight_extmarks[#highlight_extmarks + 1] = extmark
    end
  end

  t.assert_eq(2, #highlight_extmarks, "range highlight count")
  t.assert_eq("m_ex_indent", highlight_extmarks[1][4].hl_group, "indent highlight")
  t.assert_eq(0, highlight_extmarks[1][3], "indent start column")
  t.assert_eq(6, highlight_extmarks[1][4].end_col, "indent end column")
  t.assert_eq("m_ft_filename", highlight_extmarks[2][4].hl_group, "name highlight")
  t.assert_eq(6, highlight_extmarks[2][3], "name start column")
  t.assert_eq(14, highlight_extmarks[2][4].end_col, "name end column")

  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:run()
