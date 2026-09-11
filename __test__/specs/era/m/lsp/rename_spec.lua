---@diagnostic disable: undefined-global
local __module_name__ = "__test__.specs.era.m.lsp.rename" ---@type string
local harness = require("__test__.support.harness")
local bootstrap = require("__test__.support.bootstrap")
local t = harness.new(__module_name__)
local reports = {}

bootstrap.with_stl(t, {
  nvim = {
    fn = {
      augroup = function(name)
        return vim.api.nvim_create_augroup(name, {})
      end,
    },
    buf = {
      locate_bufnr = function(filepath)
        for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
          if vim.api.nvim_buf_get_name(bufnr) == filepath then
            return bufnr
          end
        end
      end,
    },
  },
  reporter = {
    error = function(report)
      reports[#reports + 1] = report
    end,
  },
})
local Event = require("era.m.lsp.event")

---@return integer, string, string
local function new_buffer()
  local from = vim.fn.tempname() .. ".lua"
  local bufnr = vim.api.nvim_create_buf(true, false)
  t:defer(function()
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)
  vim.api.nvim_buf_set_name(bufnr, from)
  vim.api.nvim_set_option_value("filetype", "lua", { buf = bufnr })
  from = vim.api.nvim_buf_get_name(bufnr)
  local to = from .. ".renamed.lua"
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "unsaved content" })
  return bufnr, from, to
end

t:test("rename: preserves hidden modified buffer and undo", function()
  local bufnr, from, to = new_buffer()
  local undo = vim.api.nvim_buf_call(bufnr, vim.fn.undotree)
  local moved = false
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

  t.assert_true(Event.on_rename(from, to, function()
    moved = true
    return true
  end))
  t.assert_true(moved)
  t.assert_true(vim.api.nvim_buf_is_valid(bufnr))
  t.assert_eq(to, vim.api.nvim_buf_get_name(bufnr))
  t.assert_true(vim.deep_equal({ "unsaved content" }, vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)))
  t.assert_true(vim.api.nvim_get_option_value("modified", { buf = bufnr }))
  t.assert_true(vim.deep_equal(undo, vim.api.nvim_buf_call(bufnr, vim.fn.undotree)))
  t.assert_eq(1, file_events, "path cache notification")
end)

t:test("rename: preserves displayed buffer identity", function()
  local bufnr, from, to = new_buffer()
  local winnr = vim.api.nvim_get_current_win()
  local previous_bufnr = vim.api.nvim_win_get_buf(winnr)
  t:defer(function()
    vim.api.nvim_win_set_buf(winnr, previous_bufnr)
  end)
  vim.api.nvim_win_set_buf(winnr, bufnr)
  t.assert_true(Event.on_rename(from, to, function()
    return true
  end))
  t.assert_eq(bufnr, vim.api.nvim_win_get_buf(winnr))
  t.assert_eq(to, vim.api.nvim_buf_get_name(bufnr))
end)

t:test("rename: rejects target buffer before filesystem and LSP changes", function()
  local bufnr, from, to = new_buffer()
  local target_bufnr = new_buffer()
  vim.api.nvim_buf_set_name(target_bufnr, to)
  local moved = false
  t:patch_table(vim.lsp, "get_clients", function()
    error("LSP must not be queried after a preflight conflict")
  end)
  t.assert_false(Event.on_rename(from, to, function()
    moved = true
    return true
  end))
  t.assert_false(moved)
  t.assert_eq(from, vim.api.nvim_buf_get_name(bufnr))
  t.assert_true(vim.deep_equal({ "unsaved content" }, vim.api.nvim_buf_get_lines(target_bufnr, 0, -1, false)))
end)

t:test("rename: filesystem failure keeps original buffer", function()
  local bufnr, from, to = new_buffer()
  t.assert_false(Event.on_rename(from, to, function()
    return false
  end))
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
    request_sync = function()
      vim.api.nvim_buf_set_name(target_bufnr, to)
      return {}
    end,
  }
  t:patch_table(vim.lsp, "get_clients", function()
    return { client }
  end)
  local moved = false
  t.assert_false(Event.on_rename(from, to, function()
    moved = true
    return true
  end))
  t.assert_false(moved)
  t.assert_eq(from, vim.api.nvim_buf_get_name(bufnr))
