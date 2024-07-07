local constant = require("fml.constant")
local path = require("fml.std.path")
local std_array = require("fml.std.array")
local std_object = require("fml.std.object")

---@class fml.api.state
---@field public BUF_IGNORED_FILETYPES  table<string, boolean>
---@field public bufs                   table<integer, fml.api.state.IBufItem>
local M = require("fml.api.state.mod")

M.BUF_IGNORED_FILETYPES = {
  ["PlenaryTestPopup"] = true,
  ["TelescopePrompt"] = true,
  ["Trouble"] = true,
  ["checkhealth"] = true,
  ["lspinfo"] = true,
  ["neo-tree"] = true,
  ["notify"] = true,
  ["startuptime"] = true,
  ["term"] = true,
}
M.bufs = {}

---@param bufnrs                        integer[]
---@return nil
function M.close_bufs(bufnrs)
  if #bufnrs < 1 then
    return
  end

  local tab, tabnr_cur = M.get_current_tab()
  if tab == nil then
    return
  end

  local bufnr_set = {} ---@type table<integer, boolean>
  for _, bufnr in ipairs(bufnrs) do
    bufnr_set[bufnr] = true
  end
  std_array.filter_inline(tab.bufnrs, function(bufnr)
    return not bufnr_set[bufnr]
  end)

  if #tab.bufnrs < 1 then
    M.close_tab(tabnr_cur)
  end

  for bufnr in pairs(bufnr_set) do
    local buf = M.bufs[bufnr]
    if buf ~= nil then
      local copies = M.count_buf_copies(bufnr)
      if copies <= 1 then
        M.bufs[bufnr] = nil
        if M.validate_buf(bufnr) then
          vim.api.nvim_buf_delete(bufnr, { force = true })
        end
      end
    end
  end
  M.schedule_refresh()
end

---@param bufnr                         integer
---@return integer
function M.count_buf_copies(bufnr)
  local copies = 0 ---@type integer
  for _, tab in pairs(M.tabs) do
    if std_array.contains(tab.bufnrs, bufnr) then
      copies = copies + 1
    end
  end
  return copies
end

---@return nil
function M.refresh_bufs()
  local bufnrs = vim.api.nvim_list_bufs() ---@type integer[]
  local valid_bufnr_set = {} ---@type table<integer, boolean>
  for _, bufnr in ipairs(bufnrs) do
    valid_bufnr_set[bufnr] = true
    M.refresh_buf(bufnr)
  end
  std_object.filter_inline(M.bufs, function(bufnr)
    return not not valid_bufnr_set[bufnr]
  end)
end

---@param bufnr                         integer|nil
---@return nil
function M.refresh_buf(bufnr)
  if bufnr == nil or type(bufnr) ~= "number" then
    return
  end

  if not M.validate_buf(bufnr) then
    M.bufs[bufnr] = nil
    return
  end

  local buf = M.bufs[bufnr] ---@type fml.api.state.IBufItem|nil
  local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
  if buf == nil then
    local filename = path.basename(filepath) ---@type string
    filename = (not filename or filename == "") and constant.BUF_UNTITLED or filename

    ---@type fml.api.state.IBufItem
    buf = {
      filepath = filepath,
      filename = filename,
      pinned = false,
    }
    M.bufs[bufnr] = buf
  elseif buf.filepath ~= filepath then
    local filename = path.basename(filepath) ---@type string
    filename = (not filename or filename == "") and constant.BUF_UNTITLED or filename
    buf.filepath = filepath
    buf.filename = filename
    return
  end
end

---@param bufnr                         integer
---@return boolean
function M.validate_buf(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end

  if vim.fn.buflisted(bufnr) ~= 1 then
    return false
  end

  local filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr })
  return not M.BUF_IGNORED_FILETYPES[filetype]
end
