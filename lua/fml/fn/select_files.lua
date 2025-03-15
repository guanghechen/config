local FileSelect = require("fml.ux.file_select")
local Select = require("fml.ux.select")

---@class fml.fn.select_files.IParams
---@field public cwd                    string
---@field public dimension              ?fml.ux.search.IRawDimension
---@field public flag_fuzzy             ?boolean
---@field public flag_regex             ?boolean
---@field public input                  ?eve.collection.IObservable -- string>
---@field public multiple               ?boolean
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
  local input = params.input ---@type eve.collection.IObservable -- string> | nil
  local multiple = params.multiple ---@type boolean|nil
  local title = params.title ---@type string
  local fetch_filepaths = params.fetch_filepaths ---@type fun(): string[]
  local get_present = params.get_present ---@type (fun(): string|nil) | nil

  if get_present == nil then
    ---@return string|nil
    get_present = function()
      local present_filepath = nil ---@type string|nil
      local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
      local bufnr_sourcefile = eve.state.tab.get_bufnr_sourcefile(tabnr) ---@type integer|nil
      if bufnr_sourcefile ~= nil then
        local absolute_filepath = vim.api.nvim_buf_get_name(bufnr_sourcefile) ---@type string
        present_filepath = eve.path.relative(cwd, absolute_filepath, true) ---@type string
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
      local data = { items = last_data.items, uuid_present = present }
      return data
    end,
  }

  file_select = FileSelect.new({
    cmp = Select.cmp_by_score,
    dimension = dimension,
    dirty_on_invisible = true,
    preview_enabled = false,
    extend_preset_keymaps = true,
    flag_fuzzy = eve.col.Observable.from_value(flag_fuzzy),
    flag_regex = eve.col.Observable.from_value(flag_regex),
    frecency = eve.state.frecency.files,
    input = input,
    multiple = multiple,
    permanent = false,
    provider = provider,
    title = title,
  }):show()
end

return select_files
