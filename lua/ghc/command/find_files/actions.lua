local session = require("ghc.context.session")
local state = require("ghc.command.find_files.state")

---@param scope                         ghc.enums.context.FindScope
---@return nil
local function change_scope(scope)
  local scope_current = session.find_scope:snapshot() ---@type ghc.enums.context.FindScope
  if scope_current ~= scope then
    session.find_scope:next(scope)
  end
end

---@class ghc.command.find_files.actions
local M = {}

---@return nil
function M.edit_config()
  ---@class ghc.command.find_files.IConfigData
  ---@field public exclude_patterns       string[]

  local f_exclude_patterns = session.find_exclude_patterns:snapshot() ---@type string

  ---@type ghc.command.find_files.IConfigData
  local data = {
    exclude_patterns = fml.array.parse_comma_list(f_exclude_patterns),
  }

  local setting = fml.ui.Setting.new({
    position = "center",
    width = 100,
    title = "Edit Configuration (find files)",
    validate = function(raw_data)
      if type(raw_data) ~= "table" then
        return "Invalid find_files configuration, expect an object."
      end
      ---@cast raw_data ghc.command.find_files.IConfigData

      if raw_data.exclude_patterns == nil or not fml.is.array(raw_data.exclude_patterns) then
        return "Invalid data.exclude_patterns, expect an array."
      end
    end,
    on_confirm = function(raw_data)
      local raw = vim.tbl_extend("force", data, raw_data)
      ---@cast raw ghc.command.find_files.IConfigData

      local exclude_patterns = table.concat(raw.exclude_patterns, ",") ---@type string

      session.find_exclude_patterns:next(exclude_patterns)
      state.reload()
    end,
  })
  setting:open({
    initial_value = data,
    text_cursor_row = 1,
    text_cursor_col = 1,
  })
end

---@return nil
function M.change_scope_cwd()
  change_scope("C")
end

---@return nil
function M.change_scope_directory()
  change_scope("D")
end

---@return nil
function M.change_scope_workspace()
  change_scope("W")
end

---@return nil
function M.toggle_case_sensitive()
  local flag = session.find_flag_case_sensitive:snapshot() ---@type boolean
  session.find_flag_case_sensitive:next(not flag)
end

---@return nil
function M.toggle_gitignore()
  local flag = session.find_flag_gitignore:snapshot() ---@type boolean
  session.find_flag_gitignore:next(not flag)
end

---@return nil
function M.toggle_scope()
  local next_scope = session.get_find_scope_carousel_next() ---@type ghc.enums.context.FindScope
  session.find_scope:next(next_scope)
end

return M
