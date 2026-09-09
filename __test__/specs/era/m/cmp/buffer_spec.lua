local harness = require("__test__.support.harness")
local context_api = require("era.m.cmp.context")
local buffer = require("era.m.cmp.source.buffer")
local suite = harness.new("era.m.cmp.source.buffer")

suite:patch_global("yoz", require("yoz"))
local tab_buffers = {}
suite:patch_global("dot", { tab = {
  resolve = function()
    return { bufs = tab_buffers }
  end,
} })

---@param lines                         string[]
---@return integer
local function create_buffer(lines)
  local bufnr = vim.api.nvim_create_buf(true, false)
  suite:defer(function()
    buffer.clear(bufnr)
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)
  vim.api.nvim_buf_set_name(bufnr, vim.fn.tempname() .. ".lua")
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  tab_buffers[#tab_buffers + 1] = { bufnr = bufnr }
  return bufnr
end

---@param bufnr                         integer
---@param line                          string
---@return era.m.cmp.IContext
local function edit_query(bufnr, line)
  vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, { line })
  return assert(context_api.from_params({
    textDocument = { uri = vim.uri_from_bufnr(bufnr) },
    position = { line = 0, character = #line },
  }, bufnr))
end

---@param items                         lsp.CompletionItem[]
---@param label                         string
---@return boolean
local function contains(items, label)
  for _, item in ipairs(items) do
    if item.label == label then
      return true
    end
  end
  return false
end

suite:test("token edits reuse shards while changes outside the token refresh only their buffer", function()
  tab_buffers = {}
  local active_bufnr = create_buffer({ "tar", "targetLocal targetOther" })
  local other_bufnr = create_buffer({ "targetExternal" })
  local builds = 0
  local native_index = yoz.cmp.index
  suite:patch_table(yoz.cmp, "index", function(...)
    builds = builds + 1
    return native_index(...)
  end)
  buffer.complete(edit_query(active_bufnr, "tar"))
  suite.assert_eq(2, builds, "initial shard count")
  local items = buffer.complete(edit_query(active_bufnr, "targ"))
  suite.assert_eq(2, builds, "typing keeps candidate shards")
  suite.assert_true(contains(items, "targetExternal"), "other buffer candidate")
  suite.assert_eq(4, items[1].textEdit.range["end"].character, "current insertion range")

  vim.api.nvim_buf_set_lines(other_bufnr, 0, -1, false, { "targetChanged" })
  items = buffer.complete(edit_query(active_bufnr, "targe"))
  suite.assert_eq(3, builds, "only the changed external shard rebuilds")
  suite.assert_true(contains(items, "targetChanged"), "updated external candidate")
  suite.assert_false(contains(items, "targetExternal"), "removed external candidate")

  items = buffer.complete(edit_query(active_bufnr, "targetNew ta"))
  suite.assert_eq(4, builds, "a new token commits the previous word")
  suite.assert_true(contains(items, "targetNew"), "committed input becomes a candidate")
end)

suite:test("a token edit cannot hide an earlier edit on another line", function()
  tab_buffers = {}
  local active_bufnr = create_buffer({ "tar", "targetBefore" })
  buffer.complete(edit_query(active_bufnr, "tar"))
  vim.api.nvim_buf_set_lines(active_bufnr, 1, 2, false, { "targetAfter" })
  local items = buffer.complete(edit_query(active_bufnr, "targ"))
  suite.assert_true(contains(items, "targetAfter"), "non-token edit is visible")
  suite.assert_false(contains(items, "targetBefore"), "old non-token text is absent")
end)

suite:test("retired listeners cannot invalidate a replacement shard", function()
  tab_buffers = {}
  local active_bufnr = create_buffer({ "tar", "targetValue" })
  buffer.complete(edit_query(active_bufnr, "tar"))
  buffer.clear(active_bufnr)
  buffer.complete(edit_query(active_bufnr, "targ"))
  local native_index = yoz.cmp.index
  local builds = 0
  suite:patch_table(yoz.cmp, "index", function(...)
    builds = builds + 1
    return native_index(...)
  end)
  suite.assert_true(
    contains(buffer.complete(edit_query(active_bufnr, "targe")), "targetValue"),
    "replacement shard survives"
  )
  suite.assert_eq(0, builds, "the new listener retains its token snapshot")
end)

suite:test("real input mutations stay bounded without rebuilding the tab index", function()
  tab_buffers = {}
  local active_bufnr
  for buffer_index = 1, 3 do
    local words = {}
    for word_index = 1, 5000 do
      words[word_index] = string.format("wo%06d", (buffer_index - 1) * 5000 + word_index)
    end
    local bufnr = create_buffer({ "wo", table.concat(words, " ") })
    active_bufnr = active_bufnr or bufnr
  end
  local builds = 0
  local native_index = yoz.cmp.index
  suite:patch_table(yoz.cmp, "index", function(...)
    builds = builds + 1
    return native_index(...)
  end)
  buffer.complete(edit_query(active_bufnr, "wo"))
  local elapsed = 0
  for iteration = 1, 8 do
    local context = edit_query(active_bufnr, iteration % 2 == 0 and "wo" or "wo0")
    local started = vim.uv.hrtime()
    local items = buffer.complete(context)
    elapsed = elapsed + (vim.uv.hrtime() - started) / 1e6
    suite.assert_eq(200, #items, "bounded candidate count")
  end
  suite.assert_eq(3, builds, "only initial buffer shards are built")
  suite.assert_true(elapsed / 8 < 10, string.format("edited buffer query %.3fms", elapsed / 8))
  print(string.format("BENCH cmp buffer edited15k=%.3fms", elapsed / 8))
end)

suite:test("focus changes commit the previous buffer token and exclude the newly active one", function()
  tab_buffers = {}
  local first_bufnr = create_buffer({ "targetFirst", "targetShared" })
  local second_bufnr = create_buffer({ "tar", "targetSecond" })
  buffer.complete(edit_query(first_bufnr, "targetFirst"))
  local items = buffer.complete(edit_query(second_bufnr, "targ"))
  suite.assert_true(contains(items, "targetFirst"), "inactive token becomes a candidate")
  suite.assert_true(contains(items, "targetShared"), "inactive buffer words stay available")
  items = buffer.complete(edit_query(first_bufnr, "tar"))
  suite.assert_false(contains(items, "targetFirst"), "new active token does not retain a stale candidate")
  suite.assert_true(contains(items, "targ"), "the newly inactive input is committed")
end)

suite:test("multiline insertion and deletion invalidate only their affected buffer shard", function()
  tab_buffers = {}
  local active_bufnr = create_buffer({ "tar", "targetBefore" })
  create_buffer({ "targetOther" })
  buffer.complete(edit_query(active_bufnr, "tar"))
  local native_index = yoz.cmp.index
  local builds = 0
  suite:patch_table(yoz.cmp, "index", function(...)
    builds = builds + 1
    return native_index(...)
  end)
  vim.api.nvim_buf_set_lines(active_bufnr, 0, 1, false, { "tar", "targetAdded" })
  local items = buffer.complete(edit_query(active_bufnr, "targ"))
  suite.assert_true(contains(items, "targetAdded"), "multiline input is indexed")
  suite.assert_eq(1, builds, "only the edited shard rebuilds")
  vim.api.nvim_buf_set_lines(active_bufnr, 1, 2, false, {})
  items = buffer.complete(edit_query(active_bufnr, "tar"))
  suite.assert_false(contains(items, "targetAdded"), "removed line is not retained")
  suite.assert_eq(2, builds, "line deletion invalidates the same shard")
end)

suite:run()
