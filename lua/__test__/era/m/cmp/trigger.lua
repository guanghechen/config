---@diagnostic disable: undefined-global

local harness = require("__test__.harness")

local t = harness.new("era.m.cmp.trigger")
local Trigger = require("era.m.cmp.trigger")

t:test("classifies only keyword and provider trigger characters", function()
  local characters = { ["."] = true, ["/"] = true, [" "] = true }

  t.assert_eq("keyword", Trigger.classify("a", characters), "letter")
  t.assert_eq("keyword", Trigger.classify("_", characters), "underscore")
  t.assert_eq("keyword", Trigger.classify("-", characters), "hyphen")
  t.assert_eq("trigger_character", Trigger.classify(".", characters), "LSP trigger")
  t.assert_eq("trigger_character", Trigger.classify("/", characters), "path trigger")
  t.assert_nil(Trigger.classify(";", characters), "ordinary punctuation")
  t.assert_nil(Trigger.classify(" ", characters), "blocked whitespace")
end)

t:test("keyword classification does not resolve provider triggers", function()
  local calls = 0
  local kind = Trigger.classify("a", function()
    calls = calls + 1
    return {}
  end)

  t.assert_eq("keyword", kind, "kind")
  t.assert_eq(0, calls, "provider lookup")
end)

t:test("snippet punctuation participates in provider triggers", function()
  local Snippets = require("era.m.cmp.source.snippets")
  t:patch_table(Snippets, "trigger_characters", function(filetype)
    t.assert_eq("cpp", filetype, "filetype")
    return { ["#"] = true }
  end)
  t:patch_table(vim.api, "nvim_get_option_value", function()
    return "cpp"
  end)
  t:patch_table(vim.lsp, "get_clients", function()
    return {}
  end)

  local characters = Trigger.characters(vim.api.nvim_get_current_buf())
  t.assert_true(characters["#"], "snippet trigger")
end)

t:run()
