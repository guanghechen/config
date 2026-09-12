--- Run with: nvim -l __test__/run.lua __test__/specs/era/m/explorer/view_spec.lua
---@diagnostic disable: undefined-global
--- Test for era.m.explorer.view

local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")

local t = harness.new("era.m.explorer.view")
local normalize_calls = 0 ---@type integer

local function normalize(filepath, keep_trailing_slash)
  normalize_calls = normalize_calls + 1
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
          snapshot = function()
            return {
              lookup = function()
                return { codes = 4, display = "M", staged_display = "", stage = "unstaged", summary = "M" }
              end,
            }
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
  yoz = require("yoz"),
  stl = {
    env = {
      PATH_SEP = "/",
    },
    fileicon = Fileicon,
    icon = {
      symbols = {
        selection = "S",
        selection_copy = "C",
        selection_cut = "X",
      },
    },
    nvim = {
      buf = {
        get_loaded_bufnrs = function()
          return {}
        end,
      },
    },
  },
})

local View = require("era.m.explorer.view")

t:test("render node: resolves Git status once", function()
  local resolve_calls = 0 ---@type integer
  t:patch_table(GitStatus, "calc_info", function(_, _, _, highlights)
    resolve_calls = resolve_calls + 1
    highlights[1] = { coll = 0, colr = 2, hlname = "m_ft_git_change" }
    return " M", "m_ft_git_change"
  end)

  local view = View.new("git-resolve-test")
  local node = {
    filepath = "/project/file.lua",
    nodename = "file.lua",
    nodetype = "F",
  } ---@type era.m.explorer.Node
  ---@diagnostic disable-next-line: missing-fields
  local ctx = {
    diag_counts = {},
    show_diagnostics = false,
    show_git_status = true,
    show_icons = false,
  } ---@type era.m.explorer.view.IRenderContext

  normalize_calls = 0
  ---@diagnostic disable-next-line: invisible, param-type-mismatch
  local _, highlights, git_info = view:__render_node__(ctx, node, "", 1, nil, false)

  t.assert_eq(0, normalize_calls, "canonical node filepath normalization count")
  t.assert_eq(1, resolve_calls, "resolve count")
  t.assert_eq("m_ft_git_change", highlights[1].hlname, "node name highlight")
  t.assert_true(git_info ~= nil, "Git status info")
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_eq(" M", git_info.text, "Git status text")
end)

t:test("render node: clean names stay neutral while file and folder icons keep their colors", function()
  t:patch_table(stl.icon, "filetype", { Folder = "D", FolderOpen = "O", FolderEmptyOpen = "E" })
  t:patch_table(Fileicon, "get_directory_icon", function(name)
    return "L", "MiniIconsGreen", name ~= "lsp" and name ~= "queries"
  end)
  t:patch_table(Fileicon, "get_file_icon", function()
    return "F", "MiniIconsBlue", false
  end)
  local view = View.new("neutral-names-colored-icons")
  local ctx = { diag_counts = {}, show_diagnostics = false, show_git_status = false, show_icons = true }
  for _, case in ipairs({
    { name = "lsp", kind = "D", icon = "L", icon_hl = "MiniIconsGreen" },
    { name = "lsp", kind = "D", expanded = true, children = { {} }, icon = "O", icon_hl = "MiniIconsGreen" },
    { name = "queries", kind = "D", icon = "L", icon_hl = "MiniIconsGreen" },
    { name = "queries", kind = "D", expanded = true, icon = "E", icon_hl = "MiniIconsGreen" },
    { name = "ordinary", kind = "D", icon = "D", icon_hl = "m_ft_dirname" },
    { name = "ordinary", kind = "D", expanded = true, children = { {} }, icon = "O", icon_hl = "m_ft_dirname" },
    { name = "ordinary", kind = "D", expanded = true, icon = "E", icon_hl = "m_ft_dirname" },
    { name = "loading", kind = "D", expanded = true, loaded = false, icon = "O", icon_hl = "m_ft_dirname" },
    { name = "file.lua", kind = "F", icon = "F", icon_hl = "MiniIconsBlue" },
    { name = "README.md", kind = "F", icon = "F", icon_hl = "MiniIconsBlue" },
  }) do
    local node = {
      filepath = "/project/" .. case.name .. (case.kind == "D" and "/" or ""),
      nodename = case.name,
      nodetype = case.kind,
      loaded = case.loaded ~= false,
      children = case.children or {},
    }
    ---@diagnostic disable-next-line: invisible, param-type-mismatch
    local line, highlights = view:__render_node__(ctx, node, "", 1, nil, case.expanded == true)
    t.assert_eq(case.icon, line:sub(1, 1), case.name .. " icon glyph")
    t.assert_eq(case.icon_hl, highlights[1].hlname, case.name .. " icon")
    t.assert_eq("m_ft_filename", highlights[2].hlname, case.name .. " neutral name")
    t.assert_eq(highlights[1].colr, highlights[2].coll, case.name .. " separate icon/name ranges")
  end
end)

