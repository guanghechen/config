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
local Fileicon = {
  get_file_icon = function()
    return "", "", false
  end,
}

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
  stl = {
    fileicon = Fileicon,
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

t:test("render: defers file icons and applies exact icons by byte range", function()
  local calls = {} ---@type string[]
  t:patch_table(Fileicon, "get_file_icon", function(_, filetype)
    calls[#calls + 1] = filetype == nil and "<nil>" or filetype
    if filetype == "" then
      return "󰈚", "IconFallback", false
    end
    return "", "IconExact", false
  end)

  local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  local view = View.new("deferred-file-icon-test")
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

  local result = view:render(bufnr, tree, root, {
    defer_file_icons = true,
    show_diagnostics = false,
    show_git_status = false,
    show_icons = true,
  })

  t.assert_eq(1, #calls, "initial icon lookup count")
  t.assert_eq("", calls[1], "initial lookup should bypass filetype detection")
  t.assert_eq(1, #result.deferred_file_icons, "deferred icon count")
  t.assert_eq("╰─󰈚 file.lua", result.lines[1], "fallback line")

  view:update_file_icons(bufnr, result, 1, 1)

  t.assert_eq(2, #calls, "exact icon lookup count")
  t.assert_eq("<nil>", calls[2], "deferred lookup should use normal filetype detection")
  t.assert_eq("╰─ file.lua", result.lines[1], "resolved result line")
  local buffer_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false) ---@type string[]
  t.assert_eq(#result.lines, #buffer_lines, "resolved buffer line count")
  t.assert_eq(result.lines[1], buffer_lines[1], "resolved buffer line")
  t.assert_eq(false, vim.api.nvim_get_option_value("modifiable", { buf = bufnr }), "modifiable restored")

  local main_extmarks = vim.api.nvim_buf_get_extmarks(bufnr, view:get_namespace(), 0, -1, { details = true })
  local name_start = nil ---@type integer|nil
  for _, extmark in ipairs(main_extmarks) do
    if extmark[4].hl_group == "m_ft_filename" then
      name_start = extmark[3]
      break
    end
  end
  t.assert_eq(#("╰─" .. "" .. " "), name_start, "name highlight should follow the resolved icon")

  local icon_extmarks = vim.api.nvim_buf_get_extmarks(bufnr, view._file_icon_nsnr, 0, -1, { details = true })
  t.assert_eq(1, #icon_extmarks, "icon highlight count")
  t.assert_eq("IconExact", icon_extmarks[1][4].hl_group, "resolved icon highlight")
  t.assert_eq(#"╰─", icon_extmarks[1][3], "icon start column")
  t.assert_eq(#("╰─" .. "" .. " "), icon_extmarks[1][4].end_col, "icon end column")

  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("file icons: restores modifiable when a buffer update fails", function()
  t:patch_table(Fileicon, "get_file_icon", function(_, filetype)
    if filetype == "" then
      return "󰈚", "IconFallback", false
    end
    return "", "IconExact", false
  end)

  local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  local view = View.new("deferred-file-icon-failure-test")
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

  local result = view:render(bufnr, tree, root, {
    defer_file_icons = true,
    show_diagnostics = false,
    show_git_status = false,
    show_icons = true,
  })
  t:patch_table(vim.api, "nvim_buf_set_text", function()
    error("injected icon update failure")
  end)

  local ok = pcall(view.update_file_icons, view, bufnr, result, 1, 1) ---@type boolean

  t.assert_false(ok, "icon update should propagate the failure")
  t.assert_false(vim.api.nvim_get_option_value("modifiable", { buf = bufnr }), "modifiable should be restored")
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:run()
