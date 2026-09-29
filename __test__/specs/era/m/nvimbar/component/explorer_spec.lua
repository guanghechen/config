--- Run with: nvim -l __test__/run.lua __test__/specs/era/m/nvimbar/component/explorer_spec.lua

local harness = require("__test__.support.harness")
require("ark.bootstrap").setup()

local t = harness.new("era.m.nvimbar.component.explorer")

---@class era.m.nvimbar.component.explorer.ITestContext
---@field public component              era.m.nvimbar.component.explorer
---@field public cwd_calls              fun(): integer
---@field public workspace_calls        fun(): integer

---@param cwd                           string
---@param workspace                     string
---@param home_user                     string
---@param with_highlights               ?boolean
---@param windows                       ?boolean
---@return era.m.nvimbar.component.explorer.ITestContext
local function setup(cwd, workspace, home_user, with_highlights, windows)
  local count_cwd = 0 ---@type integer
  local count_workspace = 0 ---@type integer

  t:patch_table(dot.path, "cwd", function()
    count_cwd = count_cwd + 1
    return cwd
  end)
  t:patch_table(dot.path, "workspace", function()
    count_workspace = count_workspace + 1
    return workspace
  end)
  t:patch_table(dot.path, "shorten", function(path)
    return path
  end)
  t:patch_table(stl.env, "HOME_USER", home_user)
  t:patch_table(stl.env, "IS_WIN", windows == true)
  if not with_highlights then
    t:patch_table(stl.nvim.fn, "txt", function(text)
      return text
    end)
    t:patch_table(stl.nvim.fn, "btn", function(text)
      return text
    end)
  end

  t:patch_table(
    package.loaded,
    "era.m.explorer.path_display",
    assert(loadfile("lua/era/m/explorer/path_display.lua"))()
  )
  local component = assert(loadfile("lua/era/m/nvimbar/component/explorer.lua"))()
  return {
    component = component,
    cwd_calls = function()
      return count_cwd
    end,
    workspace_calls = function()
      return count_workspace
    end,
  }
end

---@param component                     era.m.nvimbar.component.explorer
---@param root_filepath                 string
---@return era.m.nvimbar.IRawComponent
local function tabline(component, root_filepath)
  t:patch_table(era.widget.explorer, "widget", {
    get_root_filepath = function()
      return root_filepath
    end,
    status_text = function()
      return ""
    end,
    get_display = function()
      return { mode = "tree", selected_only = false, compress = false, show_hidden = true }
    end,
    has_win_in_tab = function()
      return true
    end,
    get_winnr = function()
      return vim.api.nvim_get_current_win()
    end,
  })
  return component.tabline("f_tl")
end

---@param component                     era.m.nvimbar.component.explorer
---@param root_filepath                 string
---@return string
local function render_path(component, root_filepath)
  local snapshot = tabline(component, root_filepath).refresh({})
  return " " .. snapshot.path_text .. snapshot.detached_text
end

t:test("workspace root renders from Windows startup context", function()
  local context = setup([[C:\workspace\project\]], [[C:\workspace\project]], [[C:\Users\alice]], false, true)
  local text = render_path(context.component, "C:/workspace/project/")

  t.assert_eq(" " .. stl.icon.filetype.FolderWithHeart .. " project", text, "workspace display")
end)

t:test("nested cwd uses a slash-only workspace-relative display", function()
  local context = setup([[C:\workspace\project\src\]], [[C:\workspace\project]], [[C:\Users\alice]], false, true)
  local text = render_path(context.component, "C:/workspace/project/src/")

  t.assert_eq(" " .. stl.icon.filetype.FolderWithHeart .. " src", text, "nested cwd display")
end)

t:test("display roots below cwd keep their workspace-relative suffix", function()
  local context = setup("/workspace/project", "/workspace/project", "/home/alice")
  t.assert_eq(
    " " .. stl.icon.filetype.FolderWithHeart .. " project/src/组件",
    render_path(context.component, "/workspace/project/src/组件/")
  )
  context = setup("/workspace/project/src", "/workspace/project", "/home/alice")
  t.assert_eq(
    " " .. stl.icon.filetype.FolderWithHeart .. " src/组件",
    render_path(context.component, "/workspace/project/src/组件/")
  )
end)

t:test("filesystem roots retain a readable root label", function()
  local context = setup("/", "/", "/home/alice")
  t.assert_eq(" " .. stl.icon.filetype.FolderWithHeart .. " /", render_path(context.component, "/"))
  t.assert_eq(" " .. stl.icon.filetype.FolderWithHeart .. " /tmp", render_path(context.component, "/tmp/"))
end)

