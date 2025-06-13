local name = "fml.action.find" ---@type string
local last_scope_path = nil ---@type string|nil
local o_scope_path = std.Observable.from_value(std.path.cwd())

local o_flag_exclude = eve.context.select.find_file.flag_exclude
local o_flag_foldempty = eve.context.select.find_file.flag_foldempty
local o_flag_fuzzy = eve.context.select.find_file.flag_fuzzy
local o_flag_gitignore = eve.context.select.find_file.flag_gitignore
local o_flag_regex = eve.context.select.find_file.flag_regex
local o_flag_sensitive = eve.context.select.find_file.flag_case_sensitive
local o_flag_selected = eve.context.select.find_file.flag_selected
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
      title = "Edit Configuration (find files)",
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
---@return nil
local function refresh(picker)
  local workspace = std.path.workspace() ---@type string
  local p = o_scope_path:snapshot() ---@type string

  local enabled_exclude = o_flag_exclude:snapshot() ---@type boolean
  local enabled_gitignore = o_flag_gitignore:snapshot() ---@type boolean
  local excludes = enabled_exclude and eve.context.select.find_file.excludes:snapshot() or {} ---@type string[]

  ---@type string[]
  local filepaths = eve.oxi.find({
    workspace = workspace,
    cwd = p,
    flag_case_sensitive = false,
    flag_gitignore = enabled_gitignore,
    flag_regex = false,
    search_pattern = "",
    search_paths = "",
    exclude_patterns = table.concat(excludes, ","),
  })

  last_scope_path = p ---@type string
  picker:reset_filepaths(p, filepaths, false)
  picker:mark_result_dirty()
  picker:focus()
end

local picker ---@type eve.ux.picker.FiletreeComposer

---@return nil
local function attach_cwd()
  local filepath = std.path.cwd() ---@type string
  local rootuuid = std.Filetree.uuid(filepath) ---@type string
  picker:attach(rootuuid)
end

---@return nil
local function attach_workspace()
  local filepath = std.path.workspace() ---@type string
  local rootuuid = std.Filetree.uuid(filepath) ---@type string
  picker:attach(rootuuid)
end

picker = eve.ux.picker.FiletreeComposer.new({
  name = name,
  frecency = eve.context.frecency.files,
  permanent = true,
  title = "Find files",
  height = 0.80,
  width = 0.85,

  keymaps_common = {
    {
      modes = { "n", "v" },
      key = "<leader>C",
      desc = "find-files: change scope (cwd)",
      callback = attach_cwd,
    },
    {
      modes = { "n", "v" },
      key = "<leader>W",
      desc = "find-files: change scope (workspace)",
      callback = attach_workspace,
    },
  },

  finder_input = o_input,
  finder_input_history = o_input_history,
  finder_multiline = false,

  flag_foldempty = o_flag_foldempty,
  flag_fuzzy = o_flag_fuzzy,
  flag_regex = o_flag_regex,
  flag_sensitive = o_flag_sensitive,
  flag_selected = o_flag_selected,
  flag_viewtype = o_flag_viewtype,
  flags_start_index = 0,
  flags_prepend = {
    {
      desc = "find-files: open settings",
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
  },

  on_attach = function(_, rootpath)
    o_scope_path:next(rootpath)
  end,

  on_refresh = function(self)
    refresh(self)
  end,
})

std.fn.observe({ o_scope_path }, function()
  local p = o_scope_path:snapshot() ---@type string
  local workspace = std.path.workspace() ---@type string
  local cwd = std.path.cwd() ---@type string
  if p == workspace then
    picker.finder:set_title("find files (workspace)")
  elseif p == cwd then
    picker.finder:set_title("find files (cwd)")
  else
    local relative_path = std.path.is_under(workspace, p) and std.path.relative(cwd, p, false) or p ---@type string
    picker.finder:set_title(string.format("find files (%s)", relative_path))
  end

  if last_scope_path == nil or not std.path.is_under(last_scope_path, p) then
    refresh(picker)
  end
end)

std.fn.observe({ o_flag_exclude, o_flag_gitignore }, function()
  refresh(picker)
end, true)

std.fn.observe({ o_includes, o_excludes }, function()
  picker:mark_result_dirty()
end)

---@class fml.action.find
local M = {}

---@return nil
function M.find_files()
  picker:focus()
end

---@return nil
function M.find_files_cwd()
  attach_cwd()
  picker:focus()
end

---@param specified_filepath            string|nil
---@return nil
function M.find_files_directory(specified_filepath)
  if specified_filepath ~= nil and #specified_filepath > 0 then
    local rootuuid = std.Filetree.uuid(specified_filepath) ---@type string
    picker:attach(rootuuid)
  end
  picker:focus()
end

---@return nil
function M.find_files_workspace()
  attach_workspace()
  picker:focus()
end

return M
