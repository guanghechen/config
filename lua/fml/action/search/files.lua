local name = "fml.action.search.files.searcher" ---@type string
local title = "Search Files" ---@type string
local o_rootpath = ark.c.Observable.from_value(dot.path.cwd())

local o_excludes = dot.context.select.search_file.excludes
local o_flag_exclude = dot.context.select.search_file.flag_exclude
local o_flag_foldempty = dot.context.select.search_file.flag_foldempty
local o_flag_fuzzy = dot.context.select.search_file.flag_fuzzy
local o_flag_gitignore = dot.context.select.search_file.flag_gitignore
local o_flag_regex = dot.context.select.search_file.flag_regex
local o_flag_replace = dot.context.search_file.flag_replace
local o_flag_case_sensitive = dot.context.select.search_file.flag_case_sensitive
local o_flag_selected = dot.context.select.search_file.flag_selected
local o_flag_viewtype = dot.context.select.search_file.flag_viewtype
local o_includes = dot.context.select.search_file.includes
local o_max_filesize = dot.context.search_file.max_filesize
local o_max_matches = dot.context.search_file.max_matches
local o_search_pattern = dot.context.select.search_file.search_pattern
local o_replace_pattern = dot.context.search_file.replacement

local o_search_pattern_history = dot.context.select.search_file.search_pattern_history
local o_replace_pattern_history = dot.context.search_file.replace_pattern_history

---@class fml.action.search.files.searcher.ISettingData
---@field public search_pattern         string
---@field public replace_pattern        string
---@field public max_filesize           string
---@field public max_matches            integer
---@field public includes               string[]
---@field public excludes               string[]

---@param searcher                      dot.ux.searcher.FiletreeComposer
---@return nil
local function edit_setting(searcher)
  local s_search_pattern = o_search_pattern:snapshot() ---@type string
  local s_replace_pattern = o_replace_pattern:snapshot() ---@type string
  local s_max_filesize = o_max_filesize:snapshot() ---@type string
  local s_max_matches = o_max_matches:snapshot() ---@type integer
  local s_includes = o_includes:snapshot() ---@type string[]
  local s_excludes = o_excludes:snapshot() ---@type string[]

  ---@type fml.action.search.files.searcher.ISettingData
  local data = {
    search_pattern = s_search_pattern,
    replace_pattern = s_replace_pattern,
    max_filesize = s_max_filesize,
    max_matches = s_max_matches,
    includes = s_includes,
    excludes = s_excludes,
  }

  dot.ux.Setting
    .new({
      position = "center",
      width = 100,
      title = string.format("Edit Configuration (%s)", title),
      validate = function(raw_data)
        if type(raw_data) ~= "table" then
          return "Invalid search_files configuration, expect an object."
        end
        ---@cast raw_data               fml.action.search.files.searcher.ISettingData

        if type(raw_data.search_pattern) ~= "string" then
          return "Invalid data.keyword, expect an string."
        end

        if type(raw_data.replace_pattern) ~= "string" then
          return "Invalid data.replace_pattern, expect an string."
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
          local last_keyword = o_search_pattern:snapshot() ---@type string
          local raw = vim.tbl_extend("force", data, raw_data)
          ---@cast raw                  fml.action.search.files.searcher.ISettingData

          local search_pattern = raw.search_pattern ---@type string
          local replace_pattern = raw.replace_pattern ---@type string
          local max_filesize = raw.max_filesize ---@type string
          local max_matches = raw.max_matches ---@type integer
          local includes = raw.includes ---@type string[]
          local excludes = raw.excludes ---@type string[]

          o_replace_pattern:next(replace_pattern)
          o_max_filesize:next(max_filesize)
          o_max_matches:next(max_matches)
          o_includes:next(includes)
          o_excludes:next(excludes)

          if search_pattern ~= last_keyword then
            searcher.finder:set_content(search_pattern)
          end

          searcher:schedule_search()
        end)
        return true
      end,
    })
    :open({
      initial_value = data,
      text_cursor_row = 1,
      text_cursor_col = 1,
    })
end

---@param searcher                      dot.ux.searcher.FiletreeComposer
---@param rootpath                      string
---@return nil
local function attach(searcher, rootpath)
  o_rootpath:next(rootpath)
  local rootuuid = dot.tree.Filetree.uuid(rootpath) ---@type string
  if searcher:isexistent(rootuuid) then
    searcher:attach(rootuuid)
  else
    searcher:schedule_search()
  end
end

