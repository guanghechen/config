require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new()
local sbs_keymap = require("era.m.diffview.view.sbs_keymap")

t:test("shared side-by-side mappings do not retain their installation context", function()
  local bufnr = t:buffer()
  local retained = setmetatable({}, { __mode = "v" })
  local function install()
    local ctx = { payload = "installation context" }
    retained.ctx = ctx
    local probe = {
      modes = { "n" },
      key = "gz",
      desc = "gc probe",
      callback = function()
        return ctx
      end,
    }
    sbs_keymap.setup({ probe }, bufnr, function()
      return nil
    end)
  end

  install()
  collectgarbage("collect")
  collectgarbage("collect")
  t.assert_nil(retained.ctx, "installation context")
end)

t:run()
