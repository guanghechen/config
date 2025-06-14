---@diagnostic disable: invisible
local __module_name__ = "fml.action.win.history" ---@type string

---@class fml.action.win.history.IItem : eve.ux.picker.composer.list.IItem
---@field public data                   fml.action.win.history.IItemData

---@class fml.action.win.history.IItemData
---@field public ordinal                integer
---@field public bufnr                  integer|nil
---@field public filepath               string|nil
---@field public icon                   string
---@field public icon_hln               string

local ORDINAL_WIDTH = vim.api.nvim_strwidth(tostring(eve.setting.WIN_BUF_HISTORY_CAPACITY)) ---@type integer
local ORDINAL_FORMAT = "%" .. tostring(ORDINAL_WIDTH) .. "d" ---@type string
local last_winnr_sourcefile = nil ---@type integer|nil

---@param ordinal                       integer
---@return string
local function gen_uuid_from_ordinal(ordinal)
  return string.format(ORDINAL_FORMAT, ordinal) ---@type string
end

---@param winnr_sourcefile              integer
---@return eve.ux.picker.composer.list.IResetData
local function fetch_data(winnr_sourcefile)
  local cwd = std.path.cwd() ---@type string
  local items = {} ---@type fml.action.win.history.IItem[]
  local uuid_present = nil ---@type string|nil

  local meta = eve.win.resolve(winnr_sourcefile, false) ---@type eve.builtin.win.IMeta|nil
  if meta == nil then
    std.reporter.error({
      from = __module_name__,
      message = "No history found.",
      details = { cwd = cwd, winnr_source = winnr_sourcefile },
    })
    ---@type eve.ux.picker.composer.list.IResetData
    return { items = {} }
  end

  local _, present_ordinal = meta.history:present() ---@type eve.builtin.win.IFilepathHistoryItem|nil, integer|nil
  if present_ordinal ~= nil then
    uuid_present = gen_uuid_from_ordinal(present_ordinal)
  end

  for history_item, ordinal in meta.history:iterator_reverse() do
    local bufnr = history_item.bufnr ---@type integer|nil
    if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
      local uuid = gen_uuid_from_ordinal(ordinal) ---@type string
      local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
      local relative_filepath = std.path.relative(cwd, filepath, true) ---@type string
      local filename = std.path.basename(filepath) ---@type string
      local icon, icon_hln = std.fileicon.get_file_icon(filename) ---@type string, string

      ---@type std.t.IHighlightInline[]
      local highlights = {
        {
          coll = ORDINAL_WIDTH + 1,
          colr = ORDINAL_WIDTH + 1 + string.len(icon),
          hlname = icon_hln,
        },
      }

      ---@type fml.action.win.history.IItem
      local item = {
        uuid = uuid,
        text = relative_filepath,
        text_lower = relative_filepath:lower(),
        highlights = highlights,
        data = {
          ordinal = ordinal,
          bufnr = bufnr,
          filepath = filepath,
          icon = icon,
          icon_hln = icon_hln,
        },
      }
      items[#items + 1] = item
    else
      local filepath = history_item.filepath ---@type string|nil
      if filepath ~= nil and std.path.is_exist_filepath(filepath) then
        local uuid = gen_uuid_from_ordinal(ordinal) ---@type string
        local relative_filepath = std.path.relative(cwd, filepath, true) ---@type string
        local filename = std.path.basename(filepath) ---@type string
        local icon, icon_hln = std.fileicon.get_file_icon(filename) ---@type string, string

        ---@type std.t.IHighlightInline[]
        local highlights = {
          {
            coll = ORDINAL_WIDTH + 1,
            colr = ORDINAL_WIDTH + 1 + string.len(icon),
            hlname = icon_hln,
          },
        }

        ---@type fml.action.win.history.IItem
        local item = {
          uuid = uuid,
          text = relative_filepath,
          text_lower = relative_filepath:lower(),
          highlights = highlights,

          data = {
            ordinal = ordinal,
            bufnr = bufnr,
            filepath = filepath,
            icon = icon,
            icon_hln = icon_hln,
          },
        }
        items[#items + 1] = item
      end
    end
  end

  ---@type eve.ux.picker.composer.list.IResetData
  return { items = items, uuid_present = uuid_present, uuid_current = uuid_present }
end

local finder_input = std.Observable.from_value("") ---@type std.collection.IObservable
local flag_fuzzy = std.Observable.from_value(true) ---@type std.collection.IObservable
local flag_regex = std.Observable.from_value(false) ---@type std.collection.IObservable
local flag_sensitive = std.Observable.from_value(false) ---@type std.collection.IObservable

---@type eve.ux.picker.ListComposer
local picker = eve.ux.picker.ListComposer.new({
  name = "window-history",
  permanent = true,
  preview = false,
  title = "Find Window History",
  height = 20,
  width = 80,

  finder_input = finder_input,
  flag_fuzzy = flag_fuzzy,
  flag_regex = flag_regex,
  flag_sensitive = flag_sensitive,

  result_render = function(composer, bufnr, _, matches)
    local lines = {} ---@type string[]
    local uuids = {} ---@type string[]
    local cwd = std.path.cwd() ---@type string

    local itemmap = composer._itemmap ---@type table<string, eve.ux.picker.composer.list.IItem>
    ---@cast itemmap                    table<string, fml.action.win.history.IItem>

    for _, match in ipairs(matches) do
      local item = itemmap[match.uuid] ---@type fml.action.win.history.IItem
      local relative_filepath = std.path.relative(cwd, item.data.filepath, false) ---@type string
      local text_displayed = string.format("%s %s %s", item.uuid, item.data.icon, relative_filepath) ---@type string
      lines[#lines + 1] = text_displayed
      uuids[#uuids + 1] = item.uuid
    end

    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    composer._retriever:attach(bufnr, uuids)

    local nsnr_content = eve.var.nsnr.picker_result
    local nsnr_matches = eve.var.nsnr.picker_matches

    for lnum, match in ipairs(matches) do
      local row = lnum - 1 ---@type integer
      local item = composer._itemmap[match.uuid]

      if item and item.highlights then
        for _, hl in ipairs(item.highlights) do
          vim.hl.range(bufnr, nsnr_content, hl.hlname, { row, hl.coll }, { row, hl.colr }, { priority = 10 })
        end
      end

      if match.matches then
        local offset = ORDINAL_WIDTH + 1 + 1 + 1 -- ordinal + space + icon + space
        for _, m in ipairs(match.matches) do
          vim.hl.range(
            bufnr,
            nsnr_matches,
            "f_pk_matches",
            { row, m.l + offset },
            { row, m.r + offset },
            { priority = 30 }
          )
        end
      end
    end

    local data = { uuids = uuids } ---@type eve.ux.picker.composer.list.IResultRenderData
    return data
  end,

  on_confirm = function(composer, item)
    if item ~= nil then
      local item_index = tonumber(item.uuid) ---@type integer|nil
      local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
      local winnr_sourcefile = eve.tab.retrieve_winnr_sourcefile(tabnr) ---@type integer|nil

      if item_index ~= nil and winnr_sourcefile ~= nil then
        local meta = eve.win.resolve(winnr_sourcefile, false) ---@type eve.builtin.win.IMeta|nil
        if meta ~= nil then
          meta.history:go(item_index)
        end
      end

      composer:reset_uuid_present(item.uuid)

      if winnr_sourcefile ~= nil then
        composer:close()

        -- Find the history item by ordinal to get the associated data
        local meta = eve.win.resolve(winnr_sourcefile, false) ---@type eve.builtin.win.IMeta|nil
        if meta ~= nil and item_index ~= nil then
          local history_item = meta.history:at(item_index) ---@type eve.builtin.win.IFilepathHistoryItem|nil
          if history_item ~= nil then
            if history_item.bufnr ~= nil and vim.api.nvim_buf_is_valid(history_item.bufnr) then
              vim.api.nvim_win_set_buf(winnr_sourcefile, history_item.bufnr)
            elseif history_item.filepath ~= nil then
              local bufnr_target = eve.buf.loadfile(history_item.filepath) ---@type integer|nil
              if bufnr_target ~= nil then
                history_item.bufnr = bufnr_target ---@type integer
                vim.api.nvim_win_set_buf(winnr_sourcefile, bufnr_target)
              end
            end
          end
        end
      end
    end
  end,
  on_refresh = function(composer)
    if last_winnr_sourcefile ~= nil and vim.api.nvim_win_is_valid(last_winnr_sourcefile) then
      local data = fetch_data(last_winnr_sourcefile) ---@type eve.ux.picker.composer.list.IResetData
      composer:reset_data(data)
    end
  end,
  on_closed = function()
    last_winnr_sourcefile = nil ---@type integer|nil
  end,
})

---@class fml.action.win
local M = {}

---@return nil
function M.history()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local winnr_sourcefile = eve.tab.retrieve_winnr_sourcefile(tabnr) ---@type integer|nil

  if winnr_sourcefile == nil then
    std.reporter.error({
      from = __module_name__,
      subject = "history",
      message = "Cannot resolve sourcefile winnr",
      details = { tabnr = tabnr, winnr_source = winnr_sourcefile },
    })

    picker:reset_data({ items = {} })
    picker:focus()
    return
  end

  if winnr_sourcefile == last_winnr_sourcefile then
    picker:focus()
    return
  end

  last_winnr_sourcefile = winnr_sourcefile ---@type integer
  finder_input:next("")

  local data = fetch_data(winnr_sourcefile) ---@type eve.ux.picker.composer.list.IResetData
  picker:reset_data(data)
  picker:focus()
end

---@return nil
function M.history_backward()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer

  local buftype = vim.bo[bufnr].buftype ---@type string
  if buftype == "quickfix" then
    eve.qflist.backward()
    return
  end

  local meta = eve.win.resolve(winnr, false) ---@type eve.builtin.win.IMeta|nil
  if meta == nil then
    std.reporter.error({
      from = __module_name__,
      subject = "history_backward",
      message = "No history found.",
      details = { winnr = winnr, bufnr = bufnr, buftype = buftype },
    })
    return
  end

  local history = meta.history ---@type std.collection.IHistory|nil
  if history == nil then
    std.reporter.error({
      from = __module_name__,
      subject = "history_backward",
      message = "No history found.",
      details = { winnr = winnr, bufnr = bufnr, buftype = buftype },
    })
    return
  end

  local bufnr_target = nil ---@type integer|nil
  while true do
    local item, is_bot = history:backward()
    ---@cast item                       eve.builtin.win.IFilepathHistoryItem|nil
    ---@cast is_bot                     boolean

    if item == nil then
      break
    end

    if item.bufnr ~= nil and vim.api.nvim_buf_is_valid(item.bufnr) then
      bufnr_target = item.bufnr ---@type integer
      item.filepath = vim.api.nvim_buf_get_name(bufnr_target) ---@type string
      break
    end

    if item.filepath ~= nil then
      bufnr_target = eve.buf.loadfile(item.filepath) ---@type integer|nil
      if bufnr_target ~= nil then
        item.bufnr = bufnr_target ---@type integer
        break
      end
    end

    if is_bot then
      break
    end
  end

  if bufnr_target ~= nil and bufnr_target ~= bufnr then
    vim.api.nvim_win_set_buf(winnr, bufnr_target)
  end
end

---@return nil
function M.history_forward()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer

  local buftype = vim.bo[bufnr].buftype ---@type string
  if buftype == "quickfix" then
    eve.qflist.forward()
    return
  end

  local meta = eve.win.resolve(winnr, false) ---@type eve.builtin.win.IMeta|nil
  if meta == nil or meta.history == nil then
    std.reporter.error({
      from = __module_name__,
      subject = "history_forward",
      message = "No history found.",
      details = { winnr = winnr, bufnr = bufnr, buftype = buftype },
    })
    return
  end

  local bufnr_target = nil ---@type integer|nil
  local history = meta.history ---@type std.collection.IHistory
  while true do
    local item, is_top = history:forward()
    ---@cast item                       eve.builtin.win.IFilepathHistoryItem|nil
    ---@cast is_top                     boolean

    if item == nil then
      break
    end

    if item.bufnr ~= nil and vim.api.nvim_buf_is_valid(item.bufnr) then
      bufnr_target = item.bufnr ---@type integer
      item.filepath = vim.api.nvim_buf_get_name(bufnr_target) ---@type string
      break
    end

    if item.filepath ~= nil and std.path.is_exist_filepath(item.filepath) then
      bufnr_target = eve.buf.loadfile(item.filepath) ---@type integer|nil
      if bufnr_target ~= nil then
        item.bufnr = bufnr_target ---@type integer
        break
      end
    end

    if is_top then
      break
    end
  end

  if bufnr_target ~= nil and bufnr_target ~= bufnr then
    vim.api.nvim_win_set_buf(winnr, bufnr_target)
  end
end

return M