end)

t:test("rename: LSP closes old URI and tracks edits at the new URI", function()
  local bufnr, from, to = new_buffer()
  local notifications = {}
  local stopped = false
  local client_id = vim.lsp.start({
    name = "rename-test",
    flags = { debounce_text_changes = 0 },
    cmd = function(dispatchers)
      return {
        request = function(method, params, callback)
          if method == "initialize" then
            callback(nil, {
              capabilities = {
                textDocumentSync = { openClose = true, change = 1, willSave = true, willSaveWaitUntil = true },
                workspace = { fileOperations = { didRename = { filters = {} } } },
              },
            })
          else
            notifications[#notifications + 1] = { method = method, params = params }
            callback(nil, nil)
          end
          return true, 1
        end,
        notify = function(method, params)
          notifications[#notifications + 1] = { method = method, params = params }
          return true
        end,
        is_closing = function()
          return stopped
        end,
        terminate = function()
          stopped = true
          dispatchers.on_exit(0, 0)
        end,
      }
    end,
  }, { bufnr = bufnr })
  t.assert_true(client_id ~= nil, "client started")
  t:defer(function()
    local client = vim.lsp.get_client_by_id(client_id)
    if client ~= nil then
      client:stop(true)
    end
  end)
  t.assert_true(
    vim.wait(1000, function()
      local client = vim.lsp.get_client_by_id(client_id)
      return client ~= nil and client.initialized and vim.lsp.buf_is_attached(bufnr, client_id)
    end),
    "client initialized"
  )
  notifications = {}

  t.assert_true(Event.on_rename(from, to, function()
    return true
  end))
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
  t.assert_true(
    vim.wait(1000, function()
      for _, notification in ipairs(notifications) do
        if notification.method == "textDocument/didChange" then
          return notification.params.textDocument.uri == vim.uri_from_fname(to)
        end
      end
      return false
    end),
    "edits use new URI"
  )

  for _, target in ipairs({ to, to .. ".lua" }) do
    if target ~= to then
      t.assert_true(Event.on_rename(to, target, function()
        return true
      end))
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
  t.assert_true(Event.on_rename(to .. ".lua", to .. ".py", function()
    return true
  end))
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
    cmd = function(dispatchers)
      local stopped = false
      return {
        request = function(method, _, callback)
          callback(nil, method == "initialize" and {
            capabilities = { textDocumentSync = { openClose = true, change = 1 } },
          } or nil)
          return true, 1
        end,
        notify = function()
          return true
        end,
        is_closing = function()
          return stopped
        end,
        terminate = function()
          stopped = true
          dispatchers.on_exit(0, 0)
        end,
      }
    end,
  })
  t:defer(function()
    vim.lsp.enable(config_name, false)
    for _, client in ipairs(vim.lsp.get_clients({ name = config_name })) do
      client:stop(true)
    end
  end)
  vim.lsp.enable(config_name)
  t.assert_true(
    vim.wait(1000, function()
      return #vim.lsp.get_clients({ name = config_name, bufnr = bufnr }) == 1
    end),
    "initial project client"
  )
  local old_client = vim.lsp.get_clients({ name = config_name, bufnr = bufnr })[1]
  t.assert_eq(root, old_client.root_dir)
  t.assert_true(Event.on_rename(from, target, function()
    return true
  end))
  t.assert_true(
    vim.wait(1000, function()
      local attached = vim.lsp.get_clients({ name = config_name, bufnr = bufnr })
      return #attached == 1 and attached[1].root_dir == root .. "/other-project"
    end),
    "new project client"
  )
  t.assert_false(vim.lsp.buf_is_attached(bufnr, old_client.id), "old project client stays detached")
  local new_client = vim.lsp.get_clients({ name = config_name, bufnr = bufnr })[1]
  t.assert_true(Event.on_rename(target, target .. ".lua", function()
    return true
  end))
  t.assert_true(
    vim.wait(1000, function()
      return vim.lsp.buf_is_attached(bufnr, new_client.id)
    end),
    "same root reuses client"
  )
  t.assert_true(vim.api.nvim_get_option_value("modified", { buf = bufnr }))
end)

t:run()
