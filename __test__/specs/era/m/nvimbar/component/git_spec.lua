local harness = require("__test__.support.harness")

local t = harness.new()

t:test("git winline component renders hunk navigation position", function()
  t:patch_global("stl", {
    icon = {
      git = {
        Git = "G",
      },
    },
    nvim = {
      fn = {
        txt = function(text)
          return text
        end,
      },
    },
  })
  t:patch_global("era", {
    m = {
      git = {
        hunk_nav = {
          get_nav_indicator = function(winnr)
            t.assert_eq(42, winnr, "component window")
            return 2, 10
          end,
        },
      },
    },
  })

  local git_component = assert(loadfile("lua/era/m/nvimbar/component/git.lua"))()
  t:patch_table(package.loaded, "era.m.git.hunk_nav", era.m.git.hunk_nav)
  local component = git_component.hunk_nav("f_wl")

  local context = {
    winnr = 42,
    bufnr = 1,
    cwd = "",
    filename = "",
    filepath = "",
    filetype = "",
    mode = "normal",
    mode_name = "NORMAL",
  } ---@type era.m.nvimbar.INvimbarContext
  t.assert_true(component.condition(context), "visible with navigation state")
  t.assert_eq("G 2/10", component.refresh(context).text, "rendered position")
end)

t:run()
