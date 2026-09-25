---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.bench.explorer.lsp" ---@type string

local here = vim.fs.dirname(assert(vim.uv.fs_realpath(debug.getinfo(1, "S").source:sub(2))))
local root = vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(here)))
local server = assert(arg[1], "usage: nvim -l __test__/bench/explorer/lsp.lua /path/to/vtsls")
assert(vim.fn.executable(server) == 1, "vtsls must already be installed")
local directory = vim.fn.tempname()
assert(vim.uv.fs_mkdir(directory, 448))
directory = assert(vim.uv.fs_realpath(directory))
local widget, client
local bufnrs = {}

---@param future                        stl.c.Future
---@return any
local function await(future)
  assert(
    vim.wait(15000, function()
      return future:is_done()
    end, 1),
    "Future timed out"
  )
  assert(not future:is_failed(), future:get_error())
  local value = future:get_result()
  assert(type(value) ~= "table" or value.kind ~= "Rejected", vim.inspect(value))
  return value
end

local ok, result = xpcall(function()
  vim.fn.writefile(
    { '{"compilerOptions":{"target":"ES2020","module":"commonjs","strict":true},"include":["*.ts"]}' },
    directory .. "/tsconfig.json"
  )
  vim.fn.writefile({ "export const answer = 42;" }, directory .. "/old.ts")
  vim.fn.writefile({ 'import { answer } from "./old";', "console.log(answer);" }, directory .. "/use.ts")
  vim.opt.runtimepath = { root, vim.env.VIMRUNTIME, vim.api.nvim__get_lib_dir() }
  vim.opt.packpath = vim.opt.runtimepath:get()
  package.path = root .. "/?.lua;" .. root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path
  local suffix = vim.uv.os_uname().sysname == "Windows_NT" and "dll" or "so"
  yoz = assert(package.loadlib(root .. "/lua/yoz." .. suffix, "luaopen_yoz"))()
  package.loaded.yoz = yoz
  stl, dot, era = require("stl"), require("dot"), require("era")
  dot.path.workspace = function()
    return directory
  end
  dot.path.is_git_repo = function()
    return false
  end
  vim.api.nvim_set_current_dir(directory)
  local errors = {}
  stl.reporter.warn = function(value)
    errors[#errors + 1] = value.message
  end
  stl.reporter.error = stl.reporter.warn
  stl.reporter.info = function() end
  local original = assert(dot.buf.loadfile(directory .. "/old.ts"))
  local dependent = assert(dot.buf.loadfile(directory .. "/use.ts"))
  bufnrs = { original, dependent }
  for _, bufnr in ipairs(bufnrs) do
    vim.api.nvim_set_option_value("filetype", "typescript", { buf = bufnr })
  end
  local capabilities = vim.lsp.protocol.make_client_capabilities()
  capabilities.workspace.fileOperations = { willRename = true, didRename = true }
  local id = assert(vim.lsp.start({
    name = "explorer-acceptance-vtsls",
    cmd = { server, "--stdio" },
    root_dir = directory,
    capabilities = capabilities,
    settings = { typescript = { updateImportsOnFileMove = { enabled = "always" } } },
  }, { bufnr = original }))
  client = assert(vim.lsp.get_client_by_id(id))
  assert(vim.lsp.buf_attach_client(dependent, id))
  assert(
    vim.wait(30000, function()
      return client.initialized
    end, 10),
    "LSP did not initialize"
  )
  local prepares = client:supports_method("workspace/willRenameFiles")
  local renames = client:supports_method("workspace/didRenameFiles")
  assert(prepares or renames, "server does not support file rename notifications or preparation")
  local definition = client:request_sync("textDocument/definition", {
    textDocument = { uri = vim.uri_from_bufnr(dependent) },
    position = { line = 1, character = 14 },
  }, 30000, dependent)
  assert(
    definition and not definition.err and definition.result and #definition.result > 0,
    "TypeScript project did not resolve the imported symbol: " .. vim.inspect(definition)
  )

  vim.api.nvim_buf_set_lines(original, 0, -1, false, { "export const answer = 43;" })
  local will, did, edits = 0, 0, 0
  local apply_edit = client.handlers["workspace/applyEdit"] or vim.lsp.handlers["workspace/applyEdit"]
  client.handlers["workspace/applyEdit"] = function(error, params, context)
    edits = edits + 1
    return apply_edit(error, params, context)
  end
  local request, notify = client.request, client.notify
  client.request = function(self, method, params, callback, bufnr)
    if method == "workspace/willRenameFiles" then
      will = will + 1
      assert(vim.uv.fs_stat(directory .. "/old.ts") and not vim.uv.fs_stat(directory .. "/renamed.ts"))
      local done = callback
      callback = function(error, value, ...)
        if value and (value.changes or value.documentChanges) then
          edits = edits + 1
        end
        return done(error, value, ...)
      end
    end
    return request(self, method, params, callback, bufnr)
  end
  client.notify = function(self, method, params)
    if method == "workspace/didRenameFiles" then
      did = did + 1
      assert(not vim.uv.fs_stat(directory .. "/old.ts") and vim.uv.fs_stat(directory .. "/renamed.ts"))
    end
    return notify(self, method, params)
  end
  widget = require("era.m.explorer.widget").new({ name = "lsp-acceptance", root = directory })
  widget:focus()
  await(widget:reveal(directory .. "/old.ts"))
  assert(vim.wait(10000, function()
    return widget:get_cursor_filepath() == directory .. "/old.ts"
  end, 1))
  await(widget._action:operate("move", { rename = true, name = "renamed.ts" }))
  assert(
    vim.wait(15000, function()
      return not widget._session:busy()
    end, 1),
    "rename did not finish"
  )
  assert(will == (prepares and 1 or 0), "rename preparation did not follow the server capabilities")
  assert(
    vim.wait(10000, function()
      return vim.api.nvim_buf_get_lines(dependent, 0, 1, false)[1]:find('"./renamed"', 1, true) ~= nil
    end, 10),
    "the real server did not send import edits"
  )
  assert(edits >= 1, "the real server did not send workspace edits")
  assert(
    vim.api.nvim_buf_get_lines(dependent, 0, 1, false)[1]:find('"./renamed"', 1, true),
    "import edit was not applied"
  )
  assert(vim.api.nvim_buf_get_name(original) == directory .. "/renamed.ts", "source buffer path was not synchronized")
  assert(vim.api.nvim_buf_get_lines(original, 0, 1, false)[1] == "export const answer = 43;", "unsaved source was lost")
  assert(vim.api.nvim_get_option_value("modified", { buf = original }))
  assert(vim.api.nvim_get_option_value("modified", { buf = dependent }))
  assert(
    vim.fn.readfile(directory .. "/use.ts")[1]:find('"./old"', 1, true),
    "rename unexpectedly saved workspace edits"
  )
  assert(
    vim.wait(5000, function()
      return vim.lsp.buf_is_attached(original, id)
    end, 10),
    "renamed buffer did not reattach"
  )
  if client:supports_method("workspace/didRenameFiles") then
    assert(did == 1)
  end
  assert(#errors == 0, vim.inspect(errors))
  return {
    passed = true,
    server = server,
    server_info = client.server_info,
    will_rename = will,
    edit_responses = edits,
    will_rename_supported = prepares,
    did_rename_supported = renames,
    did_rename = did,
    source_modified = true,
    dependent_modified = true,
    reattached = true,
  }
end, debug.traceback)

if widget then
  local jobs = require("era.m.explorer.jobs")
  jobs.cancel_all()
  vim.wait(10000, function()
    return not jobs.pending()
  end, 10)
  widget:dispose()
end
if client then
  client:stop(true)
  vim.wait(5000, function()
    return client:is_stopped()
  end, 10)
end
for _, bufnr in ipairs(bufnrs) do
  if vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end
end
vim.api.nvim_set_current_dir(root)
vim.fn.delete(directory, "rf")
assert(ok, result)
io.stdout:write(vim.json.encode(result), "\n")