t:test("detached roots shorten only complete home segments", function()
  local context = setup([[C:\workspace\project]], [[C:\workspace\project]], [[C:\Users\alice]], false, true)
  local home_text = render_path(context.component, "C:/Users/alice/notes/")
  local sibling_text = render_path(context.component, "C:/Users/alice2/notes/")
  local suffix = " " .. stl.icon.ui.CircleMedium

  t.assert_eq(" " .. stl.icon.filetype.Folder .. " ~/notes" .. suffix, home_text, "home display")
  t.assert_eq(
    " " .. stl.icon.filetype.Folder .. " C:/Users/alice2/notes" .. suffix,
    sibling_text,
    "home sibling display"
  )
end)

t:test("Unix workspace names preserve literal backslashes", function()
  local root = [[/workspace/work\space]]
  local context = setup(root, root, "/home/alice")
  local cwd_prefix = " " .. stl.icon.filetype.FolderWithHeart .. " "
  t.assert_eq(cwd_prefix .. [[work\space]], render_path(context.component, root))
  t.assert_eq(cwd_prefix .. [[work\space/src\part]], render_path(context.component, root .. [[/src\part]]))
  t.assert_eq(
    " " .. stl.icon.filetype.Folder .. " /workspace/work/space " .. stl.icon.ui.CircleMedium,
    render_path(context.component, "/workspace/work/space")
  )
end)

t:test("Windows UNC and verbatim roots share the startup path representation", function()
  local context = setup([[\\server\share\project\]], [[\\server\share\project]], [[C:\Users\alice]], false, true)
  local cwd_prefix = " " .. stl.icon.filetype.FolderWithHeart .. " "
  t.assert_eq(cwd_prefix .. "project", render_path(context.component, "//server/share/project/"))
  t.assert_eq(cwd_prefix .. "project/src", render_path(context.component, "//?/UNC/server/share/project/src"))
  context = setup([[\\server\share\project\src]], [[\\server\share\project]], [[C:\Users\alice]], false, true)
  t.assert_eq(cwd_prefix .. "src/child", render_path(context.component, "//?/UNC/server/share/project/src/child"))
end)

t:test("narrow bars preserve detached colors and escape literal path and status text", function()
  local context = setup("/workspace/project", "/workspace/project", "/home/alice", true)
  dot.context.theme.apply_theme({ theme = "vsc-dark-modern", transparency = false })
  local component = tabline(context.component, "/home/alice/目录%#Error#/\nnotes/")
  t:patch_table(era.widget.explorer.widget, "status_text", function()
    return "copy 50%"
  end)
  local snapshot = component.refresh({})
  for _, width in ipairs({ 25, 44, 80 }) do
    local text, hltext = component.render(snapshot, { tabnr = vim.api.nvim_get_current_tabpage() }, width)
    local rendered = vim.api.nvim_eval_statusline(hltext, { use_tabline = true, highlights = true, maxwidth = width })
    t.assert_eq(text, rendered.str)
    t.assert_true(vim.api.nvim_strwidth(text) <= width)
    t.assert_false(text:find("\n", 1, true) ~= nil)
    local detached = false
    for _, span in ipairs(rendered.highlights) do
      for _, group in ipairs(span.groups) do
        detached = detached or group == "f_tl_explorer_path_detached"
        t.assert_true(group ~= "Error", "path text must not introduce highlight directives")
      end
    end
    t.assert_true(detached)
    if width == 80 then
      t.assert_true(text:find("%#Error#", 1, true) ~= nil)
      t.assert_true(text:find("copy 50%", 1, true) ~= nil)
    end
  end
end)

t:test("render reuses startup path context without rereading it", function()
  local context = setup([[C:\workspace\project\]], [[C:\workspace\project]], [[C:\Users\alice]], false, true)
  local component = tabline(context.component, "C:/workspace/project/")

  t.assert_eq(1, context.cwd_calls(), "startup cwd read count")
  t.assert_eq(1, context.workspace_calls(), "startup workspace read count")
  for _ = 1, 100 do
    ---@diagnostic disable-next-line: missing-parameter
    component.render(component.refresh({}), { tabnr = vim.api.nvim_get_current_tabpage() }, 80)
  end
  t.assert_eq(1, context.cwd_calls(), "render cwd read count")
  t.assert_eq(1, context.workspace_calls(), "render workspace read count")
end)

t:run()
