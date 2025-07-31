--- https://github.com/folke/snacks.nvim/blob/d62e7527a5e9608ab0033bc63a329baf8757ea6d/lua/snacks/words.lua#L1

local __module_name__ = "fml.dressing.illumniate" ---@type string

---@class fml.dressing.illumniate.ILspWord
---@field public from { [1]: number, [2]: number }
---@field public to   { [1]: number, [2]: number }

local nsnr = vim.api.nvim_create_namespace("nvim.lsp.references") ---@type integer

---@class fml.dressing.illumniate.IConfig
local config = {
  notify_jump = false, -- show a notification when jumping
  notify_end = true, -- show a notification when reaching the end
  foldopen = true, -- open folds after jumping
  jumplist = true, -- set jump point before jumping
}

---@private
---@return fml.dressing.illumniate.ILspWord[]
---@return integer|nil
local function get_reference_words()
  local current = nil ---@type integer|nil
  local extmarks = {} ---@type vim.api.keyset.get_extmark_item[]
  local words = {} ---@type fml.dressing.illumniate.ILspWord[]

  local cursor = vim.api.nvim_win_get_cursor(0)
  vim.list_extend(extmarks, vim.api.nvim_buf_get_extmarks(0, nsnr, 0, -1, { details = true }))
  for _, extmark in ipairs(extmarks) do
    local w = {
      from = { extmark[2] + 1, extmark[3] },
      to = { extmark[4].end_row + 1, extmark[4].end_col },
    }
    words[#words + 1] = w
    if cursor[1] >= w.from[1] and cursor[1] <= w.to[1] and cursor[2] >= w.from[2] and cursor[2] <= w.to[2] then
      current = #words
    end
  end
  return words, current
end

---@class fml.dressing.illumniate
local M = {}

---@param step                          integer
---@param cycle                         boolean
---@return nil
function M.jump(step, cycle)
  local reference_words, current_index = get_reference_words()
  if not current_index then
    return
  end

  current_index = current_index + step
  if cycle then
    current_index = (current_index - 1) % #reference_words + 1
  end

  local target = reference_words[current_index]
  if target then
    if config.jumplist then
      vim.cmd.normal({ "m`", bang = true })
    end
    vim.api.nvim_win_set_cursor(0, target.from)
    if config.notify_jump then
      std.reporter.info({
        from = __module_name__,
        subject = "jump",
        message = ("Reference [%d/%d]"):format(current_index, #reference_words),
      })
    end
    if config.foldopen then
      vim.cmd.normal({ "zv", bang = true })
    end
  elseif config.notify_end then
    std.reporter.warn({
      from = __module_name__,
      subject = "jump",
      message = "No more references",
    })
  end
end

return M
