---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.bench.diffview_navigation" ---@type string

local root =
  vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(assert(vim.uv.fs_realpath(debug.getinfo(1, "S").source:sub(2))))))
vim.opt.runtimepath:prepend(root)
package.path = root .. "/?.lua;" .. root .. "/?/init.lua;" .. package.path
local count, baseline = tonumber(arg[1]) or 5000, arg[2]
baseline = baseline ~= "" and baseline or nil
baseline = baseline and assert(vim.uv.fs_realpath(baseline), "baseline directory unavailable")
local directories = arg[3] == "directories"
if baseline then
  vim.opt.runtimepath:prepend(baseline)
  package.path = baseline .. "/lua/?.lua;" .. baseline .. "/lua/?/init.lua;" .. package.path
  package.cpath = baseline .. "/lua/?.so;" .. baseline .. "/lua/?.dll;" .. package.cpath
end
require("ark.bootstrap").setup()
local native = require("__test__.support.result_tree")
local tree = require("era.m.diffview.pane.tree")
local changes = require("era.m.diffview.pane.changes")
local action = require("era.m.diffview.view.workspace.action")
if baseline then
  assert(debug.getinfo(action.next_entry, "S").source:find(baseline, 1, true), "baseline action was not loaded")
end
local view = require("era.m.diffview.view.workspace.view")
local entries = {}
for index = 1, count do
  entries[index] = {
    filepath = string.format(directories and "dir%06d/file.lua" or "file%06d.lua", index),
    stage_type = "unstaged",
    status = "M",
  }
end
if directories then
  entries[#entries + 1] = { filepath = "z.lua", stage_type = "unstaged", status = "M" }
end
local bufnr = changes.create_buffer("unstaged")
vim.api.nvim_win_set_buf(0, bufnr)
local owner = tree.new()
local plan =
  changes.render(entries, { viewtype = directories and "tree" or "list", foldempty = false, stage_type = "unstaged" })
native.await(tree.apply(bufnr, plan, owner))
if directories then
  owner:set_expansion(tree.root, false, true)
  native.await(owner:ready())
end
local current = entries[1]
local ctx = {
  layout = { changes = { staged = {}, unstaged = { bufnr = bufnr, stage_type = "unstaged" } } },
  state = {
    get_entries = function()
      return entries
    end,
    get_current_entry = function()
      return current
    end,
    set_current_entry = function(_, entry)
      current = entry
    end,
  },
}
-- Measure route resolution independently of preview I/O and native cursor acknowledgement.
action.select = function() end
action.__update_changes_cursor__ = function() end
view.open_entry = function() end
local reads, item = 0, tree.item
tree.item = function(...)
  reads = reads + 1
  return item(...)
end

---@param callback                      fun(): nil
---@return table
local function measure(callback)
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  reads = 0
  local started = vim.uv.hrtime()
  callback()
  return { ms = (vim.uv.hrtime() - started) / 1e6, item_reads = reads }
end

---@param label                         string
---@return nil
local function metadata(label)
  plan.source:get(tree.key(nil, entries[1].filepath, false)).presentation.right_text = label
  native.await(tree.apply(bufnr, plan, owner))
end

local result = { rows = owner:linecount(), directories = directories }
result.cold_next = measure(function()
  action.next_entry(ctx)
end)
result.warm_next = measure(function()
  action.next_entry(ctx)
end)
metadata("first")
result.metadata_next = measure(function()
  action.next_entry(ctx)
end)
metadata("second")
result.metadata_global_next = measure(function()
  action.goto_next_entry(ctx)
end)
assert(current.filepath == entries[directories and #entries or 2].filepath)
owner:dispose()
io.stdout:write(vim.json.encode(result), "\n")
