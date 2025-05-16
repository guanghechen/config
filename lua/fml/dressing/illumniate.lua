--- https://github.com/folke/snacks.nvim/blob/d62e7527a5e9608ab0033bc63a329baf8757ea6d/lua/snacks/words.lua#L1

local __module_name__ = "fml.dressing.illumniate" ---@type string

---@class fml.dressing.illumniate.ILspWord
---@field public from { [1]: number, [2]: number }
---@field public to   { [1]: number, [2]: number }

local illuminate_group = eve.nvim.augroup("fml.dressing.illumniate") ---@type integer
local ns = vim.api.nvim_create_namespace("vim_lsp_references") ---@type integer
local ns2 = vim.api.nvim_create_namespace("nvim.lsp.references") ---@type integer

---@class fml.dressing.illumniate.IConfig
local config = {
  debounce = 200, -- time in ms to wait before updating
  notify_jump = false, -- show a notification when jumping
  notify_end = true, -- show a notification when reaching the end
  foldopen = true, -- open folds after jumping
  jumplist = true, -- set jump point before jumping
  modes = { "n", "i", "c" }, -- modes to show references
}

---@param bufnr                         ?integer
---@param modes                         ?boolean if modes is true, also check if the current mode is enabled
---@return boolean
local function is_enabled(bufnr, modes)
  local enabled = eve.context.flight.dressing_illumniate:snapshot() ---@type boolean
  if not enabled then
    return false
  end

  bufnr = bufnr or vim.api.nvim_get_current_buf() ---@type integer
  local buftype = vim.bo[bufnr].buftype ---@type string
  local filetype = vim.bo[bufnr].filetype ---@type string
  if buftype == "nofile" or #filetype < 0 then
    return false
  end

  if modes then
    local mode = vim.api.nvim_get_mode().mode:lower()
    mode = mode:gsub("\22", "v"):gsub("\19", "s")
    mode = mode:sub(1, 2) == "no" and "o" or mode
    mode = mode:sub(1, 1):match("[ncitsvo]") or "n"
    if not vim.tbl_contains(config.modes, mode) then
      return false
    end
  end

  local clients = vim.lsp.get_clients({ bufnr = bufnr })
  for _, client in ipairs(clients) do
    if client:supports_method("textDocument/documentHighlight", bufnr) then
      return true
    end
  end
  return false
end

---@private
---@return fml.dressing.illumniate.ILspWord[]
---@return integer|nil
local function get_reference_words()
  local current = nil ---@type integer|nil
  local extmarks = {} ---@type vim.api.keyset.get_extmark_item[]
  local words = {} ---@type fml.dressing.illumniate.ILspWord[]

  local cursor = vim.api.nvim_win_get_cursor(0)
  vim.list_extend(extmarks, vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, { details = true }))
  vim.list_extend(extmarks, vim.api.nvim_buf_get_extmarks(0, ns2, 0, -1, { details = true }))
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

eve.fn.observe({ eve.context.flight.dressing_illumniate }, function()
  local enabled = eve.context.flight.dressing_illumniate:snapshot() ---@type boolean

  if enabled then
    vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "ModeChanged" }, {
      group = illuminate_group,
      callback = function()
        if not is_enabled(nil, true) then
          vim.lsp.buf.clear_references()
          return
        end

        local _, reference_cur = get_reference_words()
        if not reference_cur then
          local buf = vim.api.nvim_get_current_buf()
          std.timer.set_timeout(function()
            if vim.api.nvim_buf_is_valid(buf) then
              vim.api.nvim_buf_call(buf, function()
                if not is_enabled(nil, true) then
                  return
                end
                vim.lsp.buf.document_highlight()
                vim.lsp.buf.clear_references()
              end)
            end
          end, config.debounce)
        end
      end,
    })
  else
    vim.api.nvim_del_augroup_by_id(illuminate_group)
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
      vim.api.nvim_buf_clear_namespace(buf, ns2, 0, -1)
    end
  end
end)

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
