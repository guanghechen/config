local icons = require("ghc.core.setting.icons")

---@class ghc.core.action.window.IHistoryItem
---@field public bufnr number
---@field public filepath string

---@class ghc.core.action.window.IHistoryItemEntry
---@field public display string
---@field public ordinal string
---@field public item ghc.core.action.window.IHistoryItem
---@field public item_index number

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
local histories = {} ---@type table<number, fml.types.collection.IHistory>

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
    history = fml.collection.History.new({
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
  local name = fml.path.relative(fml.path.workspace(), filepath)

  local item = {
    name = name,
    bufnr = bufnr,
    filepath = filepath,
  }
  history:push(item)
end

---@param opts { unique: boolean }
function M.find_history(opts)
  if IGNORED_FILETYPES[vim.bo.filetype] then
    return
  end

  local unique = opts.unique ---@type boolean
  local winnr = vim.api.nvim_get_current_win()
  local history = histories[winnr]
  if history == nil then
    return
  end

  local prompt_title = unique and "window history (unique)" or "window history"
  local entries = {} ---@type ghc.core.action.window.IHistoryItemEntry[]
  local cwd = fml.path.cwd()
  local minwidth = #prompt_title + 16 ---@type number
  local default_lnum = 1 ---@type number
  if unique then
    local present_item = history:present()
    local present_filepath = present_item and present_item.filepath or "" ---@type string
    local visited = {} ---@type table<string, boolean>
    for item, item_index in history:iterator_reverse() do
      ---@cast item ghc.core.action.window.IHistoryItem
      local relative_filepath = fml.path.relative(cwd, item.filepath)
      if not visited[relative_filepath] then
        visited[relative_filepath] = true

        local display_text ---@type string
        if present_filepath == item.filepath then
          display_text = icons.ui.Separator .. " " .. relative_filepath
          default_lnum = #entries + 1
        else
          display_text = "  " .. relative_filepath
        end
        minwidth = minwidth < #display_text and #display_text or minwidth

        ---@type ghc.core.action.window.IHistoryItemEntry
        local entry = {
          display = display_text,
          ordinal = relative_filepath,
          item = item,
          item_index = item_index,
        }
        table.insert(entries, entry)
      end
    end
  else
    local present_index = history:present_index() ---@type number
    for item, item_index in history:iterator_reverse() do
      ---@cast item ghc.core.action.window.IHistoryItem
      local relative_filepath = fml.path.relative(cwd, item.filepath)

      local display_text ---@type string
      if present_index == item_index then
        display_text = icons.ui.Separator .. " " .. tostring(item_index) .. " " .. relative_filepath
        default_lnum = #entries + 1
      else
        display_text = "  " .. tostring(item_index) .. " " .. relative_filepath
      end
      minwidth = minwidth < #display_text and #display_text or minwidth

      ---@type ghc.core.action.window.IHistoryItemEntry
      local entry = {
        display = display_text,
        ordinal = relative_filepath,
        item = item,
        item_index = item_index,
      }
      table.insert(entries, entry)
    end
  end

  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local conf = require("telescope.config").values
  local finders = require("telescope.finders")
  local pickers = require("telescope.pickers")
  local themes = require("telescope.themes")

  local picker_opts = themes.get_dropdown({ -- themes.get_cursor
    cwd = cwd,
    initial_mode = "normal",
    layout_config = {
      width = function(_, max_columns)
        return math.min(minwidth + 10, max_columns)
      end,
      height = function(_, _, max_lines)
        return math.min(max_lines, #entries + 6)
      end,
    },
  })
  pickers
    .new(picker_opts, {
      prompt_title = prompt_title,
      finder = finders.new_table({
        results = entries,
        entry_maker = function(entry)
          return entry
        end,
      }),
      sorter = conf.generic_sorter(picker_opts),
      attach_mappings = function(prompt_bufnr, map)
        local function set_selection()
          local picker = action_state.get_current_picker(prompt_bufnr)
          if picker ~= nil then
            picker:set_selection(default_lnum - 1)
          end
        end

        map("n", "<C-r>", set_selection)

        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          history:go(selection.item_index)
          return false
        end)

        vim.defer_fn(set_selection, 32)
        return true
      end,
    })
    :find()
end

function M.find_history_unique()
  M.find_history({ unique = true })
end

function M.find_history_all()
  M.find_history({ unique = false })
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