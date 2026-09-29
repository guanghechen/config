---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.bench.explorer.jobs_ui" ---@type string

local here = vim.fs.dirname(assert(vim.uv.fs_realpath(debug.getinfo(1, "S").source:sub(2))))
local harness = vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(here)))
local root = vim.env.NVIM_EXPLORER_BENCH_CHECKOUT or harness
local Metrics = assert(loadfile(here .. "/metrics.lua"))()
package.path = harness .. "/?.lua;" .. root .. "/?/init.lua;" .. package.path
local samples = tonumber(arg[1]) or 3
assert(samples >= 1 and samples <= 100 and samples % 1 == 0 and arg[2] == nil)
local UI = require("__test__.support.ui")
local Grid = require("__test__.support.ui_grid")
local records, screens = {}, {}
local directory, ui, grid

---@param predicate                     fun(): boolean
---@param message                       string
---@return nil
local function until_(predicate, message)
  assert(vim.wait(30000, predicate, 5), message)
end

---@param code                          string
---@param arguments                     ?any[]
---@return any
local function execute(code, arguments)
  return ui:rpc("nvim_exec_lua", code, arguments or {})
end

---@param label                         string
---@return nil
local function screen(label)
  local rows = {}
  for _, cells in ipairs(grid.grids[1].rows) do
    local text = {}
    for _, cell in ipairs(cells) do
      text[#text + 1] = cell[1]
    end
    rows[#rows + 1] = table.concat(text):gsub("%s+$", "")
  end
  screens[#screens + 1] = { label = label, rows = rows }
end

---@param path                          string
---@return nil
local function cursor(path)
  execute(
    [[
    local path = ...
    acceptance.widget:focus()
    vim.cmd.stopinsert()
    acceptance.navigation = acceptance.widget:reveal(path)
  ]],
    { path }
  )
  until_(function()
    return execute(
      [[
      local path = ...
      local a = acceptance
      if not a.navigation:is_done() then return false end
      assert(not a.navigation:is_failed(), a.navigation:get_error())
      local session, view = a.widget:context()
      a.session, a.view = session, view
      local frame = view:frame()
      return a.widget:get_cursor_filepath() == path and frame and not view._busy
        and frame:header().cursor_row == vim.api.nvim_win_get_cursor(view.winnr)[1]
    ]],
      { path }
    )
  end, "cursor did not reach " .. path)
end

---@param label                         string
---@return table
local function idle(label)
  until_(function()
    return execute([[
      local a = acceptance
      return not a.session:busy() and not a.session.state:status().locked
        and not require("era.m.explorer.jobs").pending()
    ]])
  end, "Job did not settle: " .. label)
  return execute([[
    local a = acceptance
    assert(#a.errors == 0, vim.inspect(a.errors))
    assert(vim.v.errmsg == "", vim.v.errmsg)
    return { counts = a.session._counts, retained_results = #a.session.results,
      offset = a.session._result_offset, status = a.job and a.job:status() or a.session.progress }
  ]])
end

---@param key                           string
---@param path                          string
---@return nil
local function transfer(key, path)
  execute("acceptance.job = nil")
  ui:rpc("nvim_input", key)
  local title = key == "c" and "Copy to" or "Move to"
  until_(function()
    return grid:find(title) ~= nil
  end, title .. " prompt did not open")
  execute(
    [[
    local path = ...
    local bufnr = vim.api.nvim_get_current_buf()
    assert(vim.api.nvim_get_option_value("buftype", { buf = bufnr }) == "prompt")
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { path })
    vim.api.nvim_win_set_cursor(vim.api.nvim_get_current_win(), { 1, #path })
  ]],
    { path }
  )
  ui:rpc("nvim_input", "<CR>")
end

---@param path                          string
---@param content                       string
---@return nil
local function write(path, content)
  local descriptor = assert(vim.uv.fs_open(path, "wx", 384))
  assert(vim.uv.fs_write(descriptor, content, 0))
  assert(vim.uv.fs_close(descriptor))
end

---@param path                          string
---@param expected                      string
---@return nil
local function contents(path, expected)
  local descriptor = assert(vim.uv.fs_open(path, "r", 384))
  local value = assert(vim.uv.fs_read(descriptor, #expected + 1, 0))
  assert(vim.uv.fs_close(descriptor))
  assert(value == expected, "unexpected contents: " .. path)
end

local ok, failure = xpcall(function()
  for sample = 1, samples do
    directory = vim.fn.tempname()
    assert(vim.uv.fs_mkdir(directory, 448))
    directory = assert(vim.uv.fs_realpath(directory))
    for _, suffix in ipairs({ "/files", "/state", "/files/bulk", "/files/bulk/target", "/files/cancel-source" }) do
      assert(vim.uv.fs_mkdir(directory .. suffix, 448))
    end
    local files, cases = directory .. "/files", {}
    local record = { sample = sample, cases = cases, complete = false }
    records[#records + 1] = record
    write(files .. "/source.txt", "source payload\n")
    write(files .. "/overwrite.txt", "target sentinel\n")
    for index = 1, 260 do
      write(string.format("%s/bulk/file-%04d.txt", files, index), "bulk " .. index .. "\n")
    end
    for index = 1, 10000 do
      write(string.format("%s/cancel-source/file-%05d.txt", files, index), "cancel " .. index .. "\n")
    end
    ui = UI.new({
      timeout_ms = 45000,
      init = root .. "/init.lua",
      args = {
        "--cmd",
        string.format("lua vim.g.explorer_test_root=%q; vim.g.explorer_test_directory=%q", root, directory),
        "--cmd",
        "lua dofile("
          .. string.format("%q", harness .. "/__test__/fixtures/era/m/explorer/full_config_init.lua")
          .. ")",
      },
    })
    grid = Grid.new(ui)
    ui:rpc("nvim_ui_attach", 110, 40, { rgb = true, ext_linegrid = true })
    execute(
      [[
      local directory = ...
      acceptance = { errors = {}, cancellation_notices = {}, directory = directory }
      vim.v.errmsg = ""
      for _, level in ipairs({ "warn", "error" }) do
        local report = stl.reporter[level]
        stl.reporter[level] = function(value)
          local expected = level == "warn" and type(value) == "table"
            and value.from == "era.m.explorer.session" and value.message == "file operation cancelled"
            and acceptance.job and acceptance.job:status().cancelled
          local records = expected and acceptance.cancellation_notices or acceptance.errors
          records[#records + 1] = vim.inspect(value) .. (expected and "" or debug.traceback("", 2))
          return report(value)
        end
      end
      assert(vim.wait(10000, function()
        local input, select, loader = package.loaded["era.m.input"], package.loaded["era.m.select"], package.loaded["era.m.plugin.loader"]
        return input and select and loader and vim.ui.input == input.open and vim.ui.select == select.select
          and loader.get_startup_profile().finalized or false
      end, 5), "full configuration input/select UI did not initialize")
      vim.cmd.edit(directory .. "/files/source.txt")
      era.widget.explorer.focus()
      acceptance.widget = era.widget.explorer.get_widget()
      assert(vim.ui.input == require("era.m.input").open)
      assert(vim.ui.select == require("era.m.select").select)
    ]],
      { directory }
    )

    for _, answer in ipairs({ "n", "y" }) do
      cursor(files .. "/source.txt")
      transfer("c", files .. "/overwrite.txt")
      until_(function()
        return grid:find("Overwrite existing target?") ~= nil
      end, "overwrite confirmation was not displayed")
      execute([[
        acceptance.job = assert(acceptance.session.job)
        assert(acceptance.job:status().confirmation)
      ]])
      screen("overwrite-" .. answer .. "-" .. sample)
      ui:rpc("nvim_input", answer)
      local result = idle("overwrite " .. answer)
      assert(result.status.terminal and not result.status.cancelled)
      assert(result.counts[answer == "n" and "skipped" or "success"] == 1)
      contents(files .. "/overwrite.txt", answer == "n" and "target sentinel\n" or "source payload\n")
      contents(files .. "/source.txt", "source payload\n")
      cases[#cases + 1] = { name = "overwrite-" .. answer, result = result }
    end

    local copied, moved = files .. "/new/nested/copied.txt", files .. "/moved/nested/moved.txt"
    cursor(files .. "/source.txt")
    transfer("c", copied)
    local copy_result = idle("copy to missing parents")
    contents(copied, "source payload\n")
    assert(copy_result.counts.success == 1)
    cursor(copied)
    until_(function()
      return grid:find("copied.txt") ~= nil
    end, "copied file was not displayed")
    screen("missing-parent-copy-" .. sample)
    cases[#cases + 1] = { name = "copy-missing-parents", result = copy_result }
    transfer("x", moved)
    local move_result = idle("move to missing parents")
    assert(vim.uv.fs_stat(copied) == nil)
    contents(moved, "source payload\n")
    assert(move_result.counts.success == 1)
    cursor(moved)
    until_(function()
      return grid:find("moved.txt") ~= nil
    end, "moved file was not displayed")
    cases[#cases + 1] = { name = "move-missing-parents", result = move_result }

    cursor(files .. "/source.txt")
    ui:rpc("nvim_input", "c")
    until_(function()
      return grid:find("Copy to") ~= nil
    end, "preparation prompt did not open")
    ui:rpc("nvim_input", "<C-a>q")
    idle("cancel preparation prompt")
    contents(files .. "/source.txt", "source payload\n")
    cases[#cases + 1] = { name = "cancel-preparation" }

    cursor(files .. "/bulk")
    ui:rpc("nvim_input", ".")
    until_(function()
      return execute(
        [[
        local path = ...
        return acceptance.widget:get_root_filepath() == path
          and acceptance.view:frame():header().row_count == 261
      ]],
        { files .. "/bulk" }
      )
    end, "bulk source directory did not open")
    cursor(files .. "/bulk/file-0001.txt")
    ui:rpc("nvim_input", "VGc")
    until_(function()
      return execute("return acceptance.session:mode() == 'copy' and vim.api.nvim_get_mode().mode == 'n'")
    end, "Visual copy selection did not commit")
    cursor(files .. "/bulk/target")
    execute("acceptance.job = nil")
    ui:rpc("nvim_input", "p")
    until_(function()
      return execute([[
        if acceptance.session.job then
          acceptance.job = acceptance.session.job
          return true
        end
        return false
      ]])
    end, "bulk paste did not start")
    local backlog = execute([[
      local a = acceptance
      a.widget:hide()
      assert(next(a.widget._views) == nil)
      -- Simulate a synchronous plugin holding Lua while native IO finishes.
      local deadline = vim.uv.hrtime() + 20000000000
      while not a.job:status().terminal and vim.uv.hrtime() < deadline do
        vim.uv.sleep(1)
      end
      local status = a.job:status()
      assert(status.terminal and not status.error, vim.inspect(status))
      return status.results - a.session._result_offset
    ]])
    assert(backlog > 128, "probe did not establish a multi-batch backlog: " .. backlog)
    local bulk_result = idle("hidden result backlog")
    assert(bulk_result.status.results == 260 and bulk_result.counts.success == 260)
    assert(bulk_result.offset == 260 and bulk_result.retained_results == 128)
    assert(execute("return next(acceptance.widget._views) == nil and acceptance.session:mode() == nil"))
    for index = 1, 260 do
      local name = string.format("file-%04d.txt", index)
      contents(files .. "/bulk/" .. name, "bulk " .. index .. "\n")
      contents(files .. "/bulk/target/" .. name, "bulk " .. index .. "\n")
    end
    cursor(files .. "/bulk/target/file-0260.txt")
    until_(function()
      return grid:find("file-0260.txt") ~= nil
    end, "hidden paste was not visible after reopening")
    screen("hidden-backlog-reopened-" .. sample)
    cases[#cases + 1] = { name = "hidden-backlog", backlog = backlog, result = bulk_result }

    cursor(files .. "/cancel-source")
    transfer("c", files .. "/cancel-target")
    until_(function()
      return execute([[
        local job = acceptance.session.job
        if job and not job:status().terminal and job:status().bytes > 0 then
          acceptance.job = job
          return true
        end
        return false
      ]])
    end, "running copy was not observed before cancellation")
    ui:rpc("nvim_input", "<Space>")
    until_(function()
      return grid:find("Cancel operation") ~= nil and grid:find("Progress") ~= nil
    end, "running Job menu was not displayed")
    screen("running-cancel-menu-" .. sample)
    ui:rpc("nvim_input", "<Down><CR>")
    local cancelled = idle("cancel running Job from menu")
    assert(cancelled.status.terminal and cancelled.status.cancelled, vim.inspect(cancelled))
    for index = 1, 10000 do
      contents(string.format("%s/cancel-source/file-%05d.txt", files, index), "cancel " .. index .. "\n")
    end
    cases[#cases + 1] = { name = "cancel-running", result = cancelled }

    cursor(files .. "/source.txt")
    transfer("c", files .. "/after-cancel.txt")
    local recovered = idle("new operation after cancellation")
    assert(recovered.counts.success == 1)
    contents(files .. "/after-cancel.txt", "source payload\n")
    cursor(files .. "/after-cancel.txt")
    until_(function()
      return grid:find("after-cancel.txt") ~= nil
    end, "subsequent copy was not displayed")
    cases[#cases + 1] = { name = "operation-after-cancel", result = recovered }

    execute("acceptance.data = acceptance.session.data; acceptance.widget:dispose()")
    until_(function()
      return execute([[
        local a = acceptance
        return not require("era.m.explorer.jobs").pending() and next(a.widget._views) == nil
          and a.session.data == nil and a.session.state == nil and a.session.native == nil
          and a.data:watch_status().directories == 0 and a.data._native:stats().queue_depth == 0
      ]])
    end, "dispose left active work or watches")
    local summary = execute([[
      return { errors = acceptance.errors, cancellation_notices = acceptance.cancellation_notices, errmsg = vim.v.errmsg,
        messages = vim.api.nvim_exec2("messages", { output = true }).output }
    ]])
    assert(#summary.errors == 0 and summary.errmsg == "", vim.inspect(summary))
    record.summary = summary

    execute(
      [[
      local path = ...
      acceptance.widget = require("era.m.explorer.widget").new({ name = "job-exit-e2e", root = path })
      acceptance.widget:focus()
    ]],
      { files }
    )
    cursor(files .. "/cancel-source")
    transfer("c", files .. "/exit-target")
    until_(function()
      return execute([[
        local job = acceptance.session.job
        if job and not job:status().terminal and job:status().bytes > 0 then
          acceptance.job = job
          return true
        end
        return false
      ]])
    end, "running copy was not observed before exit")
    local marker = directory .. "/exit.json"
    execute(
      [[
      local marker = ...
      local events = {}
      vim.api.nvim_create_autocmd({ "ExitPre", "BufUnload", "BufDelete", "BufWipeout", "VimLeavePre" }, {
        callback = function(event)
          local view = acceptance.view
          events[#events + 1] = { event = event.event, bufnr = event.buf, view_bufnr = view.bufnr,
            closed = view._closed, valid = view:_valid(), epoch = view._epoch }
        end,
      })
      vim.api.nvim_create_autocmd("VimLeavePre", { once = true, callback = function()
        local a = acceptance
        local status = a.job:status()
        vim.fn.writefile({ vim.json.encode({ pending = require("era.m.explorer.jobs").pending(),
          terminal = status.terminal, cancelled = status.cancelled, active = a.session.job ~= nil,
          view_closed = a.view:status().closed, view_valid = a.view:_valid(),
          errors = a.errors, cancellation_notices = a.cancellation_notices, events = events }) }, marker)
      end })
    ]],
      { marker }
    )
    local scripted = sample % 2 == 0
    if scripted then
      -- ExitPre must also drain native cancellation when no interactive prompt runs.
      pcall(ui.rpc, ui, "nvim_command", "qall!")
    else
      ui:rpc("nvim_input", ":qall!<CR>")
      until_(function()
        return grid:find("Cancel unfinished Explorer operations and exit?") ~= nil
      end, "exit confirmation was not displayed")
      screen("exit-confirmation-" .. sample)
      ui:rpc("nvim_input", "y")
    end
    until_(function()
      return ui._exited == true
    end, "Neovim did not exit after cancelling its Job")
    local exited = vim.json.decode(table.concat(vim.fn.readfile(marker), "\n"))
    record.exit = exited
    assert(exited.terminal and exited.cancelled and not exited.pending and not exited.active, vim.inspect(exited))
    assert(exited.view_closed and not exited.view_valid, "an exiting surface retained publication eligibility")
    assert(#exited.errors == 0, vim.inspect(exited.errors))
    cases[#cases + 1] = { name = scripted and "exit-running-scripted" or "exit-running-typed", result = exited }
    record.ui_flushes, record.complete = grid.flushes, true
    ui:close()
    ui = nil
    assert(vim.fn.delete(directory, "rf") == 0)
    directory = nil
    io.stderr:write("Completed Job UI sample ", sample, ": ", #cases, " scenarios\n")
  end
end, debug.traceback)
local diagnostic
if not ok and ui and not ui._exited then
  if grid and grid.grids[1] then
    screen("failure")
  end
  local captured, value = pcall(
    execute,
    [[
    local a = acceptance
    return vim.inspect(a and { errors = a.errors, mode = vim.api.nvim_get_mode(),
      busy = a.session and a.session.state and a.session:busy(),
      status = a.job and a.job:status(), progress = a.session and a.session.progress,
      frame = a.view and not a.view._closed and a.view:frame() and a.view:frame():header(),
      buffer = vim.api.nvim_buf_get_lines(0, 0, -1, false) })
  ]]
  )
  diagnostic = captured and value or tostring(value)
  io.stderr:write("Failure state: ", diagnostic, "\n")
end
if ui then
  ui:close()
end
if directory then
  assert(vim.fn.delete(directory, "rf") == 0)
end
io.stdout:write(
  vim.json.encode({
    conditions = "Full init.lua and installed native, real keymaps/input/select UI; RPC places the cursor and fills path prompts. "
      .. "A bounded synchronous Lua pause accumulates native results for hidden backlog delivery. "
      .. "Cancellation uses the real Space menu during a 10,000-file copy; partial destinations are allowed. "
      .. "Fresh-process samples alternate typed and scripted exit during another running copy. Owned fixtures only.",
    nvim = vim.version(),
    memory_measurement = Metrics.memory_description(),
    samples = records,
    screens = screens,
    diagnostic = diagnostic,
    error = not ok and tostring(failure) or nil,
  }),
  "\n"
)
if not ok then
  error(failure)
end
