---@class era.m.wk.extras
---@field public expand                 era.m.wk.extras.expand
local M = {}

---@class era.m.wk.extras.expand
---@field public buf                    fun(): era.m.wk.IMapping[]
---@field public win                    fun(): era.m.wk.IMapping[]
M.expand = {}

---Get buffer name for display
---@param bufnr                          integer
---@return string
local function get_bufname(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  return name == "" and "[No Name]" or vim.fn.fnamemodify(name, ":~:.")
end

---Expand buffer-related keymaps (compatible with which-key.extras.expand.buf)
---@return era.m.wk.IMapping[]
function M.expand.buf()
  local ret = {} ---@type era.m.wk.IMapping[]
  local current_bufnr = vim.api.nvim_get_current_buf()

  -- Get all listed buffers except current
  local bufnrs = vim.tbl_filter(function(bufnr)
    return bufnr ~= current_bufnr and vim.bo[bufnr].buflisted
  end, vim.api.nvim_list_bufs())

  -- Sort by name and limit to 10
  table.sort(bufnrs, function(a, b)
    return get_bufname(a) < get_bufname(b)
  end)

  bufnrs = vim.list_slice(bufnrs, 1, 10)

  -- Create mappings for each buffer
  for i, bufnr in ipairs(bufnrs) do
    local name = get_bufname(bufnr)
    local glyph, hl = stl.fileicon.get_file_icon(name)
    ret[#ret + 1] = {
      tostring(i - 1),
      function()
        vim.api.nvim_set_current_buf(bufnr)
      end,
      desc = name,
      icon = { icon = glyph, hl = hl },
    }
  end

  return ret
end

---Expand window-related keymaps (compatible with .extras.expand.win)
---@return era.m.wk.IMapping[]
function M.expand.win()
  local ret = {} ---@type era.m.wk.IMapping[]
  local current_winnr = vim.api.nvim_get_current_win()

  -- Get all windows except current and floating windows
  local winnrs = {} ---@type integer[]
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    local is_float = vim.api.nvim_win_get_config(w).relative ~= ""
    if w ~= current_winnr and not is_float then
      table.insert(winnrs, w)
    end
  end

  -- Sort by buffer name and limit to 10
  table.sort(winnrs, function(a, b)
    local bufnr_a = vim.api.nvim_win_get_buf(a)
    local bufnr_b = vim.api.nvim_win_get_buf(b)
    return get_bufname(bufnr_a) < get_bufname(bufnr_b)
  end)

  winnrs = vim.list_slice(winnrs, 1, 10)

  -- Create mappings for each window
  for i, winnr in ipairs(winnrs) do
    local bufnr = vim.api.nvim_win_get_buf(winnr)
    local name = get_bufname(bufnr)
    local glyph, hl = stl.fileicon.get_file_icon(name)
    ret[#ret + 1] = {
      tostring(i - 1),
      function()
        vim.api.nvim_set_current_win(winnr)
      end,
      desc = name,
      icon = { icon = glyph, hl = hl },
    }
  end

  return ret
end

return M
