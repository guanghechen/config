require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new()

t:test("toggling a behavior saves it with the editor state", function()
  local editor = vim.fs.joinpath(t:tempdir(), "editor.json")
  dot.context.set_storage({ editor = editor })
  dot.context.watch_changes()

  dot.context.behavior.bufs_relative:next(false)

  t.wait_until(function()
    local data = stl.fs.read_json({ filepath = editor, silent_on_bad_path = true })
    return type(data) == "table" and type(data.behavior) == "table" and data.behavior.bufs_relative == false
  end, 5000, "the behavior saved in the editor state")
end)

t:run()
