--- Run with: nvim -l lua/__test__/era/m/nvimbar/component/explorer.lua

local harness = require("__test__.harness")
require("ark.bootstrap").setup()

local t = harness.new("era.m.nvimbar.component.explorer")

---@class era.m.nvimbar.component.explorer.ITestContext
---@field public component              era.m.nvimbar.component.explorer
---@field public from_os_calls          fun(): integer
---@field public workspace_calls        fun(): integer

---@param cwd                           string
---@param workspace                     string
---@param home_user                     string
---@return era.m.nvimbar.component.explorer.ITestContext
local function setup(cwd, workspace, home_user)
  local from_os_path = yoz.canonical_path.from_os_path
  local count_from_os = 0 ---@type integer
  local count_workspace = 0 ---@type integer

  t:patch_table(yoz.canonical_path, "get_cwd", function()
    return cwd
  end)
  t:patch_table(yoz.canonical_path, "from_os_path", function(filepath, keep_trailing_slash)
    count_from_os = count_from_os + 1
    return from_os_path(filepath, keep_trailing_slash)
  end)
  t:patch_table(dot.path, "workspace", function()
    count_workspace = count_workspace + 1
    return workspace
  end)
  t:patch_table(dot.path, "shorten", function(path)
    return path
  end)
  t:patch_table(stl.env, "HOME_USER", home_user)
  t:patch_table(stl.nvim.fn, "txt", function(text)
    return text
  end)
  t:patch_table(stl.nvim.fn, "btn", function(text)
    return text
  end)

  local component = assert(loadfile("lua/era/m/nvimbar/component/explorer.lua"))()
  return {
    component = component,
    from_os_calls = function()
      return count_from_os
    end,
    workspace_calls = function()
      return count_workspace
    end,
  }
end

---@param component                     era.m.nvimbar.component.explorer
---@param root_filepath                 string
---@return string
local function render_path(component, root_filepath)
  local root = stl.c.Observable.from_value(root_filepath)
  ---@diagnostic disable-next-line: missing-parameter
  return component.path(root).render()
end

t:test("workspace root renders from canonical startup context", function()
  local context = setup([[C:\workspace\project\]], [[C:\workspace\project]], [[C:\Users\alice]])
  local text = render_path(context.component, "C:/workspace/project/")

  t.assert_eq(" " .. stl.icon.filetype.FolderWithHeart .. " project", text, "workspace display")
end)

t:test("nested cwd uses a slash-only workspace-relative display", function()
  local context = setup([[C:\workspace\project\src\]], [[C:\workspace\project]], [[C:\Users\alice]])
  local text = render_path(context.component, "C:/workspace/project/src/")

  t.assert_eq(" " .. stl.icon.filetype.FolderWithHeart .. " src", text, "nested cwd display")
end)

t:test("detached roots shorten only complete canonical home segments", function()
  local context = setup([[C:\workspace\project]], [[C:\workspace\project]], [[C:\Users\alice]])
  local home_text = render_path(context.component, "C:/Users/alice/notes/")
  local sibling_text = render_path(context.component, "C:/Users/alice2/notes/")
  local suffix = " " .. stl.icon.ui.CircleMedium

  t.assert_eq(" " .. stl.icon.filetype.Folder .. " ~/notes/" .. suffix, home_text, "home display")
  t.assert_eq(
    " " .. stl.icon.filetype.Folder .. " C:/Users/alice2/notes/" .. suffix,
    sibling_text,
    "home sibling display"
  )
end)

t:test("render reuses startup path context without recanonicalizing", function()
  local context = setup([[C:\workspace\project\]], [[C:\workspace\project]], [[C:\Users\alice]])
  local root = stl.c.Observable.from_value("C:/workspace/project/")
  local component = context.component.winbar(root, "f_wl", {}, function()
    return 80
  end)

  t.assert_eq(3, context.from_os_calls(), "startup canonicalization count")
  t.assert_eq(1, context.workspace_calls(), "startup workspace read count")
  for _ = 1, 100 do
    ---@diagnostic disable-next-line: missing-parameter
    component.render()
  end
  t.assert_eq(3, context.from_os_calls(), "render canonicalization count")
  t.assert_eq(1, context.workspace_calls(), "render workspace read count")
end)

t:run()