local searcher ---@type dot.ux.searcher.FiletreeComposer
searcher = dot.ux.searcher.FiletreeComposer.new({
  name = name,
  frecency = dot.context.frecency.files,
  permanent = true,
  title = title,
  height = 0.90,
  width = 0.90,

  keymaps_common = {
    {
      modes = { "n", "x" },
      key = "tc",
      desc = string.format("%s: change root (cwd)", title),
      callback = function()
        local cwd = dot.path.cwd() ---@type string
        attach(searcher, cwd)
      end,
    },
    {
      modes = { "n", "x" },
      key = "tw",
      desc = string.format("%s: change root (workspace)", title),
      callback = function()
        local workspace = dot.path.workspace() ---@type string
        attach(searcher, workspace)
      end,
    },
  },

  search_pattern_history = o_search_pattern_history,
  replace_pattern_history = o_replace_pattern_history,

  excludes = o_excludes,
  flag_exclude = o_flag_exclude,
  flag_foldempty = o_flag_foldempty,
  flag_gitignore = o_flag_gitignore,
  flag_fuzzy = o_flag_fuzzy,
  flag_regex = o_flag_regex,
  flag_replace = o_flag_replace,
  flag_case_sensitive = o_flag_case_sensitive,
  flag_selected = o_flag_selected,
  flag_viewtype = o_flag_viewtype,
  includes = o_includes,
  max_filesize = o_max_filesize,
  max_matches = o_max_matches,
  replace_pattern = o_replace_pattern,
  rootpath = o_rootpath,
  search_pattern = o_search_pattern,

  flags_start_index = 0,
  flags_prepend = {
    {
      desc = string.format("%s: open settings", title),
      callback = function()
        edit_setting(searcher)
      end,
      snapshot = function()
        return dot.icon.symbols.setting, "picker_flag_purple"
      end,
    },
  },
  flags_append = {
    {
      desc = string.format("%s: toggle exclude", name),
      callback = function()
        local enabled = o_flag_exclude:snapshot() ---@type boolean
        o_flag_exclude:next(not enabled)
      end,
      snapshot = function()
        local enabled = o_flag_exclude:snapshot() ---@type boolean
        return dot.icon.symbols.flag_exclude, enabled and "picker_flag_blue" or "picker_flag_grey"
      end,
    },
    {
      desc = string.format("%s: toggle gitignore", name),
      callback = function()
        local enabled = o_flag_gitignore:snapshot() ---@type boolean
        o_flag_gitignore:next(not enabled)
      end,
      snapshot = function()
        local enabled = o_flag_gitignore:snapshot() ---@type boolean
        return dot.icon.symbols.flag_gitignore, enabled and "picker_flag_blue" or "picker_flag_grey"
      end,
    },
  },

  on_attached = function(_, rootpath)
    o_rootpath:next(rootpath)
  end,

  on_refresh = function()
    searcher:schedule_search()
  end,
})

ark.fn.observe({ o_rootpath }, function()
  local rootpath = o_rootpath:snapshot() ---@type string
  local workspace = dot.path.workspace() ---@type string
  local cwd = dot.path.cwd() ---@type string
  if rootpath == workspace then
    searcher.finder:set_title(string.format("%s (workspace)", title))
  elseif rootpath == cwd then
    searcher.finder:set_title(string.format("%s (cwd)", title))
  else
    local relative_path = yoz.path.is_descendant(workspace, rootpath) and dot.path.relative(cwd, rootpath) or rootpath ---@type string
    searcher.finder:set_title(string.format("%s (%s)", title, relative_path))
  end
end)

ark.fn.observe({ o_flag_exclude, o_flag_gitignore }, function()
  searcher:mark_result_flags_dirty()
  searcher:schedule_search()
end, true)

ark.fn.observe({ o_includes, o_excludes }, function()
  searcher:mark_result_dirty()
end)

---@return nil
local function focus()
  local selected_text = dot.buf.retrieve_selected_text() ---@type string
  searcher:focus()

  vim.schedule(function()
    if selected_text and #selected_text > 1 then
      local next_search_pattern = selected_text ---@type string
      o_flag_regex:next(false)
      searcher.finder:set_content(next_search_pattern)
    end
  end)
end

---@class fml.action.search.files.searcher
local M = {}

---@return nil
function M.reset_input()
  searcher.finder:set_content("")
end

---@param rootpath                      string|nil
---@return nil
function M.search_in_files(rootpath)
  rootpath = (rootpath ~= nil and rootpath ~= "") and rootpath or o_rootpath:snapshot() ---@type string
  attach(searcher, rootpath)
  focus()
end

---@return nil
function M.search_in_cwd()
  local cwd = dot.path.cwd() ---@type string
  if searcher:isfocused() then
    searcher:hide()
    return
  end

  attach(searcher, cwd)
  focus()
end

---@return nil
function M.search_in_directory()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local winnr_source = dot.tab.retrieve_winnr_sourcefile(tabnr) ---@type integer|nil
  if winnr_source ~= nil then
    local bufnr = vim.api.nvim_win_get_buf(winnr_source) ---@type integer
    local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
    local dirpath = yoz.path.is_exist_directory(filepath) and filepath or dot.path.dirname(filepath) ---@type string
    attach(searcher, dirpath)
  end
  focus()
end

---@return nil
function M.search_in_workspace()
  local workspace = dot.path.workspace() ---@type string
  attach(searcher, workspace)
  focus()
end

---@param filepath                      string|nil
---@return nil
function M.search_in_file(filepath)
  if not filepath or not yoz.path.is_exist_file(filepath) then
    local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
    local winnr_source = dot.tab.retrieve_winnr_sourcefile(tabnr) ---@type integer|nil
    if winnr_source ~= nil then
      local bufnr = vim.api.nvim_win_get_buf(winnr_source) ---@type integer
      filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
      if yoz.path.is_exist_file(filepath) then
        attach(searcher, filepath)
      end
    end
  end
  focus()
end

return M
