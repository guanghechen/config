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

t:test("toggles on a shared preview carry the side-by-side description of their keys", function()
  local bufnr = t:buffer()
  local probes = {} ---@type stl.t.IKeymap[]
  for _, key in ipairs({ "tz", "tu" }) do
    probes[#probes + 1] = { modes = { "n" }, key = key, desc = "view: " .. key, callback = stl.fn.noop }
  end
  sbs_keymap.setup(probes, bufnr, function()
    return nil
  end)
  local descs = {} ---@type table<string, string>
  for _, mapping in ipairs(vim.api.nvim_buf_get_keymap(bufnr, "n")) do
    descs[mapping.lhs] = mapping.desc
  end
  t.assert_eq("diffview(sbs): Toggle active preview default folds", descs.tz)
  t.assert_eq("diffview(sbs): Toggle workspace untracked files", descs.tu)
end)

t:run()
