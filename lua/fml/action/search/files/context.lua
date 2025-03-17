local __module_name__ = "fml.action.search.files" ---@type string

local Setting = require("fml.ux.setting")
local Search = require("fml.ux.search.search")
local SearchContext = require("fml.ux.search.context")

---@return eve.e.SearchFileScope
local function get_scope_carousel_next()
  local scopes = eve.state.select.search_file_scopes ---@type eve.e.SearchFileScope[]
  local scope = eve.state.select.search_file_scope:snapshot() ---@type eve.e.SearchFileScope
  local idx = eve.table.find_index(scopes, scope) or 1 ---@type integer
  local idx_next = idx == #scopes and 1 or idx + 1 ---@type integer
  return scopes[idx_next]
end

---@param scope                         eve.e.SearchFileScope
---@return nil
local function change_scope(scope)
  local scope_current = eve.state.select.search_file_scope:snapshot() ---@type eve.e.SearchFileScope
  if scope_current ~= scope then
    eve.state.select.search_file_scope:next(scope)
  end
end

---@param dirpath                       string
---@return string
local function get_scope_cwd(dirpath)
  local scope = eve.state.select.search_file_scope:snapshot() ---@type eve.e.SearchFileScope

  if scope == "W" then
    return eve.path.workspace()
  end

  if scope == "C" then
    return eve.path.cwd()
  end

  if scope == "D" then
    return dirpath
  end

  if scope == "B" then
    return dirpath
  end

  eve.reporter.error({
    from = __module_name__,
    subject = "get_scope_cwd",
    message = "Unknown scope.",
    details = { scope = scope, dirpath = dirpath },
  })
  return eve.path.cwd()
end

local state_cwd = eve.std.Observable.from_value(get_scope_cwd(eve.path.cwd()))

---@return string
local function gen_title()
  local flag_replace = eve.state.search_file.flag_replace:snapshot() ---@type boolean
  local mode = flag_replace and "Replace" or "Search" ---@type string

  local cwd = eve.path.cwd() ---@type string
  local scope = eve.state.select.search_file_scope:snapshot() ---@type eve.e.SearchFileScope
  if scope == "B" then
    local bufnr = eve.state.editor.get_bufnr_sourcefile() ---@type integer|nil
    if bufnr ~= nil then
      local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
      if eve.fs.is_file_or_dir(filepath) == "file" then
        local relative_filepath = eve.path.relative(cwd, filepath, false)
        return mode .. "in " .. relative_filepath ---@type string
      end
    end
  end

  local dirpath = state_cwd:snapshot() ---@type string
  if dirpath == cwd then
    return mode .. "in files (cwd)" ---@type string
  end

  local relative_dirpath = eve.path.relative(cwd, dirpath, false)
  if #relative_dirpath < 1 or relative_dirpath == "." then
    return mode .. "in files (cwd)" ---@type string
  end

  local workspace = eve.path.workspace() ---@type string
  if dirpath == workspace then
    return mode .. "in files (workspace)" ---@type string
  end

  dirpath = relative_dirpath:sub(1, 1) ~= "." and relative_dirpath or dirpath
  return mode .. "in files (" .. dirpath .. ")" ---@type string
end

eve.state.select.search_file_scope:subscribe(
  eve.std.Subscriber.new({
    on_next = function(scope, prev_scope)
      local bufnr = eve.state.editor.get_bufnr_sourcefile() ---@type integer|nil
      local current_buf_dirpath = bufnr ~= nil and eve.path.dirname(vim.api.nvim_buf_get_name(bufnr)) or eve.path.cwd() ---@type string
      local current_search_cwd = state_cwd:snapshot() ---@type string
      local next_search_cwd = get_scope_cwd(current_buf_dirpath) ---@type string
      if current_search_cwd ~= next_search_cwd then
        state_cwd:next(next_search_cwd)
      end
      if scope == "B" or prev_scope == "B" then
        state_cwd:next(next_search_cwd, { force = true })
      end
    end,
  }),
  true
)

local _search = nil ---@type fml.ux.search.ISearch|nil

---@class fml.action.search.files.context
local M = {}

M.search_cwd = state_cwd