t:test("render: selection and pending transfers use signs without overriding name status", function()
  local bufnr = vim.api.nvim_create_buf(false, true)
  t:defer(function()
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)
  local children = {
    { filepath = "/project/src/", nodename = "src", nodetype = "D", selected = true, children = {} },
    { filepath = "/project/main.lua", nodename = "main.lua", nodetype = "F", selected = true },
  }
  local root = {
    filepath = "/project/",
    nodename = "project",
    nodetype = "D",
    expanded = true,
    loaded = true,
    children = children,
  }
  local tree = {
    ticks = { structure = 1 },
    is_selected = function()
      return false
    end,
  }
  local view = View.new("selection-preserves-name-status")
  for _, status in ipairs({ false, "m_ft_git_change" }) do
    local restore = t:patch_table(GitStatus, "calc_info", function(_, _, _, highlights)
      if not status then
        return "", nil
      end
      highlights[1] = { coll = 0, colr = 2, hlname = status }
      return " M", status
    end)
    for _, mode in ipairs({ "select", "copy", "move" }) do
      local pending_transfer = mode ~= "select"
          and {
            mode = mode,
            source_filepaths = { [children[1].filepath] = true, [children[2].filepath] = true },
          }
        or nil
      ---@diagnostic disable-next-line: param-type-mismatch
      local result = view:render(bufnr, tree, root, {
        show_diagnostics = false,
        show_git_status = true,
        show_icons = false,
        pending_transfer = pending_transfer,
      })
      local name_count = 0
      for _, hl in ipairs(result.highlights) do
        if hl.hlname ~= "m_ex_indent" then
          name_count = name_count + 1
          t.assert_eq(status or "m_ft_filename", hl.hlname, mode .. " name status")
        end
      end
      t.assert_eq(2, name_count, "file and directory names")
      t.assert_eq(2, #result.sign_info_list, "selection/transfer signs remain visible")
      for _, sign in ipairs(result.sign_info_list) do
        t.assert_eq(({ select = "S", copy = "C", move = "X" })[mode], sign.sign_text, mode .. " sign")
      end
    end
    restore()
  end
end)

t:test("render node: ignored, LSP and Git determine the name color in order", function()
  local ignored = false
  t:patch_table(era.m.git.state, "is_ignored", function()
    return ignored
  end)
  local git_hl = nil
  t:patch_table(GitStatus, "calc_info", function(_, _, _, highlights)
    if not git_hl then
      return "", nil
    end
    highlights[1] = { coll = 0, colr = 2, hlname = git_hl }
    return " M", git_hl
  end)
  local view = View.new("name-status-precedence")
  for _, kind in ipairs({ "F", "D" }) do
    local node = { filepath = "/project/node" .. (kind == "D" and "/" or ""), nodename = "node", nodetype = kind }
    for _, case in ipairs({
      { ignored = true, error = 1, warn = 1, git = "m_ft_git_change", expected = "m_ex_ignored" },
      { error = 1, warn = 1, git = "m_ft_git_change", expected = "f_lsp_diagnostic_error" },
      { warn = 1, git = "m_ft_git_change", expected = "f_lsp_diagnostic_warn" },
      { git = "m_ft_git_change", expected = "m_ft_git_change" },
      { hint = 1, info = 1, expected = "m_ft_filename" },
    }) do
      ignored = case.ignored == true
      git_hl = case.git
      local ctx = {
        diag_counts = {
          [node.filepath] = {
            error = case.error or 0,
            warn = case.warn or 0,
            hint = case.hint or 0,
            info = case.info or 0,
          },
        },
        show_diagnostics = false,
        show_git_status = true,
        show_icons = false,
      }
      ---@diagnostic disable-next-line: invisible, param-type-mismatch
      local _, highlights = view:__render_node__(ctx, node, "", 1, nil, false)
      t.assert_eq(case.expected, highlights[1].hlname, kind .. " name precedence")
    end
  end
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
  ---@diagnostic disable-next-line: missing-fields
  local root = {
    filepath = "/project/",
    nodename = "project",
    nodetype = "D",
    expanded = true,
    loaded = true,
    children = { child },
  } ---@type era.m.explorer.Node
  ---@diagnostic disable-next-line: missing-fields
  local tree = {
    ticks = { structure = 1 },
    is_selected = function()
      return false
    end,
  } ---@type era.m.explorer.Tree

  normalize_calls = 0
  ---@diagnostic disable-next-line: param-type-mismatch
  local result = view:render(bufnr, tree, root, {
    show_diagnostics = false,
    show_git_status = false,
    show_icons = false,
  })
  t.assert_eq(0, normalize_calls, "canonical render filepath normalization count")
  t.assert_eq("/project/file.lua", result.layout:id(1), "displayed filepath")

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
  ---@diagnostic disable-next-line: missing-fields
  local root = {
    filepath = "/project/",
    nodename = "project",
    nodetype = "D",
    expanded = true,
    loaded = true,
    children = { child },
  } ---@type era.m.explorer.Node
  ---@diagnostic disable-next-line: missing-fields
  local tree = {
    ticks = { structure = 1 },
    is_selected = function()
      return false
    end,
  } ---@type era.m.explorer.Tree

  ---@diagnostic disable-next-line: param-type-mismatch
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

  ---@diagnostic disable-next-line: invisible
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
  ---@diagnostic disable-next-line: missing-fields
  local root = {
    filepath = "/project/",
    nodename = "project",
    nodetype = "D",
    expanded = true,
    loaded = true,
    children = { child },
  } ---@type era.m.explorer.Node
  ---@diagnostic disable-next-line: missing-fields
  local tree = {
    ticks = { structure = 1 },
    is_selected = function()
      return false
    end,
  } ---@type era.m.explorer.Tree

  ---@diagnostic disable-next-line: param-type-mismatch
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

t:test("render: records visible parent and last-child navigation", function()
  local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  local view = View.new("navigation-test")
  local first = {
    filepath = "/project/src/a.lua",
    nodename = "a.lua",
    nodetype = "F",
  } ---@type era.m.explorer.Node
  ---@diagnostic disable-next-line: missing-fields
  local last = {
    filepath = "/project/src/z.lua",
    nodename = "z.lua",
    nodetype = "F",
  } ---@type era.m.explorer.Node
  ---@diagnostic disable-next-line: missing-fields
  local directory = {
    filepath = "/project/src/",
    nodename = "src",
    nodetype = "D",
    expanded = true,
    loaded = true,
    children = { first, last },
  } ---@type era.m.explorer.Node
  ---@diagnostic disable-next-line: missing-fields
  local root_last = {
    filepath = "/project/README.md",
    nodename = "README.md",
    nodetype = "F",
  } ---@type era.m.explorer.Node
  ---@diagnostic disable-next-line: missing-fields
  local root = {
    filepath = "/project/",
    nodename = "project",
    nodetype = "D",
    expanded = true,
    loaded = true,
    children = { directory, root_last },
  } ---@type era.m.explorer.Node
  ---@diagnostic disable-next-line: missing-fields
  local tree = {
    ticks = { structure = 1 },
    is_selected = function()
      return false
    end,
  } ---@type era.m.explorer.Tree

  ---@diagnostic disable-next-line: param-type-mismatch
  local result = view:render(bufnr, tree, root, {
    foldempty = false,
    show_diagnostics = false,
    show_git_status = false,
    show_icons = false,
  })

  t.assert_eq(1, result.layout:parent_lnum(2), "first child parent")
  t.assert_eq(1, result.layout:parent_lnum(3), "last child parent")
  t.assert_eq(3, result.layout:last_child_lnum(1), "directory last child")
  t.assert_eq(4, result.layout:last_root_lnum(), "root last child")
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("render: only-selected keeps source sibling connectors", function()
  local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  local view = View.new("only-selected-connectors-test")
  local selected = {
    filepath = "/project/a.lua",
    nodename = "a.lua",
    nodetype = "F",
    selected = true,
  } ---@type era.m.explorer.Node
  ---@diagnostic disable-next-line: missing-fields
  local hidden_last = {
    filepath = "/project/z.lua",
    nodename = "z.lua",
    nodetype = "F",
    selected = false,
  } ---@type era.m.explorer.Node
  ---@diagnostic disable-next-line: missing-fields
  local root = {
    filepath = "/project/",
    nodename = "project",
    nodetype = "D",
    expanded = true,
    loaded = true,
    selected = false,
    children = { selected, hidden_last },
  } ---@type era.m.explorer.Node
  selected.parent = root
  hidden_last.parent = root
  local tree = {
    ticks = { structure = 1 },
    is_selected = function()
      return false
    end,
  } ---@type era.m.explorer.Tree

  local result = view:render(bufnr, tree, root, {
    only_selected = true,
    show_diagnostics = false,
    show_git_status = false,
    show_icons = false,
  })

  t.assert_eq(1, #result.lines, "visible row count")
  t.assert_eq("├─a.lua", result.lines[1], "connector follows source sibling position")
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("precompute: handles depth 10000 iteratively", function()
  local root = {
    filepath = "/root/",
    nodename = "root",
    nodetype = "D",
    expanded = true,
    loaded = true,
    children = {},
  } ---@type era.m.explorer.Node
  local parent = root ---@type era.m.explorer.Node
  for index = 1, 10000 do
    local node = {
      filepath = "/" .. index .. "/",
      nodename = tostring(index),
      nodetype = "D",
      expanded = true,
      loaded = true,
      children = {},
      parent = parent,
    } ---@type era.m.explorer.Node
    parent.children[1] = node
    parent = node
  end
  local view = View.new("deep-precompute-test")
  local ctx = {
    tree = { ticks = { structure = 1 } },
    diag_counts = {},
    show_diagnostics = true,
    show_git_status = false,
    show_icons = false,
  } ---@type era.m.explorer.view.IRenderContext

  ---@diagnostic disable-next-line: invisible
  view:__precompute__(root, ctx)

  ---@diagnostic disable-next-line: invisible
  t.assert_eq(10000, #view._cached_filepaths, "deep filepath count")
  t.assert_true(ctx.diag_counts[root.filepath] ~= nil, "deep root diagnostics")
end)

t:run()
