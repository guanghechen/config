local name = "fml.action.find.files" ---@type string
local title = "Find Files" ---@type string
local o_rootpath = std.Observable.from_value(std.path.cwd())

local o_flag_exclude = eve.context.select.find_file.flag_exclude
local o_flag_foldempty = eve.context.select.find_file.flag_foldempty
local o_flag_fuzzy = eve.context.select.find_file.flag_fuzzy
local o_flag_gitignore = eve.context.select.find_file.flag_gitignore
local o_flag_regex = eve.context.select.find_file.flag_regex
local o_flag_sensitive = eve.context.select.find_file.flag_case_sensitive
local o_flag_selected = eve.context.select.find_file.flag_selected
local o_flag_textonly = eve.context.select.find_file.flag_textonly
local o_flag_viewtype = eve.context.select.find_file.flag_viewtype

local o_input = eve.context.select.find_file.input
local o_input_history = eve.context.select.find_file.input_history
local o_excludes = eve.context.select.find_file.excludes
local o_includes = eve.context.select.find_file.includes

---@class fml.action.find.files.ISettingData
---@field public keyword        string
---@field public includes       string[]
---@field public excludes       string[]

---@param picker                        eve.ux.picker.FiletreeComposer
---@return nil
local function edit_setting(picker)
  local s_keyword = o_input:snapshot() ---@type string
  local s_includes = o_includes:snapshot() ---@type string[]
  local s_excludes = o_excludes:snapshot() ---@type string[]

  ---@type fml.action.find.files.ISettingData
  local data = {
    keyword = s_keyword,
    includes = s_includes,
    excludes = s_excludes,
  }

  eve.ux.Setting
    .new({
      position = "center",
      width = 100,
      title = string.format("Edit Configuration (%s)", title),
      validate = function(raw_data)
        if type(raw_data) ~= "table" then
          return "Invalid find_files configuration, expect an object."
        end
        ---@cast raw_data               fml.action.find.files.ISettingData

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
          local last_keyword = o_input:snapshot() ---@type string
          local raw = vim.tbl_extend("force", data, raw_data)
          ---@cast raw                  fml.action.find.files.ISettingData

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

---@param picker                        eve.ux.picker.FiletreeComposer
---@param rootpath                      string
---@return nil
local function refresh(picker, rootpath)
  local rootuuid = std.Filetree.uuid(rootpath) ---@type string
  local workspace = std.path.workspace() ---@type string
  local enabled_exclude = o_flag_exclude:snapshot() ---@type boolean
  local enabled_gitignore = o_flag_gitignore:snapshot() ---@type boolean
  local excludes = enabled_exclude and eve.context.select.find_file.excludes:snapshot() or {} ---@type string[]

  ---@type string[]
  local filepaths = eve.oxi.find({
    workspace = workspace,
    cwd = rootpath,
    flag_case_sensitive = false,
    flag_gitignore = enabled_gitignore,
    flag_regex = false,
    search_pattern = "",
    search_paths = "",
    exclude_patterns = table.concat(excludes, ","),
  })

  picker:reset_filepaths(rootpath, filepaths, false)
  picker:attach(rootuuid)
  picker:mark_result_dirty()
end

---@param picker                        eve.ux.picker.FiletreeComposer
---@param rootpath                      string
---@return nil
local function attach(picker, rootpath)
  local rootuuid = std.Filetree.uuid(rootpath) ---@type string
  if picker:isexistent(rootuuid) then
    picker:attach(rootuuid)
  else
    refresh(picker, rootpath)
  end
end

local picker ---@type eve.ux.picker.FiletreeComposer
picker = eve.ux.picker.FiletreeComposer.new({
  name = name,
  frecency = eve.context.frecency.files,
  permanent = true,
  title = title,
  height = 0.90,
  width = 0.90,

  keymaps_common = {
    {
      modes = { "n", "v" },
      key = "<leader>c",
      desc = string.format("%s: change root (cwd)", title),
      callback = function()
        local cwd = std.path.cwd() ---@type string
        attach(picker, cwd)
      end,
    },
    {
      modes = { "n", "v" },
      key = "<leader>w",
      desc = string.format("%s: change root (workspace)", title),
      callback = function()
        local workspace = std.path.workspace() ---@type string
        attach(picker, workspace)
      end,
    },
  },

  finder_input = o_input,
  finder_input_history = o_input_history,

  flag_foldempty = o_flag_foldempty,
  flag_fuzzy = o_flag_fuzzy,
  flag_regex = o_flag_regex,
  flag_sensitive = o_flag_sensitive,
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
        return eve.icon.symbols.setting, "picker_flag_purple"
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
        return eve.icon.symbols.flag_exclude, enabled and "picker_flag_blue" or "picker_flag_grey"
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
        return eve.icon.symbols.flag_gitignore, enabled and "picker_flag_blue" or "picker_flag_grey"
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
        return eve.icon.symbols.flag_textonly, enabled and "picker_flag_blue" or "picker_flag_grey"
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

std.fn.observe({ o_rootpath }, function()
  local rootpath = o_rootpath:snapshot() ---@type string
  local workspace = std.path.workspace() ---@type string
  local cwd = std.path.cwd() ---@type string
  if rootpath == workspace then
    picker.finder:set_title(string.format("%s (workspace)", title))
  elseif rootpath == cwd then
    picker.finder:set_title(string.format("%s (cwd)", title))
  else
    local relative_path = std.path.is_under(workspace, rootpath) and std.path.relative(cwd, rootpath, false) or rootpath ---@type string
    picker.finder:set_title(string.format("%s (%s)", title, relative_path))
  end
end)

std.fn.observe({ o_flag_exclude, o_flag_gitignore }, function()
  local rootpath = o_rootpath:snapshot() ---@type string
  picker:mark_result_flags_dirty()
  refresh(picker, rootpath)
end, true)

std.fn.observe({ o_includes, o_excludes }, function()
  picker:mark_result_dirty()
end)

---@class fml.action.find
local M = {}

---@return nil
function M.reset_input()
  picker.finder:set_content("")
end

---@param rootpath                      string|nil
---@return nil
function M.find_files(rootpath)
  rootpath = (rootpath ~= nil and rootpath ~= "") and rootpath or o_rootpath:snapshot() ---@type string
  attach(picker, rootpath)
  picker:focus()
end

---@return nil
function M.find_files_in_cwd()
  local cwd = std.path.cwd() ---@type string
  attach(picker, cwd)
  picker:focus()
end

---@return nil
function M.find_files_in_directory()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local winnr_source = eve.tab.retrieve_winnr_sourcefile(tabnr) ---@type integer|nil
  if winnr_source ~= nil then
    local bufnr = vim.api.nvim_win_get_buf(winnr_source) ---@type integer
    local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
    local dirpath = std.path.is_exist_dirpath(filepath) and filepath or std.path.dirname(filepath) ---@type string
    attach(picker, dirpath)
  end
  picker:focus()
end

---@return nil
function M.find_files_in_workspace()
  local workspace = std.path.workspace() ---@type string
  attach(picker, workspace)
  picker:focus()
end

return M
