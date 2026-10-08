---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.era.m.explorer.progress" ---@type string

local fixture = require("__test__.support.explorer").new("era.m.explorer.progress")
local t, await, directory = fixture.t, fixture.await, fixture.directory

t:test("progress uses processed items and readable byte units before paths and flags", function()
  local before = vim.o.showtabline
  vim.o.showtabline = 0
  t:defer(function()
    vim.o.showtabline = before
  end)
  local widget = fixture.widget(directory())
  local session, view = widget:context()
  t:patch_table(session, "job", {})
  t:patch_table(session, "operation", "copy")
  for _, case in ipairs({
    { 0, "0 B" },
    { 4, "4 B" },
    { 1023, "1023 B" },
    { 1024, "1.0 KiB" },
    { 1048576, "1.0 MiB" },
    { 1073741824, "1.0 GiB" },
  }) do
    t:patch_table(session, "progress", { phase = "working", processed = 17, results = 0, bytes = case[1] })
    local text, priority = widget:status_text()
    t.assert_eq("copy 17 items / " .. case[2], text)
    t.assert_eq("progress", priority)
    widget:render_winbar()
    local title = vim.api.nvim_get_option_value("winbar", { win = view.winnr })
    local rendered = vim.api.nvim_eval_statusline(title, { winid = view.winnr, use_winbar = true }).str
    t.assert_true(rendered:find(text, 1, true) ~= nil, rendered)
  end
  for _, phase in ipairs({ "preparing", "reading", "publishing", "cleanup" }) do
    t:patch_table(session, "progress", { phase = phase, processed = 17, results = 0, bytes = 4 })
    t.assert_eq(phase .. " 17 items / 4 B", widget:status_text())
  end
end)

for _, contents in ipairs({ "", "test" }) do
  t:test(
    (contents == "" and "empty" or "small") .. " files show progress before their directory result is published",
    function()
      local before = vim.o.showtabline
      vim.o.showtabline = 0
      t:defer(function()
        vim.o.showtabline = before
      end)
      local path = directory()
      assert(vim.uv.fs_mkdir(path .. "/source", 448))
      assert(vim.uv.fs_mkdir(path .. "/destination", 448))
      for index = 1, 1000 do
        local fd = assert(vim.uv.fs_open(path .. "/source/" .. index, "wx", 384))
        assert(vim.uv.fs_write(fd, contents, 0))
        assert(vim.uv.fs_close(fd))
      end
      local widget = fixture.widget(path)
      fixture.cursor(widget, path .. "/source")
      local session, view = widget:context()
      local notify = session.notify
      local observations = {}
      t:patch_table(session, "notify", function(self)
        notify(self)
        local progress = self.progress
        if self.job and progress and not progress.terminal and progress.processed > 0 and progress.results == 0 then
          local title = vim.api.nvim_get_option_value("winbar", { win = view.winnr })
          observations[#observations + 1] = {
            processed = progress.processed,
            bytes = progress.bytes,
            text = vim.api.nvim_eval_statusline(title, { winid = view.winnr, use_winbar = true }).str,
          }
        end
      end)
      local job = await(session:operate(view, { kind = "copy_to_directory", path = path .. "/destination" }))
      fixture.idle(widget)
      local status = job:status()
      t.assert_eq("complete", status.phase)
      t.assert_eq(1001, status.processed)
      t.assert_eq(1, status.results)
      t.assert_eq(1000 * #contents, status.bytes)
      t.assert_true(#observations > 0, "a compacted result count must not hide running work")
      for _, progress in ipairs(observations) do
        t.assert_true(progress.text:find(tostring(progress.processed), 1, true) ~= nil, progress.text)
        t.assert_true(progress.text:find(contents == "" and "0 B" or "B", 1, true) ~= nil, progress.text)
        if contents ~= "" then
          t.assert_true(progress.bytes > 0)
        end
      end
      for index = 1, 1000 do
        local fd = assert(vim.uv.fs_open(path .. "/destination/source/" .. index, "r", 0))
        local value = assert(vim.uv.fs_read(fd, #contents + 1, 0))
        assert(vim.uv.fs_close(fd))
        t.assert_eq(contents, value)
      end
    end
  )
end

t:run()
