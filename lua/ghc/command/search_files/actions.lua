local session = require("ghc.context.session")
local api = require("ghc.command.search_files.api")
local state = require("ghc.command.search_files.state")

---@param scope                         ghc.enums.context.SearchScope
---@return nil
local function change_scope(scope)
  local scope_current = session.search_scope:snapshot() ---@type ghc.enums.context.SearchScope
  if scope_current ~= scope then
    session.search_scope:next(scope)
  end
end

---@class ghc.command.search_files.actions
local M = {}

---@return nil
function M.change_scope_buffer()
  change_scope("B")
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
function M.edit_config()
  ---@class ghc.command.search_files.IConfigData
  ---@field public search_pattern       string
  ---@field public replace_pattern      string
  ---@field public search_paths         string[]
  ---@field public max_filesize         string
  ---@field public max_matches          integer
  ---@field public include_patterns     string[]
  ---@field public exclude_patterns     string[]

  local s_search_pattern = session.search_pattern:snapshot() ---@type string
  local s_replace_pattern = session.search_replace_pattern:snapshot() ---@type string
  local s_search_paths = session.search_paths:snapshot() ---@type string
  local s_max_filesize = session.search_max_filesize:snapshot() ---@type string
  local s_max_matches = session.search_max_matches:snapshot() ---@type integer
  local s_include_patterns = session.search_include_patterns:snapshot() ---@type string)
  local s_exclude_patterns = session.search_exclude_patterns:snapshot() ---@type string

  ---@type ghc.command.search_files.IConfigData
  local data = {
    search_pattern = s_search_pattern,
    replace_pattern = s_replace_pattern,
    search_paths = fc.array.parse_comma_list(s_search_paths),
    max_filesize = s_max_filesize,
    max_matches = s_max_matches,
    include_patterns = fc.array.parse_comma_list(s_include_patterns),
    exclude_patterns = fc.array.parse_comma_list(s_exclude_patterns),
  }

  local setting = fml.ui.Setting.new({
    position = "center",
    width = 100,
    title = "Edit Configuration (search files)",
    validate = function(raw_data)
      if type(raw_data) ~= "table" then
        return "Invalid search_files configuration, expect an object."
      end
      ---@cast raw_data ghc.command.search_files.IConfigData

      if raw_data.search_pattern == nil or type(raw_data.search_pattern) ~= "string" then
        return "Invalid data.search_pattern, expect an string."
      end

      if raw_data.replace_pattern == nil or type(raw_data.replace_pattern) ~= "string" then
        return "Invalid data.replace_pattern, expect an string."
      end

      if raw_data.search_paths == nil or not fc.is.array(raw_data.search_paths) then
        return "Invalid data.search_paths, expect an array."
      end

      if type(raw_data.max_filesize) ~= "string" then
        return "Invalid data.max_filesize, expect a string."
      end

      if type(raw_data.max_matches) ~= "number" then
        return "Invalid data.max_matches, expect a number."
      end

      if raw_data.include_patterns == nil or not fc.is.array(raw_data.include_patterns) then
        return "Invalid data.include_patterns, expect an array."
      end

      if raw_data.exclude_patterns == nil or not fc.is.array(raw_data.exclude_patterns) then
        return "Invalid data.exclude_patterns, expect an array."
      end
    end,
    on_confirm = function(raw_data)
      vim.schedule(function()
        local raw = vim.tbl_extend("force", data, raw_data)
        ---@cast raw ghc.command.search_files.IConfigData

        local search_pattern = raw.search_pattern ---@type string
        local replace_pattern = raw.replace_pattern ---@type string
        local max_filesize = raw.max_filesize ---@type string
        local max_matches = raw.max_matches ---@type integer
        local search_paths = table.concat(raw.search_paths, ",") ---@type string
        local include_patterns = table.concat(raw.include_patterns, ",") ---@type string
        local exclude_patterns = table.concat(raw.exclude_patterns, ",") ---@type string

        local last_search_pattern = session.search_pattern:snapshot() ---@type string

        session.search_pattern:next(search_pattern)
        session.search_replace_pattern:next(replace_pattern)
        session.search_paths:next(search_paths)
        session.search_max_filesize:next(max_filesize)
        session.search_max_matches:next(max_matches)
        session.search_include_patterns:next(include_patterns)
        session.search_exclude_patterns:next(exclude_patterns)

        if search_pattern ~= last_search_pattern then
          state.reload()
        else
          state.reload()
        end
      end)
      return true
    end,
  })
  setting:open({
    initial_value = data,
    text_cursor_row = 1,
    text_cursor_col = 1,
  })
end

---@return nil
function M.replace_file()
  local search = state.get_search() ---@type fml.types.ui.search.ISearch
  local item = search.state:get_current() ---@type fml.types.ui.search.IItem|nil
  if item ~= nil then
    api.replace_file(item.uuid)
    return
  end
end

---@return nil
function M.replace_file_all()
  api.replace_file_all()
end

---@return nil
function M.send_to_qflist()
  local quickfix_items = api.gen_quickfix_items() ---@type fml.types.IQuickFixItem[]
  if #quickfix_items > 0 then
    vim.fn.setqflist(quickfix_items, "r")
    state.close()

    local ok = pcall(function()
      vim.cmd("Trouble qflist toggle")
    end)

    if not ok then
      vim.cmd("copen")
    end
  end
end

---@return nil
function M.toggle_case_sensitive()
  local flag = session.search_flag_case_sensitive:snapshot() ---@type boolean
  session.search_flag_case_sensitive:next(not flag)
end

---@return nil
function M.toggle_gitignore()
  local flag = session.search_flag_gitignore:snapshot() ---@type boolean
  session.search_flag_gitignore:next(not flag)
end

---@return nil
function M.toggle_mode()
  local flag = session.search_flag_replace:snapshot() ---@type boolean
  session.search_flag_replace:next(not flag)
end

---@return nil
function M.toggle_regex()
  local flag = session.search_flag_regex:snapshot() ---@type boolean
  session.search_flag_regex:next(not flag)
end

---@return nil
function M.toggle_scope()
  local next_scope = session.get_search_scope_carousel_next() ---@type ghc.enums.context.SearchScope
  change_scope(next_scope)
end

return M
