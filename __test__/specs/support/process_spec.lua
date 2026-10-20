local harness = require("__test__.support.harness")
local process = require("__test__.support.process")
local t = harness.new()

t:test("a pseudo-terminal Neovim that exits nonzero fails the case", function()
  local inner = harness.new()
  inner:test("case", function()
    local run = process.pty(
      inner,
      { "-u", "NONE", "-i", "NONE", "-n", "--cmd", "cquit 3" },
      { width = 40, height = 10 }
    )
    process.assert_exited(inner, { run }, 5000)
  end)
  local result = inner:run({ exit = false, quiet = true })
  t.assert_eq(1, result.failed, "nonzero exit")
  t.assert_true(result.failures[1]:find("expected 0, got 3", 1, true) ~= nil, vim.inspect(result.failures))
end)

t:run()
