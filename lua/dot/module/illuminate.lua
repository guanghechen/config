---@see https://github.com/folke/snacks.nvim/blob/fe7cfe9800a182274d0f868a74b7263b8c0c020b/lua/snacks/words.lua#L1

local __module_name__ = "dot.module.illuminate" ---@type string

---@class dot.module.illuminate.ILspWord
---@field public from                   { [1]: integer, [2]: integer }
---@field public to                     { [1]: integer, [2]: integer }

---@alias dot.module.illuminate.IMode
---| "n"
---| "i"
---| "c"
---| "t"
---| "s"
---| "v"
---| "o"

---@class dot.module.illuminate.IConfig
---@field public debounce               integer
---@field public notify_jump            boolean
---@field public notify_end             boolean
---@field public foldopen               boolean
---@field public jumplist               boolean
---@field public modes                  dot.module.illuminate.IMode[]

local ns_lsp_ref = vim.api.nvim_create_namespace("vim_lsp_references") ---@type integer
local ns_nvim_ref = vim.api.nvim_create_namespace("nvim.lsp.references") ---@type integer
local augroup = ark.vim.fn.augroup(__module_name__) ---@type integer
local timer = assert(vim.uv.new_timer()) ---@type uv.uv_timer_t
local attached_buffers = {} ---@type table<integer, boolean>

---@type dot.module.illuminate.IConfig
local config = {
  debounce = 200,
  notify_jump = false,
  notify_end = true,
  foldopen = true,
  jumplist = true,
  modes = { "n", "i", "c" },
}

---@param bufnr                         integer
---@return boolean
local function has_highlight_capability(bufnr)
  local clients = vim.lsp.get_clients({ bufnr = bufnr, method = "textDocument/documentHighlight" })
  return #clients > 0
end

---@return dot.module.illuminate.IMode
local function get_current_mode()
  local mode = vim.api.nvim_get_mode().mode:lower()
  mode = mode:gsub("\22", "v"):gsub("\19", "s")
  mode = mode:sub(1, 2) == "no" and "o" or mode
  ---@diagnostic disable-next-line: return-type-mismatch
  return mode:sub(1, 1):match("[ncitsvo]") or "n"
end

---@return boolean
local function is_mode_enabled()
  local mode = get_current_mode()
  return vim.tbl_contains(config.modes, mode)
end

---@param bufnr                         integer
---@return dot.module.illuminate.ILspWord[]
---@return integer|nil
local function get_reference_words(bufnr)
  local extmarks = {} ---@type vim.api.keyset.get_extmark_item[]
  local words = {} ---@type dot.module.illuminate.ILspWord[]

  local cursor = vim.api.nvim_win_get_cursor(0)
  vim.list_extend(extmarks, vim.api.nvim_buf_get_extmarks(bufnr, ns_lsp_ref, 0, -1, { details = true }))
  vim.list_extend(extmarks, vim.api.nvim_buf_get_extmarks(bufnr, ns_nvim_ref, 0, -1, { details = true }))

  for _, extmark in ipairs(extmarks) do
    words[#words + 1] = {
      from = { extmark[2] + 1, extmark[3] },
      to = { extmark[4].end_row + 1, extmark[4].end_col },
    }
  end

  table.sort(words, function(a, b)
    if a.from[1] ~= b.from[1] then
      return a.from[1] < b.from[1]
    end
    return a.from[2] < b.from[2]
  end)

  local current = nil ---@type integer|nil
  for i, w in ipairs(words) do
    if cursor[1] >= w.from[1] and cursor[1] <= w.to[1] and cursor[2] >= w.from[2] and cursor[2] <= w.to[2] then
      current = i
      break
    end
  end

  return words, current
end

local function update_highlight()
  local bufnr = vim.api.nvim_get_current_buf()
  timer:stop()
  timer:start(config.debounce, 0, function()
    vim.schedule(function()
      if vim.api.nvim_get_current_buf() ~= bufnr or not attached_buffers[bufnr] then
        return
      end
      if not is_mode_enabled() or not has_highlight_capability(bufnr) then
        return
      end
      vim.lsp.buf.clear_references()
      vim.lsp.buf.document_highlight()
    end)
  end)
end

local function clear_highlight()
  timer:stop()
  if not is_mode_enabled() then
    vim.lsp.buf.clear_references()
    return
  end
  local _, current = get_reference_words(vim.api.nvim_get_current_buf())
  if not current then
    update_highlight()
  end
end

---@class dot.module.illuminate
local M = {}

---@param step                          integer
---@param cycle                         boolean
---@return nil
function M.jump(step, cycle)
  local bufnr = vim.api.nvim_get_current_buf()
  local words, current_index = get_reference_words(bufnr)

  if not current_index then
    stl.reporter.warn({
      from = __module_name__,
      subject = "jump",
      message = "Cursor not on a reference word",
    })
    return
  end

  local new_index = current_index + step
  if cycle then
    new_index = (new_index - 1) % #words + 1
  end

  local target = words[new_index]
  if target then
    if config.jumplist then
      vim.cmd.normal({ "m`", bang = true })
    end
    vim.api.nvim_win_set_cursor(0, target.from)
    if config.notify_jump then
      stl.reporter.info({
        from = __module_name__,
        subject = "jump",
        message = ("Reference [%d/%d]"):format(new_index, #words),
      })
    end
    if config.foldopen then
      vim.cmd.normal({ "zv", bang = true })
    end
  elseif config.notify_end then
    stl.reporter.warn({
      from = __module_name__,
      subject = "jump",
      message = "No more references",
    })
  end
end

---@param bufnr                         integer
---@return nil
function M.dressing(bufnr)
  local enabled = dot.context.flight.dressing_illuminate:snapshot() ---@type boolean
  if not enabled or attached_buffers[bufnr] then
    return
  end

  if not has_highlight_capability(bufnr) then
    return
  end

  attached_buffers[bufnr] = true

  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "ModeChanged" }, {
    group = augroup,
    buffer = bufnr,
    callback = clear_highlight,
  })

  vim.api.nvim_create_autocmd("BufDelete", {
    group = augroup,
    buffer = bufnr,
    callback = function()
      attached_buffers[bufnr] = nil
    end,
  })
end

---@param bufnr                         integer
---@return nil
function M.undressing(bufnr)
  attached_buffers[bufnr] = nil
  timer:stop()
  vim.lsp.buf.clear_references()
  vim.api.nvim_clear_autocmds({
    group = augroup,
    buffer = bufnr,
  })
end

return M
