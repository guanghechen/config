local path = require("fml.std.path")
local reporter = require("fml.std.reporter")
local state = require("fml.api.state")

---@class fml.api.win
local M = require("fml.api.win.mod")

---@return nil
function M.back()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local win = state.wins[winnr]
  if win == nil then
    reporter.error({
      from = "fml.api.win",
      subject = "back",
      message = "Cannot find window.",
      details = { winnr = winnr },
    })
    return
  end

  local bufnr_cur = vim.api.nvim_get_current_buf() ---@type integer
  local bufnr_last = win.buf_history:back(1) ---@type integer
  if bufnr_cur ~= bufnr_last and bufnr_last ~= nil then
    vim.api.nvim_win_set_buf(winnr, bufnr_last)
  end
end

function M.forward()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local win = state.wins[winnr]
  if win == nil then
    reporter.error({
      from = "fml.api.win",
      subject = "back",
      message = "Cannot find window.",
      details = { winnr = winnr },
    })
    return
  end

  local bufnr_cur = vim.api.nvim_get_current_buf() ---@type integer
  local bufnr_next = win.buf_history:forward(1) ---@type integer
  if bufnr_cur ~= bufnr_next and bufnr_next ~= nil then
    vim.api.nvim_win_set_buf(winnr, bufnr_next)
  end
end

---@param opts { unique: boolean }
function M.find_history(opts)
  local unique = opts.unique ---@type boolean
  local winnr = vim.api.nvim_get_current_win()
  local win = state.wins[winnr] ---@type fml.api.state.IWinItem|nil
  if win == nil then
    reporter.error({
      from = "fml.api.win",
      subject = "find_history",
      message = "Cannot find window.",
      details = { winnr = winnr, unique = unique },
    })
    return
  end

  local prompt_title = unique and "window history (unique)" or "window history"
  local entries = {} ---@type fml.api.win.IHistoryItemEntry[]
  local cwd = path.cwd()
  local minwidth = #prompt_title + 16 ---@type number
  local default_lnum = 1 ---@type number
  if unique then
    local present_bufnr = win.buf_history:present()
    local present_buf = state.bufs[present_bufnr]
    local present_filepath = present_buf and present_buf.filepath or "" ---@type string
    local visited = {} ---@type table<string, boolean>
    for bufnr, index in win.buf_history:iterator_reverse() do
      local buf = state.bufs[bufnr]
      if buf ~= nil then
        local relative_filepath = path.relative(cwd, buf.filepath)
        if not visited[relative_filepath] then
          visited[relative_filepath] = true

          local display_text ---@type string
          if present_filepath == buf.filepath then
            display_text = fml.ui.icons.ui.Separator .. " " .. relative_filepath
            default_lnum = #entries + 1
          else
            display_text = "  " .. relative_filepath
          end
          minwidth = minwidth < #display_text and #display_text or minwidth

          ---@type fml.api.win.IHistoryItemEntry
          local entry = {
            display = display_text,
            ordinal = relative_filepath,
            item = { bufnr = bufnr, filepath = buf.filepath },
            item_index = index
          }
          table.insert(entries, entry)
        end
      end
    end
  else
    local present_index = win.buf_history:present_index() ---@type number
    for bufnr, index in win.buf_history:iterator_reverse() do
      local buf = state.bufs[bufnr]
      if buf ~= nil then
        local relative_filepath = path.relative(cwd, buf.filepath)

        local display_text ---@type string
        if present_index == index then
          display_text = fml.ui.icons.ui.Separator .. " " .. tostring(index) .. " " .. relative_filepath
          default_lnum = #entries + 1
        else
          display_text = "  " .. tostring(index) .. " " .. relative_filepath
        end
        minwidth = minwidth < #display_text and #display_text or minwidth

        ---@type fml.api.win.IHistoryItemEntry
        local entry = {
          display = display_text,
          ordinal = relative_filepath,
          item = { bufnr = bufnr, filepath = buf.filepath },
          item_index = index,
        }
        table.insert(entries, entry)
      end
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
            win.buf_history:go(selection.item_index)
            vim.api.nvim_win_set_buf(winnr, selection.item.bufnr)
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

function M.show_history()
  local winnr = vim.api.nvim_get_current_win()
  local win = state.wins[winnr]
  if win == nil then
    reporter.error({
      from = "fml.api.win",
      subject = "show_history",
      message = "Cannot find window.",
      details = { winnr = winnr },
    })
    return
  end
  win.buf_history:print()
end
