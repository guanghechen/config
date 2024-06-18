local util_json = require("guanghechen.util.json")
local util_reporter = require("guanghechen.util.reporter")

---@class kyokuya.replacer.IEditConfigOptions
---@field public state kyokuya.types.IReplacerState
---@field public on_confirm fun(next_state: kyokuya.types.IReplacerState):nil

---@class kyokuya.replacer.edit
local M = {}

---@param opts kyokuya.replacer.IEditConfigOptions
---@return nil
function M.edit_replacer_state(opts)
  local Popup = require("nui.popup")
  local event = require("nui.utils.autocmd").event

  local state = opts.state
  local on_confirm = opts.on_confirm

  local title = state.mode == "search" and "Search options" or "Replace options"

  local popup = Popup({
    enter = true,
    focusable = true,
    border = {
      style = "rounded",
      text = {
        top = title,
        top_align = "center",
      },
    },
    position = "50%",
    size = {
      width = "80%",
      height = "60%",
    },
  })

  -- mount/open the component
  popup:mount()

  -- unmount component when cursor leaves buffer
  popup:on(event.BufLeave, function()
    popup:unmount()
  end)

  local actions = {
    on_confirm = function()
      local content = table.concat(vim.api.nvim_buf_get_lines(popup.bufnr, 0, -1, false), "\n") ---@type string
      local ok, json = pcall(function()
        return util_json.parse(content)
      end)
      if ok then
        ---@cast json kyokuya.types.IReplacerState
        ---@type kyokuya.types.IReplacerState
        local raw = vim.tbl_extend("force", state, json)

        ---@type kyokuya.types.IReplacerState
        local next_state = {
          cwd = raw.cwd,
          mode = raw.mode,
          flag_regex = raw.flag_regex,
          flag_case_sensitive = raw.flag_case_sensitive,
          search_pattern = raw.search_pattern,
          replace_pattern = raw.replace_pattern,
          search_paths = raw.search_paths,
          include_patterns = raw.include_patterns,
          exclude_patterns = raw.exclude_patterns,
        }
        on_confirm(next_state)
      else
        util_reporter.error({
          from = "kyokuya/replace",
          subject = "ui-edit.edit_replacer_state",
          message = "failed to parse json",
          details = {
            content = content,
            json = json,
          },
        })
      end
      popup:unmount()
    end,
    on_quit = function()
      popup:unmount()
    end,
  }

  vim.api.nvim_set_option_value("filetype", "json", { buf = popup.bufnr })
  popup:map("n", "<cr>", actions.on_confirm, { noremap = true, silent = true, desc = "replace: save changes" })
  popup:map("n", "q", actions.on_quit, { noremap = true, silent = true, desc = "replace: discard changes" })

  -- set content
  local lines = util_json.stringify_prettier_lines(state) ---@type string[]
  vim.api.nvim_buf_set_lines(popup.bufnr, 0, -1, false, lines)
end

return M
