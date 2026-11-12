local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")
local lsp = require("__test__.support.lsp")
local t = harness.new()

require("ark.bootstrap").setup()
local Jobs = require("era.m.filetree.jobs")
local await = require("__test__.support.treeview").await
bootstrap.with_reporter(t)
t:patch_table(era.m.git.state, "refresh", function() end)

---@param from                          string
---@param to                            string
---@return boolean
local function move(from, to)
  local captured = await(Jobs.capture(from))
  local result = await(Jobs.move(captured.data, captured.resource, to))
  return result.success
end

-- A Lua buffer whose unsaved content differs from its file on disk, shown in the current window when `current` is true.
---@param current                       ?boolean
---@return integer, string, string
local function new_buffer(current)
  local from = t:tempdir() .. "/source.lua"
  vim.fn.writefile({ "disk content" }, from)
  local bufnr = t:buffer({ "unsaved content" }, { name = from, listed = true, filetype = "lua", current = current })
  from = vim.api.nvim_buf_get_name(bufnr)
  return bufnr, from, from .. ".renamed.lua"
end

t:test("rename: preserves hidden modified buffer and undo", function()
  local bufnr, from, to = new_buffer()
  local undo = vim.api.nvim_buf_call(bufnr, vim.fn.undotree)
  local file_events = 0
  local autocmd = vim.api.nvim_create_autocmd("BufFilePost", {
    buffer = bufnr,
    callback = function()
      file_events = file_events + 1
    end,
  })
  t:defer(function()
    vim.api.nvim_del_autocmd(autocmd)
  end)

  t.assert_true(move(from, to))
  t.assert_nil(vim.uv.fs_stat(from))
  t.assert_eq("disk content", vim.fn.readfile(to)[1])
  t.assert_true(vim.api.nvim_buf_is_valid(bufnr))
  t.assert_eq(to, vim.api.nvim_buf_get_name(bufnr))
  t.assert_same({ "unsaved content" }, vim.api.nvim_buf_get_lines(bufnr, 0, -1, false))
  t.assert_true(vim.api.nvim_get_option_value("modified", { buf = bufnr }))
  t.assert_same(undo, vim.api.nvim_buf_call(bufnr, vim.fn.undotree))
  t.assert_eq(1, file_events, "path cache notification")
end)

t:test("rename: preserves displayed buffer identity", function()
  local bufnr, from, to = new_buffer(true)
  local winnr = vim.api.nvim_get_current_win()
  t.assert_true(move(from, to))
  t.assert_eq(bufnr, vim.api.nvim_win_get_buf(winnr))
  t.assert_eq(to, vim.api.nvim_buf_get_name(bufnr))
end)

