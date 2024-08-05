local constant = require("fml.constant")
local History = require("fml.collection.history")
local Observable = require("fml.collection.observable")
local session = require("ghc.context.session")
local statusline = require("ghc.ui.statusline")
local util_search_files_scope = require("ghc.util.search.files_scope")

---@class ghc.command.search
local M = require("ghc.command.search.mod")

---@type string
local _filepath = fml.path.locate_session_filepath({ filename = "state.search_files.json" })

---@type fml.types.collection.IHistory
local _input_history = History.new({
  name = "search_files",
  capacity = 100,
  validate = fml.string.is_non_blank_string,
})

---@class ghc.command.search.files.IStateData
---@field input_history                 ?fml.types.collection.history.ISerializedData|nil

local _state_data = fml.fs.read_json({ filepath = _filepath, silent_on_bad_path = true, silent_on_bad_json = false })
if _state_data ~= nil then
  ---@cast _state_data ghc.command.search.files.IStateData
  _input_history:load(_state_data.input_history)
end

local _search = nil ---@type fml.types.ui.search.ISearch|nil
fml.disposable:add_disposable(fml.collection.Disposable.new({
  on_dispose = function()
    if _search ~= nil then
      local ok, data = pcall(function()
        local input_history = _input_history:dump() ---@type fml.types.collection.history.ISerializedData
        local stack = input_history.stack ---@type fml.types.T[]
        if #stack > 0 then
          local prefix = constant.EDITING_INPUT_PREFIX ---@type string
          local top = stack[#stack] ---@type string
          if #top > #prefix and string.sub(top, 1, #prefix) == prefix then
            stack[#stack] = string.sub(top, #prefix + 1)
          end
        end
        return { input_history = input_history } ---@type ghc.command.search.files.IStateData
      end)
      if ok then
        fml.fs.write_json(_filepath, data, false)
      else
        fml.fs.write_json(_filepath, { error = data }, false)
      end
    end
  end,
}))

local state_dirpath = fml.collection.Observable.from_value(vim.fn.expand("%:p:h"))
local state_search_cwd = fml.collection.Observable.from_value(
  util_search_files_scope.get_cwd(session.find_scope:snapshot(), state_dirpath:snapshot()) ---@type string
)

---@class ghc.command.search.IItemData
---@field public filepath               string
---@field public filematch              fml.std.oxi.search.IFileMatch
---@field public lnum                   ?integer
---@field public col                    ?integer

local _item_data_map = {} ---@type table<string, ghc.command.search.IItemData>

---@param input_text                  string
---@param callback                    fml.types.ui.search.IFetchItemsCallback
---@return nil
local function fetch_items(input_text, callback)
  local cwd = session.search_cwd:snapshot() ---@type string
  local flag_case_sensitive = session.search_flag_regex:snapshot() ---@type boolean
  local flag_regex = session.search_flag_regex:snapshot() ---@type boolean
  local search_paths = session.search_paths:snapshot() ---@type string
  local include_patterns = session.search_include_patterns:snapshot() ---@type string
  local exclude_patterns = session.search_exclude_patterns:snapshot() ---@type string
  local scope = session.search_scope:snapshot() ---@type string

  ---@type fml.std.oxi.search.IResult
  local result = fml.oxi.search({
    cwd = cwd,
    flag_case_sensitive = flag_case_sensitive,
    flag_regex = flag_regex,
    search_pattern = input_text,
    search_paths = search_paths,
    include_patterns = include_patterns,
    exclude_patterns = exclude_patterns,
    specified_filepath = nil,
  })

  if result.error ~= nil or result.items == nil then
    callback(false, result.error)
    return
  end

  local items = {} ---@type fml.types.ui.search.IItem[]
  local item_data_map = {} ---@type table<string, ghc.command.search.IItemData>
  for _, raw_filepath in ipairs(result.item_orders) do
    local file_match = result.items[raw_filepath] ---@type fml.std.oxi.search.IFileMatch|nil
    if file_match ~= nil then
      local filename = fml.path.basename(raw_filepath) ---@type string
      local filepath = fml.path.relative(cwd, raw_filepath) ---@type string
      local icon, icon_hl = fml.util.calc_fileicon(filename)
      local icon_width = string.len(icon) ---@type integer
      local file_highlights = { { cstart = 0, cend = icon_width, hlname = icon_hl } } ---@type fml.types.ui.printer.ILineHighlight[]

      ---@type fml.types.ui.search.IItem
      local file_item = {
        uuid = filepath,
        text = icon .. " " .. filepath,
        highlights = file_highlights,
      }
      table.insert(items, file_item)

      ---@class ghc.command.search.IItemData
      item_data_map[file_item.uuid] = {
        filepath = filepath,
        filematch = file_match,
      }

      for _, block_match in ipairs(file_match.matches) do
        local lines = block_match.lines ---@type string[]
        local lnum0 = block_match.lnum ---@type integer

        local k = 1 ---@type integer
        local offset = 0 ---@type integer
        local lwidth = string.len(lines[1]) + 1 ---@type integer
        for _, match in ipairs(block_match.matches) do
          while match.l > offset + lwidth and k < #lines do
            k = k + 1
            offset = offset + lwidth
            lwidth = string.len(lines[k]) + 1
          end

          local lnum = lnum0 + k - 1 ---@type integer
          local col_start = match.l - offset ---@type integer
          local colr_end = math.min(lwidth - 1, match.r - offset) ---@type integer
          local text_prefix = "  " .. lnum .. ":" .. col_start ---@type string
          local text = text_prefix .. lines[k] ---@type string

          local offset_prefix = string.len(text_prefix) ---@type integer
          local offset_start = offset_prefix + col_start ---@type integer
          local offset_end = offset_prefix + colr_end ---@type integer

          ---@type fml.types.ui.printer.ILineHighlight[]
          local highlights = {
            { cstart = 0, cend = offset_prefix, hlname = "f_us_main_match_lnum" },
            { cstart = offset_start, cend = offset_end, hlname = "f_us_main_match" },
          }

          ---@type fml.types.ui.search.IItem
          local match_item = {
            uuid = filepath .. text_prefix,
            text = text,
            highlights = highlights,
          }
          table.insert(items, match_item)

          ---@class ghc.command.search.IItemData
          item_data_map[match_item.uuid] = {
            filepath = filepath,
            filematch = file_match,
            lnum = lnum,
            col = col_start,
          }
        end
      end
    end
  end
  _item_data_map = item_data_map
  callback(true, items)
end

---@param scope                         ghc.enums.context.FindScope
---@return nil
local function change_scope(scope)
  local scope_current = session.find_scope:snapshot() ---@type ghc.enums.context.FindScope
  if _search ~= nil and scope_current ~= scope then
    session.find_scope:next(scope)
    local dirpath = state_dirpath:snapshot() ---@type string
    local search_cwd = util_search_files_scope.get_cwd(scope, dirpath) ---@type string
    state_search_cwd:next(search_cwd)
    M.reload()
  end
end

---@return fml.types.ui.search.ISearch
local function get_search()
  if _search == nil then
    local actions = {
      change_scope_workspace = function()
        change_scope("W")
      end,
      change_scope_cwd = function()
        change_scope("C")
      end,
      change_scope_directory = function()
        change_scope("D")
      end,
      change_scope_carousel = function()
        ---@type ghc.enums.context.FindScope
        local scope = session.find_scope:snapshot()
        local scope_next = util_search_files_scope.get_carousel_next(scope)
        change_scope(scope_next)
      end,
    }

    ---@type fml.types.IKeymap[]
    local input_keymaps = {
      {
        modes = { "n", "v" },
        key = "<leader>w",
        callback = actions.change_scope_workspace,
        desc = "find: change scope (workspace)",
      },
      {
        modes = { "n", "v" },
        key = "<leader>c",
        callback = actions.change_scope_cwd,
        desc = "find: change scope (cwd)",
      },
      {
        modes = { "n", "v" },
        key = "<leader>d",
        callback = actions.change_scope_directory,
        desc = "find: change scope (directory)",
      },
      {
        modes = { "n", "v" },
        key = "<leader>s",
        callback = actions.change_scope_carousel,
        desc = "find: change scope (carousel)",
      },
    }

    ---@type fml.types.IKeymap[]
    local main_keymaps = vim.tbl_deep_extend("force", {}, input_keymaps)

    _search = fml.ui.search.Search.new({
      title = "Search in files",
      input = Observable.from_value(""),
      input_history = _input_history,
      input_keymaps = input_keymaps,
      main_keymaps = main_keymaps,
      fetch_items = fetch_items,
      fetch_delay = 32,
      width = 80,
      height = 0.8,
      on_close = function()
        statusline.disable(statusline.cnames.search_files)
      end,
      on_confirm = function(item)
        local winnr = fml.api.state.win_history:present() ---@type integer
        if winnr ~= nil then
          local cwd = session.search_cwd:snapshot() ---@type string
          local data = _item_data_map[item.uuid] ---@type ghc.command.search.IItemData|nil
          if data ~= nil then
            local filepath = fml.path.join(cwd, data.filepath) ---@type string
            vim.schedule(function()
              fml.api.buf.open(winnr, filepath)

              local lnum = data.lnum ---@type integer|nil
              local col = data.col ---@type integer|nil
              if lnum ~= nil and col ~= nil then
                vim.schedule(function()
                  vim.api.nvim_win_set_cursor(0, { data.lnum or 1, data.col or 0 })
                end)
              end
            end)
          end
          return true
        end
        return false
      end,
    })
  end
  return _search
end

---@return nil
function M.reload()
  if _search ~= nil then
    _search.state:mark_items_dirty()
  end
end

---@return nil
function M.files()
  state_dirpath:next(vim.fn.expand("%:p:h"))
  local search = get_search() ---@type fml.types.ui.search.ISearch
  statusline.enable(statusline.cnames.search_files)
  search:open()
end