---@return nil
function M.close()
  if _search ~= nil then
    _search:close()
  end
end

---@return nil
function M.refresh_title()
  if _search ~= nil then
    local title = gen_title() ---@type string
    _search:change_input_title(title)
  end
end

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
  ---@class fml.action.search.files.IConfigData
  ---@field public keyword              string
  ---@field public replacement          string
  ---@field public max_filesize         string
  ---@field public max_matches          integer
  ---@field public includes             string[]
  ---@field public excludes             string[]

  local s_keyword = eve.state.select.search_file.input:snapshot() ---@type string
  local s_replacement = eve.state.search_file.replacement:snapshot() ---@type string
  local s_max_filesize = eve.state.search_file.max_filesize:snapshot() ---@type string
  local s_max_matches = eve.state.search_file.max_matches:snapshot() ---@type integer
  local s_includes = eve.state.select.search_file.includes:snapshot() ---@type string[]
  local s_excludes = eve.state.select.search_file.excludes:snapshot() ---@type string[]

  ---@type fml.action.search.files.IConfigData
  local data = {
    keyword = s_keyword,
    replacement = s_replacement,
    max_filesize = s_max_filesize,
    max_matches = s_max_matches,
    includes = s_includes,
    excludes = s_excludes,
  }

  local setting = Setting.new({
    position = "center",
    width = 100,
    title = "Edit Configuration (search files)",
    validate = function(raw_data)
      if type(raw_data) ~= "table" then
        return "Invalid search_files configuration, expect an object."
      end
      ---@cast raw_data                 fml.action.search.files.IConfigData

      if raw_data.keyword == nil or type(raw_data.keyword) ~= "string" then
        return "Invalid data.keyword, expect an string."
      end

      if raw_data.replacement == nil or type(raw_data.replacement) ~= "string" then
        return "Invalid data.replacement, expect an string."
      end

      if type(raw_data.max_filesize) ~= "string" then
        return "Invalid data.max_filesize, expect a string."
      end

      if type(raw_data.max_matches) ~= "number" then
        return "Invalid data.max_matches, expect a number."
      end

      if raw_data.includes == nil or not vim.islist(raw_data.includes) then
        return "Invalid data.includes, expect an array."
      end

      if raw_data.excludes == nil or not vim.islist(raw_data.excludes) then
        return "Invalid data.excludes, expect an array."
      end
    end,
    on_confirm = function(raw_data)
      vim.schedule(function()
        local last_keyword = eve.state.select.search_file.input:snapshot() ---@type string

        local raw = vim.tbl_extend("force", data, raw_data)
        ---@cast raw                    fml.action.search.files.IConfigData

        local keyword = raw.keyword ---@type string
        local replacement = raw.replacement ---@type string
        local max_filesize = raw.max_filesize ---@type string
        local max_matches = raw.max_matches ---@type integer
        local includes = raw.includes ---@type string[]
        local excludes = raw.excludes ---@type string[]

        eve.state.select.search_file.input:next(keyword)
        eve.state.select.search_file.includes:next(includes)
        eve.state.select.search_file.excludes:next(excludes)
        eve.state.search_file.replacement:next(replacement)
        eve.state.search_file.max_filesize:next(max_filesize)
        eve.state.search_file.max_matches:next(max_matches)

        if keyword ~= last_keyword then
          M.reset_input(keyword)
        else
          M.reload()
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

---@return fml.ux.search.ISearch
function M.get_search()
  if _search == nil then
    local api = require("fml.action.search.files.api")
    local keybindings = require("fml.action.search.files.keybindings")

    local frecency = eve.state.frecency.files ---@type eve.std.collection.IFrecency
    local title = gen_title() ---@type string

    ---@type fml.ux.search.IContext
    local context = SearchContext.new({
      delay_fetch = 512,
      dimension = {
        height = 0.8,
        max_height = 1,
        max_width = 1,
        width = 0.4,
        width_preview = 0.45,
      },
      enable_multiline_input = true,
      fetch_data = api.fetch_data,
      flag_selected = eve.state.select.search_file.flag_selected,
      input = eve.state.select.search_file.input,
      input_history = eve.state.select.search_file.input_history,
      multiple = true,
      permanent = true,
      title = title,
    })

    _search = Search.new({
      context = context,
      fetch_preview_data = api.fetch_preview_data,
      input_keymaps = keybindings.input_keymaps,
      main_keymaps = keybindings.main_keymaps,
      patch_preview_data = api.patch_preview_data,
      preview_keymaps = keybindings.preview_keymaps,
      delay_render = 64,
      statusline_items = keybindings.statusline_items,
      on_invisible = function()
        local scope = eve.state.select.search_file_scope:snapshot() ---@type eve.e.SearchFileScope
        if scope == "B" then
          M.reload()
        end
      end,
      on_close = function()
        vim.cmd.checktime()
        local scope = eve.state.select.search_file_scope:snapshot() ---@type eve.e.SearchFileScope
        if scope == "B" then
          M.reload()
        end
      end,
      ---@diagnostic disable-next-line: unused-local
      on_confirm = function(widget, items)
        api.open_files(items, frecency)
      end,
    })
  end
  return _search
end

---@return nil
function M.hide()
  if _search ~= nil then
    _search:hide()
  end
end

---@param uuid                          string
---@return boolean
function M.has_item_deleted(uuid)
  return _search ~= nil and _search.context:has_item_deleted(uuid)
end

---@param uuid                          string
---@return nil
function M.mark_item_deleted(uuid)
  if _search ~= nil then
    _search.context:set_item_deleted(uuid)
  end
end

---@return nil
function M.mark_all_items_deleted()
  if _search ~= nil then
    _search.context:mark_all_items_deleted()
  end
end

---@return nil
function M.reload()
  if _search ~= nil then
    _search.context.dirtier_data:mark_dirty()
  end
end

---@return nil
function M.replace_file()
  local search = M.get_search() ---@type fml.ux.search.ISearch
  local item = search.context:get_current() ---@type fml.ux.search.IItem|nil
  if item ~= nil then
    local api = require("fml.action.search.files.api")
    api.replace_file(item.uuid)
    return
  end
end

---@return nil
function M.replace_file_all()
  local api = require("fml.action.search.files.api")
  api.replace_file_all()
end

---@param text                          string
---@return nil
function M.reset_input(text)
  if _search ~= nil then
    _search:reset_input(text)
  end
end

---@return nil
function M.send_to_qflist()
  local api = require("fml.action.search.files.api")
  local quickfix_items = api.gen_quickfix_items() ---@type eve.t.IQuickFixItem[]
  if #quickfix_items > 0 then
    M.close()

    eve.state.qflist.push(quickfix_items)
    eve.state.qflist.open_qflist(true)
  end
end

---@return nil
function M.toggle_flag_case_sensitive()
  local flag = eve.state.select.search_file.flag_case_sensitive:snapshot() ---@type boolean
  eve.state.select.search_file.flag_case_sensitive:next(not flag)
end

---@return nil
function M.toggle_flag_gitignore()
  local flag = eve.state.select.search_file.flag_gitignore:snapshot() ---@type boolean
  eve.state.select.search_file.flag_gitignore:next(not flag)
end

---@return nil
function M.toggle_mode()
  local flag = eve.state.search_file.flag_replace:snapshot() ---@type boolean
  eve.state.search_file.flag_replace:next(not flag)
end

---@return nil
function M.toggle_flag_regex()
  local flag = eve.state.select.search_file.flag_regex:snapshot() ---@type boolean
  eve.state.select.search_file.flag_regex:next(not flag)
end

---@return nil
function M.toggle_scope()
  local next_scope = get_scope_carousel_next() ---@type eve.e.SearchFileScope
  change_scope(next_scope)
end

---@return nil
function M.toggle_flag_selected()
  local flag = eve.state.select.search_file.flag_selected:snapshot() ---@type boolean
  eve.state.select.search_file.flag_selected:next(not flag)
end

---@return nil
function M.toggle_flag_exclude()
  local flag = eve.state.select.search_file.flag_exclude:snapshot() ---@type boolean
  eve.state.select.search_file.flag_exclude:next(not flag)
end

return M
