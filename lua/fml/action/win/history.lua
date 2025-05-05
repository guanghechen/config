local __module_name__ = "fml.action.win.history" ---@type string

---@class fml.action.win.history.IItemData
---@field public ordinal                integer
---@field public bufnr                  integer|nil
---@field public filepath               string|nil
---@field public icon                   string
---@field public icon_hln               string

local _history_select = nil ---@type eve.ux.ISelect|nil

---@return eve.ux.ISelect
local function get_history_select()
  local frecency = eve.state.frecency.files ---@type eve.std.collection.IFrecency
  local ORDINAL_WIDTH = vim.api.nvim_strwidth(tostring(eve.setting.WIN_BUF_HISTORY_CAPACITY)) ---@type integer
  local ORDINAL_FORMAT = "%" .. tostring(ORDINAL_WIDTH) .. "d" ---@type string

  ---@param ordinal                       integer
  ---@return string
  local function gen_uuid_from_ordinal(ordinal)
    return string.format(ORDINAL_FORMAT, ordinal) ---@type string
  end

  ---@type eve.ux.select.IProvider
  local provider = {
    fetch_data = function()
      local cwd = eve.path.cwd() ---@type string
      local items = {} ---@type eve.ux.select.IItem[]
      local uuid_present = "0" ---@type string

      local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
      local winnr_sourcefile = eve.tab.retrieve_winnr_sourcefile(tabnr) ---@type integer|nil
      if winnr_sourcefile == nil then
        eve.reporter.error({
          from = __module_name__,
          message = "Cannot resolve sourcefile winnr",
          details = { cwd = cwd, winnr_source = winnr_sourcefile },
        })
        ---@type eve.ux.select.IData
        return { items = {} }
      end

      local meta = eve.win.resolve(winnr_sourcefile, false) ---@type eve.builtin.win.IMeta|nil
      if meta == nil then
        eve.reporter.error({
          from = __module_name__,
          message = "No history found.",
          details = { cwd = cwd, winnr_source = winnr_sourcefile },
        })
        ---@type eve.ux.select.IData
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
          local relative_filepath = eve.path.relative(cwd, filepath, true) ---@type string
          local filename = eve.path.basename(filepath) ---@type string
          local icon, icon_hln = eve.fn.fileicon(filename) ---@type string, string

          ---@type fml.action.win.history.IItemData
          local data = {
            ordinal = ordinal,
            bufnr = bufnr,
            filepath = filepath,
            icon = icon,
            icon_hln = icon_hln,
          }

          ---@type eve.ux.select.IItem
          local item = { uuid = uuid, text = relative_filepath, data = data }
          items[#items + 1] = item

          goto continue
        end

        local filepath = history_item.filepath ---@type string|nil
        if filepath ~= nil and eve.path.is_exist_filepath(filepath) then
          local uuid = gen_uuid_from_ordinal(ordinal) ---@type string
          local relative_filepath = eve.path.relative(cwd, filepath, true) ---@type string
          local filename = eve.path.basename(filepath) ---@type string
          local icon, icon_hln = eve.fn.fileicon(filename) ---@type string, string

          local text = string.format("%2d %s %s", ordinal, icon, relative_filepath) ---@type string

          ---@type fml.action.win.history.IItemData
          local data = {
            ordinal = ordinal,
            bufnr = nil,
            filepath = filepath,
            icon = icon,
            icon_hln = icon_hln,
          }

          ---@type eve.ux.select.IItem
          local item = { uuid = uuid, text = text, data = data }
          items[#items + 1] = item
          goto continue
        end

        ::continue::
      end

      local width = 0 ---@type integer
      for _, item in ipairs(items) do
        local w = vim.api.nvim_strwidth(item.text) ---@type integer
        width = width < w and w or width
      end
      if _history_select ~= nil then
        width = math.max(width + 16, 60)
        _history_select:change_dimension({ height = #items + 3, width = width + 16 })
      end

      ---@type eve.ux.select.IData
      return { items = items, uuid_present = uuid_present }
    end,
    render_item = function(item, match)
      local offset = ORDINAL_WIDTH + 1 ---@type integer
      local width_icon = string.len(item.data.icon) ---@type integer
      local text = string.format("%s %s %s", item.uuid, item.data.icon, item.text) ---@type string

      ---@type eve.t.IHighlightInline[]
      local highlights = {
        {
          coll = offset,
          colr = offset + width_icon,
          hlname = item.data.icon_hl,
        },
      }

      offset = offset + width_icon + 1 ---@type integer
      for _, piece in ipairs(match.matches) do
        ---@type eve.t.IHighlightInline
        local highlight = {
          coll = offset + piece.l,
          colr = offset + piece.r,
          hlname = "f_us_main_match",
        }
        highlights[#highlights + 1] = highlight
      end
      return text, highlights
    end,
  }

  if _history_select == nil then
    ---@type eve.ux.ISelect
    _history_select = eve.ux.Select.new({
      dimension = { height = 3 },
      dirty_on_invisible = true,
      preview_enabled = false,
      extend_preset_keymaps = true,
      frecency = frecency,
      multiple = false,
      provider = provider,
      title = "Find Window History",
      on_confirm = function(widget, items)
        if #items == 1 then
          local item = items[1] ---@type eve.ux.select.IItem
          local item_index = tonumber(item.uuid) ---@type integer|nil
          local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
          local winnr_sourcefile = eve.tab.retrieve_winnr_sourcefile(tabnr) ---@type integer|nil

          if item_index ~= nil and winnr_sourcefile ~= nil then
            local meta = eve.win.resolve(winnr_sourcefile, false) ---@type eve.builtin.win.IMeta|nil
            if meta ~= nil then
              meta.history:go(item_index)
            end
          end

          if winnr_sourcefile ~= nil then
            local data = item.data ---@type fml.action.win.history.IItemData
            widget:close()

            if data.bufnr ~= nil and vim.api.nvim_buf_is_valid(data.bufnr) then
              vim.api.nvim_win_set_buf(winnr_sourcefile, data.bufnr)
            elseif data.filepath ~= nil then
              local bufnr_target = eve.buf.loadfile(data.filepath) ---@type integer|nil
              if bufnr_target ~= nil then
                data.bufnr = bufnr_target ---@type integer
                vim.api.nvim_win_set_buf(winnr_sourcefile, bufnr_target)
              end
            end
          end
        end
      end,
    })
  end
  return _history_select
end

---@class fml.action.win
local M = {}

---@return nil
function M.history()
  local select = get_history_select() ---@type eve.ux.ISelect
  select:show()
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
    eve.reporter.error({
      from = __module_name__,
      subject = "history_backward",
      message = "No history found.",
      details = { winnr = winnr, bufnr = bufnr, buftype = buftype },
    })
    return
  end

  local history = meta.history ---@type eve.std.collection.IHistory|nil
  if history == nil then
    eve.reporter.error({
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
    eve.reporter.error({
      from = __module_name__,
      subject = "history_forward",
      message = "No history found.",
      details = { winnr = winnr, bufnr = bufnr, buftype = buftype },
    })
    return
  end

  local bufnr_target = nil ---@type integer|nil
  local history = meta.history ---@type eve.std.collection.IHistory
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

    if item.filepath ~= nil and eve.path.is_exist_filepath(item.filepath) then
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
