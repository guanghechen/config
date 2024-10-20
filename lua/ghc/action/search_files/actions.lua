local api = require("ghc.action.search_files.api")
local state = require("ghc.action.search_files.state")

---@param scope                         t.eve.e.SearchScope
---@return nil
local function change_scope(scope)
  local scope_current = eve.context.state.search.scope:snapshot() ---@type t.eve.e.SearchScope
  if scope_current ~= scope then
    eve.context.state.search.scope:next(scope)
  end
end

---@class ghc.action.search_files.actions
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
  ---@class ghc.action.search_files.IConfigData
  ---@field public keyword              string
  ---@field public replacement          string
  ---@field public search_paths         string[]
  ---@field public max_filesize         string
  ---@field public max_matches          integer
  ---@field public includes             string[]
  ---@field public excludes             string[]

  local s_keyword = eve.context.state.search.keyword:snapshot() ---@type string
  local s_replacement = eve.context.state.search.replacement:snapshot() ---@type string
  local s_search_paths = eve.context.state.search.search_paths:snapshot() ---@type string[]
  local s_max_filesize = eve.context.state.search.max_filesize:snapshot() ---@type string
  local s_max_matches = eve.context.state.search.max_matches:snapshot() ---@type integer
  local s_includes = eve.context.state.search.includes:snapshot() ---@type string[]
  local s_excludes = eve.context.state.search.excludes:snapshot() ---@type string[]

  ---@type ghc.action.search_files.IConfigData
  local data = {
    keyword = s_keyword,
    replacement = s_replacement,
    search_paths = s_search_paths,
    max_filesize = s_max_filesize,
    max_matches = s_max_matches,
    includes = s_includes,
    excludes = s_excludes,
  }

  local setting = fml.ux.Setting.new({
    position = "center",
    width = 100,
    title = "Edit Configuration (search files)",
    validate = function(raw_data)
      if type(raw_data) ~= "table" then
        return "Invalid search_files configuration, expect an object."
      end
      ---@cast raw_data ghc.action.search_files.IConfigData

      if raw_data.keyword == nil or type(raw_data.keyword) ~= "string" then
        return "Invalid data.search_pattern, expect an string."
      end

      if raw_data.replacement == nil or type(raw_data.replacement) ~= "string" then
        return "Invalid data.replace_pattern, expect an string."
      end

      if raw_data.search_paths == nil or not vim.islist(raw_data.search_paths) then
        return "Invalid data.search_paths, expect an array."
      end

      if type(raw_data.max_filesize) ~= "string" then
        return "Invalid data.max_filesize, expect a string."
      end

      if type(raw_data.max_matches) ~= "number" then
        return "Invalid data.max_matches, expect a number."
      end

      if raw_data.includes == nil or not vim.islist(raw_data.includes) then
        return "Invalid data.include_patterns, expect an array."
      end

      if raw_data.excludes == nil or not vim.islist(raw_data.excludes) then
        return "Invalid data.exclude_patterns, expect an array."
      end
    end,
    on_confirm = function(raw_data)
      vim.schedule(function()
        local last_search_pattern = eve.context.state.search.keyword:snapshot() ---@type string

        local raw = vim.tbl_extend("force", data, raw_data)
        ---@cast raw ghc.action.search_files.IConfigData

        local keyword = raw.keyword ---@type string
        local replacement = raw.replacement ---@type string
        local max_filesize = raw.max_filesize ---@type string
        local max_matches = raw.max_matches ---@type integer
        local search_paths = raw.search_paths ---@type string[]
        local includes = raw.includes ---@type string[]
        local excludes = raw.excludes ---@type string[]

        eve.context.state.search.keyword:next(keyword)
        eve.context.state.search.replacement:next(replacement)
        eve.context.state.search.max_filesize:next(max_filesize)
        eve.context.state.search.max_matches:next(max_matches)
        eve.context.state.search.search_paths:next(search_paths)
        eve.context.state.search.includes:next(includes)
        eve.context.state.search.excludes:next(excludes)

        if keyword ~= last_search_pattern then
          state.reset_input(keyword)
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
  local search = state.get_search() ---@type t.fml.ux.search.ISearch
  local item = search.state:get_current() ---@type t.fml.ux.search.IItem|nil
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
  local quickfix_items = api.gen_quickfix_items() ---@type t.eve.IQuickFixItem[]
  if #quickfix_items > 0 then
    state.close()

    eve.qflist.push(quickfix_items)
    eve.qflist.open_qflist(true)
  end
end

---@return nil
function M.toggle_case_sensitive()
  local flag = eve.context.state.search.flag_case_sensitive:snapshot() ---@type boolean
  eve.context.state.search.flag_case_sensitive:next(not flag)
end

---@return nil
function M.toggle_gitignore()
  local flag = eve.context.state.search.flag_gitignore:snapshot() ---@type boolean
  eve.context.state.search.flag_gitignore:next(not flag)
end

---@return nil
function M.toggle_mode()
  local flag = eve.context.state.search.flag_replace:snapshot() ---@type boolean
  eve.context.state.search.flag_replace:next(not flag)
end

---@return nil
function M.toggle_regex()
  local flag = eve.context.state.search.flag_regex:snapshot() ---@type boolean
  eve.context.state.search.flag_regex:next(not flag)
end

---@return nil
function M.toggle_scope()
  local next_scope = fml.api.search.get_scope_carousel_next() ---@type t.eve.e.SearchScope
  change_scope(next_scope)
end

return M
