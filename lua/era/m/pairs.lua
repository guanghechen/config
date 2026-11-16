---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.pairs" ---@type string

---@class era.m.pairs.IEntry
---@field public document               yoz.pairs.Document
---@field public changedtick            integer The buffer's changedtick the document reflects.

--- Pair tokens of source buffers: a `yoz.pairs` document per buffer, parsed on first use and kept in sync with line
--- edits. Rows and columns are zero-based; columns are bytes.
---@class era.m.pairs
local M = {}

---@type table<integer, era.m.pairs.IEntry|false> False for a buffer without a pairs language.
local entries = {}
local initialized = false ---@type boolean

---@param bufnr                         integer
---@return integer
local function tab_width(bufnr)
  local width = vim.api.nvim_get_option_value("shiftwidth", { buf = bufnr }) ---@type integer
  if width == 0 then
    width = vim.api.nvim_get_option_value("tabstop", { buf = bufnr })
  end
  return math.max(width, 2)
end

--- The pairs language of a filetype: blink.pairs' filetype map, then its treesitter language and that language's
--- filetypes.
---@param filetype                      string
---@return string|nil
function M.language_of(filetype)
  if filetype == "" or filetype == stl.filetype.BIGFILE or stl.filetype.is_not_sourcefile(filetype) then
    return nil
  end
  local language = yoz.pairs.language(filetype) ---@type string|nil
  if language then
    return language
  end
  -- The language comes first among its filetypes.
  local lang = vim.treesitter.language.get_lang(filetype) or filetype ---@type string
  for _, candidate in ipairs(vim.treesitter.language.get_filetypes(lang)) do
    language = yoz.pairs.language(candidate)
    if language then
      return language
    end
  end
  return nil
end

--- Rereads the whole buffer into its document.
---@param bufnr                         integer
---@param entry                         era.m.pairs.IEntry
---@return nil
local function sync(bufnr, entry)
  local document = entry.document
  document:edit(0, document:line_count(), vim.api.nvim_buf_get_lines(bufnr, 0, -1, false))
  entry.changedtick = vim.api.nvim_buf_get_changedtick(bufnr)
end

---@param bufnr                         integer
---@return era.m.pairs.IEntry|false
local function attach(bufnr)
  local language = M.language_of(vim.api.nvim_get_option_value("filetype", { buf = bufnr }))
  if not language then
    return false
  end
  local entry = { document = yoz.pairs.new(language, tab_width(bufnr)), changedtick = 0 } ---@type era.m.pairs.IEntry
  sync(bufnr, entry)
  vim.api.nvim_buf_attach(bufnr, false, {
    on_lines = function(_, _, changedtick, first, old_last, new_last)
      if entries[bufnr] ~= entry then
        return true
      end
      local lines = vim.api.nvim_buf_get_lines(bufnr, first, new_last, false)
      local ok, err = pcall(entry.document.edit, entry.document, first, old_last, lines)
      if not ok then
        entries[bufnr] = false
        stl.reporter.error({
          from = __module_name__,
          subject = "sync",
          message = tostring(err),
          details = { bufnr = bufnr },
        })
        return true
      end
      -- Emptying a buffer reports no lines left, though Neovim keeps one empty line.
      if entry.document:line_count() ~= vim.api.nvim_buf_line_count(bufnr) then
        sync(bufnr, entry)
      else
        entry.changedtick = changedtick
      end
    end,
    on_changedtick = function(_, _, changedtick)
      if entries[bufnr] == entry then
        entry.changedtick = changedtick
      end
    end,
    on_reload = function()
      if entries[bufnr] == entry then
        sync(bufnr, entry)
      end
    end,
    on_detach = function()
      if entries[bufnr] == entry then
        entries[bufnr] = nil
      end
    end,
  })
  return entry
end

--- The document of a loaded source buffer, parsed now if it has none yet; nil when the buffer has no pairs language,
--- or while a command-line preview (`inccommand`) shows text the buffer never reported.
---@param bufnr                         integer
---@return yoz.pairs.Document|nil
function M.document(bufnr)
  local entry = entries[bufnr]
  if entry == nil then
    if not vim.api.nvim_buf_is_loaded(bufnr) then
      return nil
    end
    M.setup()
    entry = attach(bufnr)
    entries[bufnr] = entry
  end
  if not entry then
    return nil
  end
  if vim.api.nvim_buf_get_changedtick(bufnr) ~= entry.changedtick then
    if vim.api.nvim_get_mode().mode:sub(1, 1) == "c" then
      return nil
    end
    -- A preview ended without an edit, or a change went unreported.
    sync(bufnr, entry)
  end
  return entry.document
end

---@return nil
function M.setup()
  if initialized then
    return
  end
  initialized = true
  local augroup = stl.nvim.fn.augroup(__module_name__) ---@type integer
  -- A forgotten buffer's document is parsed again on its next use.
  vim.api.nvim_create_autocmd({ "FileType", "BufUnload" }, {
    group = augroup,
    callback = function(ev)
      entries[ev.buf] = nil
    end,
  })
  vim.api.nvim_create_autocmd("OptionSet", {
    group = augroup,
    pattern = { "shiftwidth", "tabstop" },
    callback = function()
      for bufnr, entry in pairs(entries) do
        if entry and vim.api.nvim_buf_is_valid(bufnr) then
          entry.document:set_tab_width(tab_width(bufnr))
        end
      end
    end,
  })
end

return M
