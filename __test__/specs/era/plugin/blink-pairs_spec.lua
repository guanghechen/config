local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")
local undo = require("__test__.support.undo")

local t = harness.new()

bootstrap.with_global(t, "stl", {
  filetype = {
    list_not_sourcefile_filetypes = function()
      return {}
    end,
  },
})

local spec = require("era.plugin.blink-pairs")

-- Stands in for blink.pairs, which maps these keys in Insert mode when it is set up.
---@param lhss                          string[]
---@return string[]                     The keys that went through the maps of the stand-in.
local function with_pairs(lhss)
  local pressed = {} ---@type string[]
  t:patch_table(package.loaded, "blink.pairs", {
    setup = function()
      for _, lhs in ipairs(lhss) do
        vim.keymap.set("i", lhs, function()
          pressed[#pressed + 1] = lhs
          return lhs
        end, { expr = true })
      end
    end,
  })
  t:defer(function()
    for _, lhs in ipairs(lhss) do
      pcall(vim.keymap.del, "i", lhs)
    end
  end)
  return pressed
end

t:test("Enter and Space keep their undo break-points in front of the maps of blink.pairs", function()
  local pressed = with_pairs({ "<CR>", "<Space>" })
  spec.config(spec, spec.opts)

  t.assert_same({
    { "the quick  brown fox", "next" },
    { "the quick  brown fox" },
    { "the quick  brown" },
    { "the quick" },
    { "the" },
    { "" },
  }, undo.states(t, "the quick  brown fox<CR>next"))
  t.assert_same(
    { "<Space>", "<Space>", "<Space>", "<Space>", "<CR>" },
    pressed,
    "every key still goes through blink.pairs"
  )
end)

t:test("a blink.pairs that no longer maps one of the keys fails the setup", function()
  with_pairs({ "<CR>" })
  local ok, err = pcall(spec.config, spec, spec.opts)

  t.assert_false(ok, "setup")
  t.assert_true(tostring(err):find("blink.pairs no longer maps <Space>", 1, true) ~= nil, tostring(err))
end)

t:run()
