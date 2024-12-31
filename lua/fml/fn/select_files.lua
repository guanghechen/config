local checks = require("eve.lib.checks")
local path = require("eve.lib.path")
local Observable = require("eve.lib.collection.observable")
local state = require("eve.state")
local FileSelect = require("fml.ux.file_select")
local Select = require("fml.ux.select")

---@class fml.fn.select_files.IParams
---@field public cwd                    string
---@field public dimension              ?fml.ux.search.IRawDimension
---@field public flag_fuzzy             ?boolean
---@field public flag_regex             ?boolean
---@field public input                  ?eve.lib.collection.IObservable
---@field public title                  string
---@field public fetch_filepaths        fun(): string[]
---@field public get_present            ?fun(): string|nil

---@param params                        fml.fn.select_files.IParams
---@return nil
local function select_files(params)
  local cwd = params.cwd ---@type string
  local dimension = params.dimension ---@type fml.ux.search.IRawDimension|nil
  local flag_fuzzy = not not params.flag_fuzzy ---@type boolean
  local flag_regex = not not params.flag_regex ---@type boolean
  local input = params.input ---@type eve.lib.collection.IObservable | nil
  local title = params.title ---@type string
  local fetch_filepaths = params.fetch_filepaths ---@type fun(): string[]
  local get_present = params.get_present ---@type (fun(): string|nil) | nil

  if get_present == nil then
    ---@return string|nil
    get_present = function()
      local present_filepath = nil ---@type string|nil
      local winnr = state.tab.get_current_winnr() ---@type integer
      if winnr > 0 and vim.api.nvim_win_is_valid(winnr) then
        local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
        if checks.is_buf_valid(bufnr) then
          local absolute_filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
          present_filepath = path.relative(cwd, absolute_filepath, true) ---@type string
        end
      end
      return present_filepath
    end
  end

  local file_select = nil ---@type fml.ux.IFileSelect|nil
  local last_data = nil ---@type fml.ux.file_select.IData|nil

  ---@type fml.ux.file_select.IProvider
  local provider = {
    fetch_data = function(force)
      if force or last_data == nil then
        local filepaths = fetch_filepaths() ---@type string[]
        table.sort(filepaths)

        local items = FileSelect.make_items_by_filepaths(cwd, filepaths) ---@type fml.ux.file_select.IRawItem[]
        last_data = { cwd = cwd, items = items } ---@type fml.ux.file_select.IData

        if file_select ~= nil then
          local width = 0 ---@type integer
          for _, filepath in ipairs(filepaths) do
            local w = vim.api.nvim_strwidth(filepath) ---@type integer
            width = width < w and w or width
          end
          width = math.max(width + 16, 60)
          file_select:change_dimension({ height = #filepaths + 3, width = width + 16 })
        end
      end

      local present = get_present ~= nil and get_present() or nil ---@type string|nil

      ---@type fml.ux.file_select.IData
      local data = { items = last_data.items, present_uuid = present }
      return data
    end,
  }

  file_select = FileSelect.new({
    cmp = Select.cmp_by_score,
    dimension = dimension,
    dirty_on_invisible = true,
    preview_enabled = false,
    extend_preset_keymaps = true,
    flag_fuzzy = Observable.from_value(flag_fuzzy),
    flag_regex = Observable.from_value(flag_regex),
    frecency = state.frecency.files,
    input = input,
    permanent = false,
    provider = provider,
    title = title,
  }):focus()
end

return select_files
