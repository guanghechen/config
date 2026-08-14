---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.fn.find_files" ---@type string

local name = "era.fn.find_files" ---@type string
local title = "Find Files" ---@type string
local o_rootpath = stl.c.Observable.from_value(dot.path.cwd())

local o_flag_exclude = dot.context.select.find_file.flag_exclude
local o_flag_foldempty = dot.context.select.find_file.flag_foldempty
local o_flag_fuzzy = dot.context.select.find_file.flag_fuzzy
local o_flag_gitignore = dot.context.select.find_file.flag_gitignore
local o_flag_regex = dot.context.select.find_file.flag_regex
local o_flag_case_sensitive = dot.context.select.find_file.flag_case_sensitive
local o_flag_selected = dot.context.select.find_file.flag_selected
local o_flag_textonly = dot.context.select.find_file.flag_textonly
local o_flag_viewtype = dot.context.select.find_file.flag_viewtype

local o_search_pattern = dot.context.select.find_file.search_pattern
local o_search_pattern_history = dot.context.select.find_file.search_pattern_history
local o_excludes = dot.context.select.find_file.excludes
local o_includes = dot.context.select.find_file.includes

---@class era.fn.find_files.ISettingData
---@field public keyword                string
---@field public includes               string[]
---@field public excludes               string[]

---@param picker                        era.m.picker.FiletreeComposer
---@return nil
local function edit_setting(picker)
  local s_keyword = o_search_pattern:snapshot() ---@type string
  local s_includes = o_includes:snapshot() ---@type string[]
  local s_excludes = o_excludes:snapshot() ---@type string[]

  ---@type era.fn.find_files.ISettingData
  local data = {
    keyword = s_keyword,
    includes = s_includes,
    excludes = s_excludes,
  }

  era.view.Setting
    .new({
      position = "center",
      width = 100,
      title = string.format("Edit Configuration (%s)", title),
      validate = function(raw_data)
        if type(raw_data) ~= "table" then
          return "Invalid find_files configuration, expect an object."
        end
        ---@cast raw_data               era.fn.find_files.ISettingData

        if raw_data.keyword == nil or type(raw_data.keyword) ~= "string" then
          return "Invalid data.keyword, expect an string."
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
          ---@cast raw                  era.fn.find_files.ISettingData

          local keyword = raw.keyword ---@type string
          local includes = raw.includes ---@type string[]
          local excludes = raw.excludes ---@type string[]

          o_includes:next(includes)
          o_excludes:next(excludes)
          if keyword ~= last_keyword then
            picker.finder:set_content(keyword)
          end
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

---@param picker                        era.m.picker.FiletreeComposer
---@param rootpath                      string
---@return nil
local function refresh(picker, rootpath)
  local rootuuid = stl.c.Filetree.uuid(rootpath) ---@type string
  local enabled_exclude = o_flag_exclude:snapshot() ---@type boolean
  local enabled_gitignore = o_flag_gitignore:snapshot() ---@type boolean
  local excludes = enabled_exclude and dot.context.select.find_file.excludes:snapshot() or {} ---@type string[]

  ---@type yoz.find.IFindFilesOptions
  local find_files_options = {
    cwd = yoz.canonical_path.to_os_path(rootpath),
    flag_case_sensitive = false,
    flag_gitignore = enabled_gitignore,
    flag_regex = false,
    search_pattern = "",
    search_paths = "",
    exclude_patterns = table.concat(excludes, ","),
  }

  local filepaths = {}
  local result, err = yoz.find.find_files(find_files_options)
  if err ~= nil then
    stl.reporter.warn({
      from = name,
      subject = "find_files",
      message = err.error,
    })
  elseif result ~= nil then
    filepaths = result.filepaths or {}
  end

  picker:reset_filepaths(rootpath, filepaths, false)
  picker:attach(rootuuid)
  picker:mark_result_dirty()
end

---@param picker                        era.m.picker.FiletreeComposer
---@param rootpath                      string
---@return nil
local function attach(picker, rootpath)
  local rootuuid = stl.c.Filetree.uuid(rootpath) ---@type string
  if picker:isexistent(rootuuid) then
    picker:attach(rootuuid)
  else
    refresh(picker, rootpath)
  end
end

local picker ---@type era.m.picker.FiletreeComposer
picker = era.m.picker.FiletreeComposer.new({
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
        attach(picker, cwd)
      end,
    },
    {
      modes = { "n", "x" },
      key = "tw",
      desc = string.format("%s: change root (workspace)", title),
      callback = function()
        local workspace = dot.path.workspace() ---@type string
        attach(picker, workspace)
      end,
    },
  },

  search_pattern = o_search_pattern,
  search_pattern_history = o_search_pattern_history,

  flag_foldempty = o_flag_foldempty,
  flag_fuzzy = o_flag_fuzzy,
  flag_regex = o_flag_regex,
  flag_case_sensitive = o_flag_case_sensitive,
  flag_selected = o_flag_selected,
  flag_viewtype = o_flag_viewtype,
  flags_start_index = 0,
  flags_prepend = {
    {
      desc = string.format("%s: open settings", title),
      callback = function()
        edit_setting(picker)
      end,
      snapshot = function()
        return stl.icon.symbols.setting, "picker_flag_purple"
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
        return stl.icon.symbols.flag_exclude, enabled and "picker_flag_blue" or "picker_flag_grey"
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
        return stl.icon.symbols.flag_gitignore, enabled and "picker_flag_blue" or "picker_flag_grey"
      end,
    },
    {
      desc = string.format("%s: toggle textonly", name),
      callback = function()
        local enabled = o_flag_textonly:snapshot() ---@type boolean
        o_flag_textonly:next(not enabled)
      end,
      snapshot = function()
        local enabled = o_flag_textonly:snapshot() ---@type boolean
        return stl.icon.symbols.flag_textonly, enabled and "picker_flag_blue" or "picker_flag_grey"
      end,
    },
  },

  on_attached = function(_, rootpath)
    o_rootpath:next(rootpath)
  end,

  on_refresh = function(self)
    local rootpath = o_rootpath:snapshot() ---@type string
    refresh(self, rootpath)
  end,
})

