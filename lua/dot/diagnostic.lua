---@diagnostic disable-next-line: unused-local
local __module_name__ = "dot.diagnostic" ---@type string

---@class dot.diagnostic.IHiddenMark
---@field public ns                     integer
---@field public id                     integer
---@field public details                vim.api.keyset.extmark_details

---@class dot.diagnostic.IHidden
---@field public row                    integer
---@field public marks                  dot.diagnostic.IHiddenMark[]

---@class dot.diagnostic
local M = {}

local initialized = false ---@type boolean
local hides_cursor_line = false ---@type boolean
local hidden = {} ---@type table<integer, dot.diagnostic.IHidden>

-- Extmark namespaces the built-in virtual text handler draws into, one per diagnostic namespace.
---@return integer[]
local function virtual_text_namespaces()
  local namespaces = {} ---@type integer[]
  for _, ns in pairs(vim.diagnostic.get_namespaces()) do
    local virt_text_ns = ns.user_data.virt_text_ns ---@type integer|nil
    if virt_text_ns ~= nil then
      namespaces[#namespaces + 1] = virt_text_ns
    end
  end
  return namespaces
end

---@param bufnr                         integer
---@return nil
local function restore(bufnr)
  local entry = hidden[bufnr] ---@type dot.diagnostic.IHidden|nil
  hidden[bufnr] = nil
  if entry == nil or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  for _, mark in ipairs(entry.marks) do
    local position = vim.api.nvim_buf_get_extmark_by_id(bufnr, mark.ns, mark.id, {}) ---@type integer[]
    if position[1] ~= nil then
      pcall(vim.api.nvim_buf_set_extmark, bufnr, mark.ns, position[1], position[2], {
        id = mark.id,
        hl_mode = mark.details.hl_mode,
        virt_text = mark.details.virt_text,
        virt_text_pos = mark.details.virt_text_pos,
        virt_text_hide = mark.details.virt_text_hide,
        virt_text_win_col = mark.details.virt_text_win_col,
      })
    end
  end
end

-- Empties the virtual text on the cursor line of the current window in place, so the extmark keeps
-- tracking its row for the restore.
---@param bufnr                         integer
---@return nil
local function hide(bufnr)
  local row = vim.api.nvim_win_get_cursor(0)[1] - 1 ---@type integer
  local marks = {} ---@type dot.diagnostic.IHiddenMark[]
  for _, ns in ipairs(virtual_text_namespaces()) do
    for _, extmark in ipairs(vim.api.nvim_buf_get_extmarks(bufnr, ns, { row, 0 }, { row, -1 }, { details = true })) do
      local details = extmark[4] ---@type vim.api.keyset.extmark_details
      if details.virt_text ~= nil then
        marks[#marks + 1] = { ns = ns, id = extmark[1], details = details }
        pcall(vim.api.nvim_buf_set_extmark, bufnr, ns, extmark[2], extmark[3], {
          id = extmark[1],
          hl_mode = details.hl_mode,
        })
      end
    end
  end
  hidden[bufnr] = { row = row, marks = marks }
end

-- The built-in `current_line = false` renders every virtual text of the buffer again on each
-- CursorMoved. Here the handler draws every line and only the two rows the cursor leaves and enters
-- change.
---@return nil
local function setup()
  if initialized then
    return
  end
  initialized = true

  local builtin = vim.diagnostic.handlers.virtual_text
  vim.diagnostic.handlers.virtual_text = {
    show = function(namespace, bufnr, diagnostics, opts)
      bufnr = bufnr == 0 and vim.api.nvim_get_current_buf() or bufnr
      -- Showing clears the namespace, and its new extmarks reuse the ids the hidden record points to.
      restore(bufnr)
      builtin.show(namespace, bufnr, diagnostics, opts)
      if hides_cursor_line and bufnr == vim.api.nvim_get_current_buf() then
        hide(bufnr)
      end
    end,
    hide = builtin.hide,
  }

  local augroup = stl.nvim.fn.augroup(__module_name__) ---@type integer
  vim.api.nvim_create_autocmd("CursorMoved", {
    group = augroup,
    callback = function(args)
      local entry = hidden[args.buf] ---@type dot.diagnostic.IHidden|nil
      if not hides_cursor_line or (entry ~= nil and entry.row == vim.api.nvim_win_get_cursor(0)[1] - 1) then
        return
      end
      restore(args.buf)
      hide(args.buf)
    end,
  })
  vim.api.nvim_create_autocmd("BufWipeout", {
    group = augroup,
    callback = function(args)
      hidden[args.buf] = nil
    end,
  })
end

-- Virtual lines show the diagnostics of the cursor line, so virtual text leaves that line to them.
---@param enabled                       boolean
---@return nil
function M.set_virtual_text_hides_cursor_line(enabled)
  setup()
  hides_cursor_line = enabled
  if enabled then
    local bufnr = vim.api.nvim_get_current_buf() ---@type integer
    restore(bufnr)
    hide(bufnr)
  else
    for bufnr in pairs(hidden) do
      restore(bufnr)
    end
  end
end

return M
