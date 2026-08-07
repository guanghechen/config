---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.git.visual" ---@type string

---@class era.m.git.visual.IOwner
---@field autocmd_id                    integer|nil
---@field valid                         boolean

---@class era.m.git.visual
local M = {}

local current_owner = nil ---@type era.m.git.visual.IOwner|nil

---@param owner                         era.m.git.visual.IOwner
local function stop_tracking(owner)
  if current_owner == owner then
    current_owner = nil
  end
  if owner.autocmd_id then
    pcall(vim.api.nvim_del_autocmd, owner.autocmd_id)
    owner.autocmd_id = nil
  end
end

---Leave Visual mode after a successful Future only while this operation still owns the selection.
---@param future                        stl.c.Future
function M.leave_on_success(future)
  if current_owner then
    current_owner.valid = false
    stop_tracking(current_owner)
  end

  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  local visual_mode = vim.api.nvim_get_mode().mode ---@type string
  local visual_start = vim.fn.getpos("v") ---@type integer[]
  local visual_end = vim.fn.getpos(".") ---@type integer[]
  local owner = { autocmd_id = nil, valid = true } ---@type era.m.git.visual.IOwner
  current_owner = owner

  owner.autocmd_id = vim.api.nvim_create_autocmd({ "CursorMoved", "ModeChanged", "BufLeave", "WinLeave" }, {
    buffer = bufnr,
    callback = function()
      owner.valid = false
      if current_owner == owner then
        current_owner = nil
      end
      owner.autocmd_id = nil
      return true
    end,
  })

  future:finally(function(resolved, result)
    local owns_selection = owner.valid and current_owner == owner
    stop_tracking(owner)
    if not owns_selection or not resolved or type(result) ~= "table" or not result.ok then
      return
    end
    if
      not vim.api.nvim_win_is_valid(winnr)
      or vim.api.nvim_get_current_win() ~= winnr
      or vim.api.nvim_win_get_buf(winnr) ~= bufnr
    then
      return
    end
    local mode = vim.api.nvim_get_mode().mode ---@type string
    if
      mode ~= visual_mode
      or not vim.deep_equal(vim.fn.getpos("v"), visual_start)
      or not vim.deep_equal(vim.fn.getpos("."), visual_end)
    then
      return
    end
    vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "nx", false)
  end)
end

return M
