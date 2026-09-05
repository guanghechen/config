--- Run with: nvim -l __test__/run.lua __test__/specs/era/m/ai/sender_spec.lua
local harness = require("__test__.support.harness")
local t = harness.new("era.m.ai.sender")

local function load_sender(tmux)
  t:patch_global("era", { m = { ai = { tmux = tmux } } })
  t:patch_table(vim, "defer_fn", function(callback)
    callback()
  end)
  t:patch_table(package.loaded, "era.m.ai.sender", nil)
  return require("era.m.ai.sender")
end

t:test("places text without submitting it", function()
  local pasted = nil
  local completed = 0
  local sender = load_sender({
    send_text = function(pane_id, text)
      t.assert_eq("%999999", pane_id)
      pasted = text
      return true
    end,
    send_key = function()
      error("placing text must not send submit keys")
    end,
    capture = function()
      error("placement without state patterns does not need capture")
    end,
  })

  sender.deliver({ pane_id = "%999999", text = "hello world", submit = false, vim_mode = false }, function(ok, reason)
    t.assert_true(ok)
    t.assert_eq("placed", reason)
    completed = completed + 1
  end)

  t.assert_eq("hello world", pasted)
  t.assert_eq(1, completed, "completion runs once")
end)

t:test("verifies modal delivery using the capture module and shipped patterns", function()
  local config = require("era.m.ai.config").tools.claude
  local frame = table.concat({ string.rep("─", 30), "❯ ", string.rep("─", 30), "-- INSERT --" }, "\n")
  local keys = {}
  local captures = 0
  local pasted = nil
  local completed = 0
  local sender = load_sender({
    send_text = function(pane_id, text)
      t.assert_eq("%999999", pane_id)
      pasted = text
      return true
    end,
    send_key = function(pane_id, key)
      t.assert_eq("%999999", pane_id)
      keys[#keys + 1] = key
    end,
    capture = function(pane_id, callback)
      t.assert_eq("%999999", pane_id)
      captures = captures + 1
      t.assert_true(captures <= 4, "delivery must finish after confirming the cleared input")
      callback(frame)
    end,
  })

  sender.deliver({
    pane_id = "%999999",
    text = "hello world",
    submit = true,
    vim_mode = true,
    insert_pattern = config.insert_pattern,
    busy_pattern = config.busy_pattern,
  }, function(ok, reason)
    t.assert_true(ok)
    t.assert_eq("submitted", reason)
    completed = completed + 1
  end)

  t.assert_eq("hello world", pasted)
  t.assert_eq("Escape,i,Escape,Enter", table.concat(keys, ","))
  t.assert_eq(4, captures, "verify idle, INSERT, and two submitted frames")
  t.assert_eq(1, completed, "completion runs once")
end)

t:run()