stl.fn.observe({ o_rootpath }, function()
  local rootpath = yoz.canonical_path.from_os_path(o_rootpath:snapshot(), false) ---@type string
  local workspace = yoz.canonical_path.from_os_path(dot.path.workspace(), false) ---@type string
  local cwd = yoz.canonical_path.get_cwd_without_trailing() ---@type string
  if rootpath == workspace then
    picker.finder:set_title(string.format("%s (workspace)", title))
  elseif rootpath == cwd then
    picker.finder:set_title(string.format("%s (cwd)", title))
  else
    local relative_path = yoz.canonical_path.is_descendant(workspace, rootpath)
        and yoz.canonical_path.relative(cwd, rootpath, false)
      or rootpath ---@type string
    picker.finder:set_title(string.format("%s (%s)", title, relative_path))
  end
end)

stl.fn.observe({ o_flag_exclude, o_flag_gitignore, o_includes, o_excludes }, function()
  local rootpath = o_rootpath:snapshot() ---@type string
  picker:mark_result_flags_dirty()
  refresh(picker, rootpath)
end, true)

---@param rootpath                      string|"cwd"|"directory"|"workspace"|nil
---@param reset_input                   boolean|nil
---@return nil
local function find_files(rootpath, reset_input)
  if reset_input then
    picker.finder:set_content("")
  end

  if rootpath == "cwd" then
    rootpath = dot.path.cwd()
  elseif rootpath == "directory" then
    local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
    local winnr_source = dot.tab.retrieve_winnr_sourcefile(tabnr) ---@type integer|nil
    if winnr_source ~= nil then
      local bufnr = vim.api.nvim_win_get_buf(winnr_source) ---@type integer
      local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
      rootpath = yoz.path.is_exist_directory(filepath) and filepath or dot.path.dirname(filepath)
    else
      rootpath = nil
    end
  elseif rootpath == "workspace" then
    rootpath = dot.path.workspace()
  end

  rootpath = (rootpath ~= nil and rootpath ~= "") and rootpath or o_rootpath:snapshot() ---@type string
  attach(picker, rootpath)
  picker:focus()
end

return find_files
