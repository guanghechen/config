local Observable = require("eve.collection.observable")
local FileSelect = require("fml.ux.component.file_select")
local frecency = eve.context.state.frecency.files ---@type t.eve.collection.IFrecency

---@class fml.fn.select_files.IParams
---@field public cwd                    string
---@field public dimension              ?t.fml.ux.search.IRawDimension
---@field public flag_fuzzy             ?boolean
---@field public flag_regex             ?boolean
---@field public input                  ?t.eve.collection.IObservable
---@field public title                  string
---@field public fetch_filepaths        fun(): string[]
---@field public get_present            ?fun(): string|nil

---@param params                        fml.fn.select_files.IParams
---@return nil
local function select_files(params)
  local cwd = params.cwd ---@type string
  local dimension = params.dimension ---@type t.fml.ux.search.IRawDimension|nil
  local flag_fuzzy = not not params.flag_fuzzy ---@type boolean
  local flag_regex = not not params.flag_regex ---@type boolean
  local input = params.input ---@type t.eve.collection.IObservable | nil
  local title = params.title ---@type string
  local fetch_filepaths = params.fetch_filepaths ---@type fun(): string[]
  local get_present = params.get_present ---@type (fun(): string|nil) | nil

  if get_present == nil then
    ---@return string|nil
    get_present = function()
      local present_filepath = nil ---@type string|nil
      local winnr_cur = eve.locations.get_current_winnr() ---@type integer|nil
      if winnr_cur ~= nil and vim.api.nvim_win_is_valid(winnr_cur) then
        local bufnr = vim.api.nvim_win_get_buf(winnr_cur) ---@type integer
        local absolute_filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
        present_filepath = eve.path.relative(cwd, absolute_filepath, true) ---@type string
      end
      return present_filepath
    end
  end

  local file_select = nil ---@type t.fml.ux.IFileSelect|nil
  local last_data = nil ---@type t.fml.ux.file_select.IData|nil

  ---@type t.fml.ux.file_select.IProvider
  local provider = {
    fetch_data = function(force)
      if force or last_data == nil then
        local filepaths = fetch_filepaths() ---@type string[]
        table.sort(filepaths)

        local items = FileSelect.make_items_by_filepaths(filepaths) ---@type t.fml.ux.file_select.IRawItem[]
        last_data = { cwd = cwd, items = items } ---@type t.fml.ux.file_select.IData

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

      ---@type t.fml.ux.file_select.IData
      local data = { cwd = cwd, items = last_data.items, present_uuid = present }
      return data
    end,
  }

  file_select = FileSelect.new({
    cmp = fml.ux.Select.cmp_by_score,
    dimension = dimension,
    dirty_on_invisible = true,
    preview_enabled = false,
    extend_preset_keymaps = true,
    flag_fuzzy = Observable.from_value(flag_fuzzy),
    flag_regex = Observable.from_value(flag_regex),
    frecency = frecency,
    input = input,
    permanent = false,
    provider = provider,
    title = title,
  }):focus()
end

return select_files
