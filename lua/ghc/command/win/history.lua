local __module_name__ = "ghc.command.win.history" ---@type string

local path = require("eve.lib.path")
local reporter = require("eve.lib.reporter")
local uuids = eve.commander.uuids ---@type eve.builtin.commander.uuids
local state = require("eve.state")

local _history_select = nil ---@type fml.ux.FileSelect|nil

---@return fml.ux.FileSelect
local function get_history_select()
  if _history_select == nil then
    local ORIDINAL_WIDTH = vim.api.nvim_strwidth(tostring(eve.constant.WIN_BUF_HISTORY_CAPACITY)) ---@type integer
    local frecency = state.state.frecency.files ---@type eve.lib.collection.IFrecency

    ---@param ordinal                       integer
    ---@return string
    local function gen_uuid_from_ordinal(ordinal)
      return eve.util.pad_start(tostring(ordinal), ORIDINAL_WIDTH, " ")
    end

    ---@type fml.t.ux.file_select.IProvider
    local provider = {
      fetch_data = function()
        local cwd = path.cwd() ---@type string
        local items = {} ---@type fml.t.ux.file_select.IRawItem[]
        local present_uuid = "0" ---@type string
        local width = 0 ---@type integer
        local winnr = eve.tab.get_current_winnr() ---@type integer
        local meta = eve.win.resolve(winnr) ---@type eve.t.state.state.win.IMeta|nil
        if meta == nil then
          reporter.error({
            from = __module_name__,
            message = "Cannot find window.",
            details = { winnr = winnr },
          })

          ---@type fml.t.ux.file_select.IData
          return { cwd = cwd, items = {} }
        else
          local _, present_ordinal = meta.filepath_history:present() ---@type string|nil, integer|nil
          if present_ordinal ~= nil then
            present_uuid = gen_uuid_from_ordinal(present_ordinal)
          end

          for absolute_filepath, ordinal in meta.filepath_history:iterator_reverse() do
            local filepath = path.relative(cwd, absolute_filepath, true) ---@type string
            local uuid = gen_uuid_from_ordinal(ordinal) ---@type string
            local item = { uuid = uuid, filepath = filepath } ---@type fml.t.ux.file_select.IRawItem
            items[#items + 1] = item
          end

          for _, item in ipairs(items) do
            local w = vim.api.nvim_strwidth(item.filepath) ---@type integer
            width = width < w and w or width
          end
        end

        if _history_select ~= nil then
          width = math.max(width + 16, 60)
          _history_select:change_dimension({ height = #items + 3, width = width + 16 })
        end

        ---@type fml.t.ux.file_select.IData
        return { cwd = cwd, items = items, present_uuid = present_uuid }
      end,
      render_item = function(item, match)
        local text_prefix = item.uuid .. " " ---@type string
        local width_prefix = ORIDINAL_WIDTH + 1 ---@type integer
        local width_icon = string.len(item.data.icon) ---@type integer
        local text = text_prefix .. item.data.icon .. item.data.filepath ---@type string

        ---@type eve.t.IHighlightInline[]
        local highlights = {
          {
            coll = width_prefix,
            colr = width_prefix + width_icon,
            hlname = item.data.icon_hl,
          },
        }
        for _, piece in ipairs(match.matches) do
          ---@type eve.t.IHighlightInline
          local highlight = {
            coll = width_prefix + width_icon + piece.l,
            colr = width_prefix + width_icon + piece.r,
            hlname = "f_us_main_match",
          }
          highlights[#highlights + 1] = highlight
        end
        return text, highlights
      end,
    }

    _history_select = fml.ux.FileSelect.new({
      dimension = { height = 3 },
      dirty_on_invisible = true,
      preview_enabled = false,
      extend_preset_keymaps = true,
      frecency = frecency,
      provider = provider,
      title = "Find Window History",
      on_confirm = function(item)
        local item_index = tonumber(item.uuid) ---@type integer|nil
        if item_index ~= nil then
          local winnr = eve.tab.get_current_winnr() ---@type integer
          local meta = eve.win.resolve(winnr) ---@type eve.t.state.state.win.IMeta|nil
          if meta ~= nil then
            meta.filepath_history:go(item_index)
          end
        end

        if _history_select ~= nil then
          local cwd = path.cwd() ---@type string
          local filepath = path.join(cwd, item.data.filepath) ---@type string
          local ok = eve.buf.open_filepath_in_current_valid_win(filepath)
          return ok and "close" or "none"
        end
        return "none"
      end,
    })
  end
  return _history_select
end

eve.commander
  .register({
    uuid = uuids.win_history,
    desc = "win: history",
    action = function()
      local select = get_history_select() ---@type fml.ux.FileSelect
      select:focus()
    end,
  })
  .register({
    uuid = uuids.win_history_backward,
    desc = "win: history backward",
    action = function()
      local winnr = vim.api.nvim_get_current_win() ---@type integer

      local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
      local buftype = vim.bo[bufnr].buftype ---@type string
      if buftype == eve.constant.BT_QUICKFIX then
        eve.qflist.backward()
        return
      end

      local meta = eve.win.resolve(winnr) ---@type eve.t.state.state.win.IMeta|nil
      if meta == nil then
        reporter.error({
          from = __module_name__,
          subject = "history.backward",
          message = "Cannot find window.",
          details = { winnr = winnr },
        })
        return
      end

      local last_filepath = meta.filepath_history:backward() ---@type string|nil
      if last_filepath ~= nil then
        eve.buf.open_filepath(winnr, last_filepath)
      end
    end,
  })
  .register({
    uuid = uuids.win_history_forward,
    desc = "win: history forward",
    action = function()
      local winnr = vim.api.nvim_get_current_win() ---@type integer

      local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
      local buftype = vim.bo[bufnr].buftype ---@type string
      if buftype == eve.constant.BT_QUICKFIX then
        eve.qflist.forward()
        return
      end

      local meta = eve.win.resolve(winnr) ---@type eve.t.state.state.win.IMeta|nil
      if meta == nil then
        reporter.error({
          from = __module_name__,
          subject = "history.forward",
          message = "Cannot find window.",
          details = { winnr = winnr },
        })
        return
      end

      local next_filepath = meta.filepath_history:forward() ---@type string|nil
      if next_filepath ~= nil then
        eve.buf.open_filepath(winnr, next_filepath)
      end
    end,
  })
