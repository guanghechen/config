local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")

local t = harness.new()

bootstrap.with_global(t, "stl", {
  filetype = {
    NOTEPAD = "notepad",
  },
})

t:test("notepad owns its markdown mapping", function()
  local mappings = {} ---@type table<string, string>
  t:patch_table(vim.treesitter.language, "register", function(lang, filetype)
    mappings[filetype] = lang
  end)
  t:patch_table(package.loaded, "era.m.notepad", nil)

  require("era.m.notepad")

  t.assert_eq("markdown", mappings[stl.filetype.NOTEPAD], "notepad mapping")
end)

t:run()
