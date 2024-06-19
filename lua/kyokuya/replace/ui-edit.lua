local util_json = require("guanghechen.util.json")
local util_reporter = require("guanghechen.util.reporter")
local Textarea = require("kyokuya.component.textarea")

---@class kyokuya.replacer.IEditConfigOptions
---@field public state kyokuya.types.IReplacerState
---@field public on_confirm fun(next_state: kyokuya.types.IReplacerState):nil

---@class kyokuya.replacer.edit
local M = {}

---@param opts kyokuya.replacer.IEditConfigOptions
---@return nil
function M.edit_replacer_state(opts)
  local state = opts.state
  local lines = util_json.stringify_prettier_lines(state) ---@type string[]

  local textarea = Textarea:new()
  textarea:open({
    icon = " ",
    title = state.mode == "search" and "Search options" or "Replace options",
    value = lines,
    on_confirm = function()
      local bufnr = textarea:get_bufnr() ---@type integer|nil
      if bufnr == nil then
        return
      end

      local content = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n") ---@type string
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
        opts.on_confirm(next_state)
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
    end,
  })

  local bufnr = textarea:get_bufnr()
  if bufnr ~= nil then
    vim.api.nvim_set_option_value("filetype", "json", { buf = bufnr })
  end
end

return M
