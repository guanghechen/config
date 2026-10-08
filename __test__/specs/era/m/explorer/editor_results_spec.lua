---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.era.m.explorer.editor_results" ---@type string

local fixture = require("__test__.support.explorer").new("era.m.explorer.editor_results")
local t, await = fixture.t, fixture.await
local buffers = require("era.m.explorer.buffers")

---@param path                          string
---@param contents                      string
---@return integer
local function edited_buffer(path, contents)
  local bufnr = vim.fn.bufadd(path)
  vim.fn.bufload(bufnr)
  t:defer(function()
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { contents })
  return bufnr
end

---@param value                         any
---@return nil
local function assert_plain_result(value)
  if type(value) == "table" then
    for _, field in pairs(value) do
      assert_plain_result(field)
    end
  else
    t.assert_true(type(value) == "string" or type(value) == "number" or type(value) == "boolean")
  end
end

t:test("a late buffer collision survives 129 successful results without changing IO success or recovery", function()
  local path = assert(vim.uv.fs_realpath(fixture.directory()))
  assert(vim.uv.fs_mkdir(path .. "/dst", 448))
  for index = 1, 130 do
    fixture.write(string.format("%s/file-%03d", path, index))
  end
  local source, target = path .. "/file-001", path .. "/dst/file-001"
  local from = edited_buffer(source, "unsaved source edits")
  local widget = fixture.widget(path)
  local session, view = widget:context()
  local nodes = {}
  for index = 1, 130 do
    nodes[index] = await(session.data:resolve(string.format("%s/file-%03d", path, index))):node()
  end
  await(session.state:select_node(nodes, true))
  t:patch_table(vim.lsp, "get_clients", function()
    return {}
  end)
  local to
  local sync = buffers.sync
  t:patch_table(buffers, "sync", function(owner, item)
    if item.source == source then
      t.assert_eq("success", item.status)
      t.assert_nil(vim.uv.fs_stat(source))
      to = edited_buffer(target, "unsaved target edits")
    end
    return sync(owner, item)
  end)
  local messages = {}
  t:patch_table(stl.reporter, "info", function(value)
    messages[#messages + 1] = value.message
  end)
  -- Observe collection after the caller's temporary Job userdata leaves its stack frame.
  ---@return table
  local function execute()
    local job = await(session:operate(view, { kind = "move", target = await(session.data:resolve(path .. "/dst")) }))
    fixture.idle(widget)
    t.assert_nil(job:results(1, 1)[1].editor_error)
    t.assert_eq("success", job:results(1, 1)[1].status)
    return setmetatable({ job }, { __mode = "v" })
  end
  local retained = execute()
  t.assert_eq(130, session._counts.success)
  t.assert_eq(0, session._counts.failed)
  t.assert_eq(1, session._counts.editor_failed)
  t.assert_eq(128, #session.results)
  for _, item in ipairs(session.results) do
    t.assert_true(item.source ~= source)
  end
  t.assert_eq(1, #session.issues)
  local issue = session.issues[1]
  t.assert_eq(source, issue.source)
  t.assert_eq("success", issue.status)
  t.assert_nil(issue.error)
  t.assert_nil(issue.sync_error)
  t.assert_eq(1, issue.editor_error.failures)
  t.assert_true(issue.editor_error.message:find("target name belongs to another buffer", 1, true) ~= nil)
  t.assert_true(messages[#messages]:find("130 succeeded, 0 failed, 0 skipped, 1 editor sync issue", 1, true) ~= nil)
  t.assert_eq(0, session.issues_omitted)
  t.assert_true(session._issue_bytes <= 1024 * 1024)
  assert_plain_result(issue)
  -- LuaJIT traces may retain observed userdata constants after their application owners release them.
  jit.flush()
  t.wait_until(function()
    collectgarbage("collect")
    return retained[1] == nil
  end, 10000)
  t.assert_nil(session.job)
  t.assert_nil(next(session.data._jobs))
  t.assert_false(require("era.m.explorer.jobs").pending())
  t:patch_table(vim.ui, "select", function(_, _, done)
    done("Last results")
  end)
  widget._action:menu()
  t.assert_true(messages[#messages]:find("Editor synchronization: " .. issue.editor_error.message, 1, true) ~= nil)
  t.assert_eq(target, vim.b[from].filetree_move_target)
  local written = pcall(vim.api.nvim_buf_call, from, function()
    vim.cmd.write({ bang = true })
  end)
  t.assert_false(written)
  t.assert_nil(vim.uv.fs_stat(source))
  t.assert_eq("unsaved source edits", vim.api.nvim_buf_get_lines(from, 0, -1, false)[1])
  t.assert_eq("unsaved target edits", vim.api.nvim_buf_get_lines(to, 0, -1, false)[1])
  local recovered = path .. "/recovered.txt"
  vim.api.nvim_buf_set_name(from, recovered)
  vim.api.nvim_buf_call(from, function()
    vim.cmd.write()
  end)
  t.assert_eq("unsaved source edits", vim.fn.readfile(recovered)[1])
  t.assert_eq("test", vim.fn.readfile(target)[1])
  t.assert_nil(vim.b[from].filetree_move_target)
  t.assert_nil(vim.uv.fs_stat(source))
  session:dispose()
  t.assert_nil(session.state)
  t.assert_nil(session.data)
  t.assert_true(session.issues[1] == issue)
end)

t:test("an unexpected notification failure preserves earlier buffer failures in one bounded outcome", function()
  local path = assert(vim.uv.fs_realpath(fixture.directory()))
  local source, target = path .. "/source", path .. "/target"
  fixture.write(source)
  local bufnr = edited_buffer(source, "unsaved edits")
  assert(vim.uv.fs_rename(source, target))
  t:patch_table(era.m.lsp.event, "rename_buf", function()
    error("injected buffer rename failure", 0)
  end)
  t:patch_table(vim.lsp, "get_clients", function()
    return {
      {
        supports_method = function()
          return true
        end,
        notify = function()
          error({ message = "injected notification failure", detail = function() end }, 0)
        end,
      },
    }
  end)
  local reports = {}
  local item = { status = "success", source = source, target = target }
  local issue = buffers.sync({
    operation = "move",
    report = function(message)
      reports[#reports + 1] = message
    end,
  }, item)
  t.assert_eq("success", item.status)
  t.assert_eq(2, issue.failures)
  t.assert_eq(2, #reports)
  t.assert_true(issue.message:find("injected buffer rename failure", 1, true) ~= nil)
  t.assert_eq("injected notification failure", reports[2])
  assert_plain_result(issue)
  t.assert_eq("unsaved edits", vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)[1])
  t.assert_eq(target, vim.b[bufnr].filetree_move_target)
  t.assert_nil(vim.uv.fs_stat(source))
  t.assert_eq("test", vim.fn.readfile(target)[1])
end)

t:test("an unrepresentable moved path produces an editor outcome without changing IO status", function()
  t:patch_table(stl.env, "IS_WIN", true)
  for _, item in ipairs({
    { status = "success", source = "//?/device/source", target = "//?/device/target" },
    { status = "success", source_label = "unrepresentable source", target_label = "unrepresentable target" },
  }) do
    local issue = buffers.sync({ operation = "move", report = function() end }, item)
    t.assert_eq("success", item.status)
    t.assert_eq(1, issue.failures)
    t.assert_true(issue.message:find("cannot be represented by Neovim", 1, true) ~= nil)
  end
end)

for _, large in ipairs({ false, true }) do
  t:test(
    "editor issues obey the " .. (large and "byte" or "item") .. " history limit and reset with the next job",
    function()
      local path = fixture.directory()
      assert(vim.uv.fs_mkdir(path .. "/dst", 448))
      for index = 1, 520 do
        fixture.write(string.format("%s/file-%03d", path, index))
      end
      local widget = fixture.widget(path)
      local session, view = widget:context()
      local nodes = {}
      for index = 1, 520 do
        nodes[index] = await(session.data:resolve(string.format("%s/file-%03d", path, index))):node()
      end
      await(session.state:select_node(nodes, true))
      t:patch_table(vim.lsp, "get_clients", function()
        return {
          {
            name = "test editor",
            supports_method = function(_, method)
              return method == "workspace/didRenameFiles"
            end,
            notify = function()
              if large then
                error(string.rep("notification failure 文😀 ", 256), 0)
              end
              return false
            end,
          },
        }
      end)
      local target = await(session.data:resolve(path .. "/dst"))
      -- Measure history retention without a watcher refresh invalidating the prepared selection.
      widget:hide()
      t.wait_until(function()
        return session.data:watch_status().roots == 0 and not session.data._native:is_busy()
      end, 10000)
      await(session:operate(view, { kind = "move", target = target }))
      fixture.idle(widget)
      t.assert_eq(520, session._counts.success)
      t.assert_eq(0, session._counts.failed)
      t.assert_eq(520, session._counts.editor_failed)
      t.assert_eq(128, #session.results)
      t.assert_eq(520, #session.issues + session.issues_omitted)
      t.assert_true(session._issue_bytes <= 1024 * 1024)
      if large then
        t.assert_true(#session.issues > 0 and #session.issues < 512)
      else
        t.assert_eq(512, #session.issues)
        t.assert_true(session.issues[1].editor_error.message:find("rejected by test editor", 1, true) ~= nil)
      end
      for _, item in ipairs(session.issues) do
        t.assert_eq("success", item.status)
        t.assert_eq(1, item.editor_error.failures)
        t.assert_true(#item.editor_error.message <= 4096)
        if large then
          t.assert_eq("...", item.editor_error.message:sub(-3))
        end
      end
      local message
      t:patch_table(stl.reporter, "info", function(value)
        message = value.message
      end)
      t:patch_table(vim.ui, "select", function(_, _, done)
        done("Last results")
      end)
      widget:focus()
      fixture.idle(widget)
      session, view = widget:context()
      widget._action:menu()
      t.assert_true(message:find("520 editor sync issues", 1, true) ~= nil)
      t.assert_true(message:find(session.issues_omitted .. " additional issues omitted", 1, true) ~= nil)
      await(session:operate(view, { kind = "create", target = target, path = "next" }))
      fixture.idle(widget)
      t.assert_eq(0, session._counts.editor_failed)
      t.assert_eq(0, #session.issues)
      t.assert_eq(0, session.issues_omitted)
      t.assert_eq(0, session._issue_bytes)
    end
  )
end

t:run()
