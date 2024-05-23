local History = require("guanghechen.history.History")
local guanghechen = require("guanghechen")

---@class ghc.core.action.window.IHistoryItem
---@field public bufnr number
---@field public filepath string

local POPUP_WINNR = nil
local IGNORED_FILETYPES = {
  [""] = true,
  ["checkhealth"] = true,
  ["lspinfo"] = true,
  ["neo-tree"] = true,
  ["notify"] = true,
  ["PlenaryTestPopup"] = true,
  ["startuptime"] = true,
  ["term"] = true,
  ["TelescopePrompt"] = true,
  ["Trouble"] = true,
}
local histories = {} ---@type table<number, guanghechen.history.History>

---@param x ghc.core.action.window.IHistoryItem
---@param y ghc.core.action.window.IHistoryItem
---@return integer
local function comparator(x, y)
  if x.bufnr == y.bufnr or x.filepath == y.filepath then
    return 0
  end
  return x.bufnr - y.bufnr
end

---@class ghc.core.action.window
local M = require("ghc.core.action.window.module")

function M.back()
  local winnr = vim.api.nvim_get_current_win() ---@type number
  local history = histories[winnr]

  if history == nil then
    return
  end

  local previous = history:back(1) ---@type ghc.core.action.window.IHistoryItem|nil
  if previous ~= nil then
    vim.api.nvim_set_current_buf(previous.bufnr)
  end
end

function M.forward()
  local winnr = vim.api.nvim_get_current_win() ---@type number
  local history = histories[winnr]

  if history == nil then
    return
  end

  local next = history:forward(1) ---@type ghc.core.action.window.IHistoryItem|nil
  if next ~= nil then
    vim.api.nvim_set_current_buf(next.bufnr)
  end
end

---@param index number
function M.go(index)
  local winnr = vim.api.nvim_get_current_win() ---@type number
  local history = histories[winnr]
  if history == nil then
    return
  end

  local item = history:go(index)
  if item == nil then
    return
  end

  vim.api.nvim_set_current_buf(item.bufnr)
end

function M.push()
  local winnr = vim.api.nvim_get_current_win() ---@type number
  local history = histories[winnr]
  if history == nil then
    history = History.new({
      name = tostring(winnr),
      max_count = 50,
      comparator = comparator,
    })
    histories[winnr] = history
  end

  if IGNORED_FILETYPES[vim.bo.filetype] then
    return
  end

  local bufnr = vim.api.nvim_get_current_buf() ---@type number
  local filepath = vim.api.nvim_buf_get_name(bufnr)
  local name = guanghechen.util.path.relative(guanghechen.util.path.workspace(), filepath)

  local item = {
    name = name,
    bufnr = bufnr,
    filepath = filepath,
  }
  history:push(item)
end

function M.toggle_history_popup()
  if POPUP_WINNR and vim.api.nvim_win_is_valid(POPUP_WINNR) then
    vim.api.nvim_win_close(POPUP_WINNR, true)
    POPUP_WINNR = nil
    return
  end

  if IGNORED_FILETYPES[vim.bo.filetype] then
    return
  end

  local winnr = vim.api.nvim_get_current_win()
  local history = histories[winnr]
  if history == nil then
    return
  end

  local contents = {} ---@type string[]
  local cwd = guanghechen.util.path.cwd()
  local visited = {} ---@type table<string, boolean>
  for item in history:iterator_reverse() do
    ---@cast item ghc.core.action.window.IHistoryItem
    local display_text = guanghechen.util.path.relative(cwd, item.filepath)
    if not visited[display_text] then
      visited[display_text] = true
      table.insert(contents, display_text)
    end
  end

  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local make_entry = require("telescope.make_entry")
  local opts = {
    cwd = cwd,
    initial_mode = "normal",
    entry_maker = make_entry.gen_from_file({ cwd = cwd }),
  }
  pickers
    .new(opts, {
      prompt_title = "window history",
      finder = finders.new_table({ results = contents }),
      previewer = conf.grep_previewer(opts),
      sorter = conf.generic_sorter(opts),
    })
    :find()
end

function M.show_window_history()
  local winnr = vim.api.nvim_get_current_win()
  local history = histories[winnr]
  if history ~= nil then
    history:print()
  end
end

---@param augroup fun(groupname: string): string
function M.register_autocmd_window_history(augroup)
  vim.api.nvim_create_autocmd("BufEnter", {
    group = augroup("window_history_update"),
    callback = function()
      M.push()
    end,
  })

  vim.api.nvim_create_autocmd("WinClosed", {
    group = augroup("window_history_clear"),
    callback = function(args)
      local winnr = args.id ---@type number
      if type(winnr) == "number" then
        histories[winnr] = nil
      end
    end,
  })
end
