---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.diffview.pane.tree" ---@type string

local Source = require("era.view.result_source")
local ResultTree = require("era.view.result_tree")
local owners = {} ---@type table<integer, era.view.ResultTree>
local M = {}
M.root = "diffview"

---@param scope                         ?string
---@param path                          string
---@param directory                     boolean
---@return string
function M.key(scope, path, directory)
  return (scope or "")
    .. (directory and ":d:" or ":f:")
    .. path:gsub(".", function(byte)
      return string.format("%02x", byte:byte())
    end)
end

---@return era.view.ResultTree
function M.new()
  return ResultTree.new({
    name = "Diffview",
    tree = Source.new(M.root),
    present = function(_, data)
      return vim.deepcopy(data.presentation or { label = "" })
    end,
  })
end

---@param entries                       era.m.diffview.IFileEntry[]
---@return era.m.diffview.IFileEntry[]
function M.sorted_entries(entries)
  local items = {}
  for _, entry in ipairs(entries) do
    items[#items + 1] = { entry = entry, parts = vim.split(entry.filepath, "/", { plain = true }) }
  end
  table.sort(items, function(left, right)
    for index = 1, math.min(#left.parts, #right.parts) do
      local a, b = left.parts[index], right.parts[index]
      local adir, bdir = index < #left.parts, index < #right.parts
      if adir ~= bdir then
        return adir
      end
      if a ~= b then
        return a < b
      end
    end
    return #left.parts < #right.parts
  end)
  local sorted = {}
  for _, item in ipairs(items) do
    sorted[#sorted + 1] = item.entry
  end
  return sorted
end

---@param options                       ?table
---@return table
function M.plan(options)
  options = options or {}
  local mode = options.viewtype or dot.context.diffview.flag_panel_viewtype:snapshot()
  local compress = options.foldempty
  if compress == nil then
    compress = dot.context.diffview.flag_foldempty:snapshot()
  end
  return {
    source = Source.new(M.root),
    entries = { [M.root] = { nodetype = "container", foldable = false } },
    mode = mode,
    foldempty = compress,
    default_closed = {},
    orders = {},
  }
end

---@param plan                          table
---@param files                         era.m.diffview.IFileEntry[]
---@param scope                         ?string
---@param commit                        ?era.m.diffview.ICommit
---@return integer
function M.files(plan, files, scope, commit)
  local util = require("era.m.diffview.util")
  local parent = scope or M.root
  local count = 0
  for _, entry in ipairs(M.sorted_entries(files)) do
    local filepath = entry.filepath
    local parts = vim.split(filepath, "/", { plain = true })
    local owner, path = parent, ""
    for index = 1, #parts - 1 do
      path = path == "" and parts[index] or path .. "/" .. parts[index]
      local key = M.key(scope, path, true)
      if not plan.source:contains(key) then
        local name = vim.fn.strtrans(parts[index])
        plan.source:insert(owner, key, {
          presentation = { label = name, icon = "", highlight = "m_ft_dirname", fields = { directory_icon = name } },
          item = { type = "directory", uuid = path, filepath = path, stage_type = entry.stage_type, commit = commit },
        })
        plan.entries[key] = { nodetype = "container" }
        count = count + 1
      end
      owner = key
    end
    local key = M.key(scope, filepath, false)
    local right = {}
    if entry.insertions and entry.insertions > 0 then
      right[#right + 1] = "+" .. entry.insertions
    end
    if entry.deletions and entry.deletions > 0 then
      right[#right + 1] = "-" .. entry.deletions
    end
    right[#right + 1] = entry.status or ""
    local name = vim.fn.strtrans(parts[#parts])
    plan.source:insert(owner, key, {
      presentation = {
        label = name,
        fields = { file_icon = name },
        highlight = util.get_status_hlgroup(entry.status or ""),
        right_text = table.concat(right, " "),
      },
      item = { type = "file", uuid = filepath, stage_type = entry.stage_type, commit = commit, entry = entry },
    })
    plan.entries[key] = { nodetype = "leaf" }
    plan.orders[#plan.orders + 1] = key
    count = count + 1
  end
  return count
end

---@param bufnr                         ?integer Nil publishes logical state without a surface.
---@param plan                          table
---@param owner                         ?era.view.ResultTree
---@param on_frame                      ?fun(frame: yoz.ux.treeview.Frame): nil
---@param on_attach                     ?fun(view: ux.treeview.View): nil
---@return stl.c.Future
function M.apply(bufnr, plan, owner, on_frame, on_attach)
  owner = owner or bufnr and owners[bufnr] or M.new()
  if bufnr and not owners[bufnr] then
    vim.api.nvim_create_autocmd("BufWipeout", {
      buf = bufnr,
      once = true,
      callback = function()
        owners[bufnr] = nil
      end,
    })
    owners[bufnr] = owner
  end
  -- Producers describe records; native Data keeps identity across successive imports.
  owner.source, owner.entries = plan.source, plan.entries
  owner:invalidate()
  if bufnr then
    for _, winnr in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_buf(winnr) == bufnr then
        owner:mount(winnr, bufnr, on_frame or function() end, on_attach)
        break
      end
    end
  end
  return owner
    :publish({
      mode = plan.inline and "tree" or plan.mode,
      list_text = "ancestry",
      list_from_depth = plan.inline and plan.mode == "list" and 1 or nil,
      rootuuid = M.root,
      foldempty = plan.foldempty,
      default_closed = plan.default_closed,
      orders = plan.orders,
    })
    :then_(function(reply)
      if reply.kind == "Rejected" then
        error(reply.error)
      end
      return owner:ready()
    end)
end

---@param bufnr                         integer
---@return era.view.ResultTree|nil
function M.owner(bufnr)
  return owners[bufnr]
end

---@param bufnr                         integer
---@param row                           integer
---@return table|nil
function M.item(bufnr, row)
  local owner = owners[bufnr]
  local key = owner and owner:retrieve_uuid(row)
  local data = key and owner:data(key)
  return data and data.item
end

---@param bufnr                         integer
---@return yoz.ux.treeview.Frame|nil
function M.navigation(bufnr)
  local owner = owners[bufnr]
  return owner and owner:frame()
end

---@param frame                         ?yoz.ux.treeview.Frame
---@param row                           integer
---@return integer|nil
function M.parent(frame, row)
  return frame and frame:navigate(row, "parent")
end

---@param frame                         ?yoz.ux.treeview.Frame
---@param row                           integer
---@return integer|nil
function M.last_child(frame, row)
  return frame and frame:navigate(row, "last_child_or_sibling")
end

---@param direction                     string
---@return nil
function M.navigate(direction)
  local owner = owners[vim.api.nvim_get_current_buf()]
  if owner and owner.view then
    owner.view:navigate(direction)
  end
end

return M