t:test("rename: rejects target buffer before filesystem and LSP changes", function()
  local bufnr, from, to = new_buffer()
  local target_bufnr = new_buffer()
  vim.api.nvim_buf_set_name(target_bufnr, to)
  local requests = 0 ---@type integer
  local client = {
    supports_method = function(_, method)
      return method == "workspace/willRenameFiles"
    end,
    request = function()
      requests = requests + 1
      return false
    end,
  }
  t:patch_table(vim.lsp, "get_clients", function()
    return { client }
  end)
  local reports = bootstrap.with_reporter(t)

  t.assert_false(move(from, to))
  t.assert_eq(0, requests, "no willRenameFiles request")
  local messages = bootstrap.messages(reports.error) ---@type string[]
  t.assert_eq(1, #messages, "refusal reported")
  t.assert_eq(1, messages[1]:find("Move refused; target belongs to another buffer: ", 1, true), messages[1])
  t.assert_true(vim.uv.fs_stat(from) ~= nil)
  t.assert_nil(vim.uv.fs_stat(to))
  t.assert_eq(from, vim.api.nvim_buf_get_name(bufnr))
  t.assert_same({ "unsaved content" }, vim.api.nvim_buf_get_lines(target_bufnr, 0, -1, false))
end)

t:test("rename: filesystem failure keeps original buffer", function()
  local bufnr, from, to = new_buffer()
  local captured = await(Jobs.capture(from))
  assert(vim.uv.fs_rename(from, from .. ".saved"))
  vim.fn.writefile({ "replacement" }, from)
  t.assert_false(await(Jobs.move(captured.data, captured.resource, to)).success)
  t.assert_eq("replacement", vim.fn.readfile(from)[1])
  t.assert_eq(from, vim.api.nvim_buf_get_name(bufnr))
  t.assert_true(vim.api.nvim_get_option_value("modified", { buf = bufnr }))
end)

t:test("rename: checks buffers created by willRenameFiles before moving", function()
  local bufnr, from, to = new_buffer()
  local target_bufnr = new_buffer()
  local client = {
    supports_method = function(_, method)
      return method == "workspace/willRenameFiles"
    end,
    request = function(_, _, _, callback)
      vim.api.nvim_buf_set_name(target_bufnr, to)
      callback(nil, nil)
      return true, 1
    end,
  }
  t:patch_table(vim.lsp, "get_clients", function()
    return { client }
  end)
  t.assert_false(move(from, to))
  t.assert_true(vim.uv.fs_stat(from) ~= nil)
  t.assert_eq(from, vim.api.nvim_buf_get_name(bufnr))
end)

t:test("rename: LSP closes old URI and tracks edits at the new URI", function()
  local bufnr, from, to = new_buffer()
  local notifications = {}
  local client_id = lsp.start(t, bufnr, {
    name = "rename-test",
    flags = { debounce_text_changes = 0 },
    cmd = lsp.server({
      capabilities = {
        textDocumentSync = { openClose = true, change = 1, willSave = true, willSaveWaitUntil = true },
        workspace = { fileOperations = { didRename = { filters = {} } } },
      },
      on_request = function(method, params, respond)
        notifications[#notifications + 1] = { method = method, params = params }
        respond(nil, nil)
      end,
      on_notify = function(method, params)
        notifications[#notifications + 1] = { method = method, params = params }
      end,
    }),
  })
  t.wait_until(function()
    local client = vim.lsp.get_client_by_id(client_id)
    return client ~= nil and client.initialized and vim.lsp.buf_is_attached(bufnr, client_id)
  end, 5000, "client initialized")
  notifications = {}

  t.assert_true(move(from, to))
  local close_index, open_index, rename_index
  for i, notification in ipairs(notifications) do
    if notification.method == "textDocument/didClose" then
      close_index = i
      t.assert_eq(vim.uri_from_fname(from), notification.params.textDocument.uri)
    elseif notification.method == "textDocument/didOpen" then
      open_index = i
      t.assert_eq(vim.uri_from_fname(to), notification.params.textDocument.uri)
      t.assert_true(notification.params.textDocument.text:find("unsaved content", 1, true) ~= nil)
    elseif notification.method == "workspace/didRenameFiles" then
      rename_index = i
    end
  end
  t.assert_true(close_index ~= nil and open_index ~= nil and close_index < open_index, "close/open order")
  t.assert_true(rename_index ~= nil and open_index < rename_index, "workspace notification after buffer update")
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "next edit" })
  t.wait_until(function()
    for _, notification in ipairs(notifications) do
      if notification.method == "textDocument/didChange" then
        return notification.params.textDocument.uri == vim.uri_from_fname(to)
      end
    end
    return false
  end, 5000, "edits use new URI")

  for _, target in ipairs({ to, to .. ".lua" }) do
    if target ~= to then
      t.assert_true(move(to, target))
    end
    notifications = {}
    vim.api.nvim_exec_autocmds("BufWritePre", { buffer = bufnr, modeline = false })
    local will_save, wait_until = 0, 0
    for _, notification in ipairs(notifications) do
      if notification.method == "textDocument/willSave" then
        will_save = will_save + 1
        t.assert_eq(vim.uri_from_fname(target), notification.params.textDocument.uri)
      elseif notification.method == "textDocument/willSaveWaitUntil" then
        wait_until = wait_until + 1
        t.assert_eq(vim.uri_from_fname(target), notification.params.textDocument.uri)
      end
    end
    t.assert_eq(1, will_save, "one willSave per save after repeated renames")
    t.assert_eq(1, wait_until, "one willSaveWaitUntil per save after repeated renames")
  end

  local filetype_events = 0
  local autocmd = vim.api.nvim_create_autocmd("FileType", {
    buffer = bufnr,
    callback = function(event)
      filetype_events = filetype_events + 1
      t.assert_eq("python", event.match)
    end,
  })
  t:defer(function()
    vim.api.nvim_del_autocmd(autocmd)
  end)
  t.assert_true(move(to .. ".lua", to .. ".py"))
  t.assert_eq("python", vim.api.nvim_get_option_value("filetype", { buf = bufnr }))
  t.assert_eq(1, filetype_events, "new language triggers configured LSP selection")
  t.assert_false(vim.lsp.buf_is_attached(bufnr, client_id), "old-language client must remain detached")
  t.assert_true(vim.api.nvim_get_option_value("modified", { buf = bufnr }))
end)

t:test("rename: enabled LSP config resolves the new project root", function()
  local bufnr, from = new_buffer()
  local config_name = "rename-root-test"
  local root = vim.fs.dirname(from)
  local target = root .. "/other-project/target.lua"
  vim.lsp.config(config_name, {
    filetypes = { "lua" },
    root_dir = function(buffer, on_dir)
      on_dir(vim.fs.dirname(vim.api.nvim_buf_get_name(buffer)))
    end,
    cmd = lsp.server({ capabilities = { textDocumentSync = { openClose = true, change = 1 } } }),
  })
  t:defer(function()
    vim.lsp.enable(config_name, false)
    for _, client in ipairs(vim.lsp.get_clients({ name = config_name })) do
      client:stop(true)
    end
  end)
  vim.lsp.enable(config_name)
  t.wait_until(function()
    return #vim.lsp.get_clients({ name = config_name, bufnr = bufnr }) == 1
  end, 5000, "initial project client")
  local old_client = vim.lsp.get_clients({ name = config_name, bufnr = bufnr })[1]
  t.assert_eq(root, old_client.root_dir)
  t.assert_true(move(from, target))
  t.wait_until(function()
    local attached = vim.lsp.get_clients({ name = config_name, bufnr = bufnr })
    return #attached == 1 and attached[1].root_dir == root .. "/other-project"
  end, 5000, "new project client")
  t.assert_false(vim.lsp.buf_is_attached(bufnr, old_client.id), "old project client stays detached")
  local new_client = vim.lsp.get_clients({ name = config_name, bufnr = bufnr })[1]
  t.assert_true(move(target, target .. ".lua"))
  t.wait_until(function()
    return vim.lsp.buf_is_attached(bufnr, new_client.id)
  end, 5000, "same root reuses client")
  t.assert_true(vim.api.nvim_get_option_value("modified", { buf = bufnr }))
end)

t:run()
