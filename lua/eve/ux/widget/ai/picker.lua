local __module_name__ = "eve.ux.widget.ai.picker" ---@type string

local config = require("eve.ux.widget.ai.config")
local state = require("eve.ux.widget.ai.state")

---@class eve.ux.widget.ai.picker.IItem : eve.ux.picker.composer.list.IItem
---@field public data                   any

---@class eve.ux.widget.ai.picker
local M = {}

----------------------------------------------------------------------------------------------------
--- Picker utilities
----------------------------------------------------------------------------------------------------

---@return std.collection.IObservable, std.collection.IObservable, std.collection.IObservable, std.collection.IObservable
local function create_picker_flags()
  return std.Observable.from_value(""),
    std.Observable.from_value(true),
    std.Observable.from_value(false),
    std.Observable.from_value(false)
end

---@param flags                         std.collection.IObservable[]
---@return nil
local function dispose_picker_flags(flags)
  for _, flag in ipairs(flags) do
    flag:dispose()
  end
end

---@param winnr                         integer
---@return nil
local function restore_window(winnr)
  if vim.api.nvim_win_is_valid(winnr) then
    vim.api.nvim_tabpage_set_win(0, winnr)
  end
end

---@param items                         eve.ux.picker.composer.list.IItem[]
---@param width                         integer
---@return integer, integer
local function calc_picker_dimensions(items, width)
  local height = math.min(#items + 3, math.floor(vim.o.lines * 0.6))
  width = math.max(60, width)
  return height, width
end

----------------------------------------------------------------------------------------------------
--- Item builders
----------------------------------------------------------------------------------------------------

---@class eve.ux.widget.ai.picker.IAttachItemInfo
---@field public item                   eve.ux.widget.ai.ISelectItem
---@field public category               eve.ux.widget.ai.ItemCategory
---@field public agent_label            string
---@field public identifier             string|nil
---@field public pane_cwd               string|nil
---@field public uuid                   string

---@param info                          eve.ux.widget.ai.picker.IAttachItemInfo
---@return string
local function get_item_hlname(info)
  local category = info.category
  if category == "attached" then
    return "f_us_ai_attached"
  elseif category == "same_window" then
    return "f_us_ai_running_same_window"
  elseif category == "same_session" then
    return "f_us_ai_running_same_session"
  elseif category == "other_tmux" then
    return "f_us_ai_running_other_session"
  else
    return "f_us_ai_new"
  end
end

---@param a                             eve.ux.widget.ai.picker.IAttachItemInfo
---@param b                             eve.ux.widget.ai.picker.IAttachItemInfo
---@return boolean
local function compare_by_pane_id(a, b)
  local a_pane = a.item.source and a.item.source.tmux_pane
  local b_pane = b.item.source and b.item.source.tmux_pane
  if a_pane and b_pane then
    local a_num = tonumber(a_pane.pane_id:match("%%(%d+)")) or 0
    local b_num = tonumber(b_pane.pane_id:match("%%(%d+)")) or 0
    return a_num < b_num
  end
  return false
end

---@param a                             eve.ux.widget.ai.picker.IAttachItemInfo
---@param b                             eve.ux.widget.ai.picker.IAttachItemInfo
---@return boolean
local function compare_by_session_window_pane(a, b)
  local a_pane = a.item.source and a.item.source.tmux_pane
  local b_pane = b.item.source and b.item.source.tmux_pane
  if a_pane and b_pane then
    if a_pane.session_name ~= b_pane.session_name then
      return a_pane.session_name < b_pane.session_name
    end
    if a_pane.window_name ~= b_pane.window_name then
      return a_pane.window_name < b_pane.window_name
    end
    local a_num = tonumber(a_pane.pane_id:match("%%(%d+)")) or 0
    local b_num = tonumber(b_pane.pane_id:match("%%(%d+)")) or 0
    return a_num < b_num
  end
  return false
end

---@param a                             eve.ux.widget.ai.picker.IAttachItemInfo
---@param b                             eve.ux.widget.ai.picker.IAttachItemInfo
---@return boolean
local function compare_by_agent_name(a, b)
  return a.item.agent < b.item.agent
end

---@param items                         eve.ux.widget.ai.ISelectItem[]
---@return eve.ux.widget.ai.picker.IItem[], integer
local function build_attach_picker_items(items)
  local action = require("eve.ux.widget.ai.action")
  local tmux = require("eve.ux.widget.ai.tmux")
  local current_info = tmux.get_current_info()
  local current_session = current_info and current_info.session_name or ""
  local current_window = current_info and current_info.window_name or ""

  local width_agent = 0 ---@type integer
  local width_identifier = 0 ---@type integer

  local attached_infos = {} ---@type eve.ux.widget.ai.picker.IAttachItemInfo[]
  local same_window_infos = {} ---@type eve.ux.widget.ai.picker.IAttachItemInfo[]
  local same_session_infos = {} ---@type eve.ux.widget.ai.picker.IAttachItemInfo[]
  local other_tmux_infos = {} ---@type eve.ux.widget.ai.picker.IAttachItemInfo[]
  local new_agent_infos = {} ---@type eve.ux.widget.ai.picker.IAttachItemInfo[]

  for _, item in ipairs(items) do
    local agent_label = config.agent_labels[item.agent] or item.agent
    local attached = item.source ~= nil and state.is_attached(item.source)
    local identifier = item.source and action.get_source_identifier(item.source) or nil
    local pane_cwd = item.source and std.path.shorten(item.source.cwd) or nil

    width_agent = math.max(width_agent, #agent_label)
    if identifier then
      width_identifier = math.max(width_identifier, #identifier)
    end

    local pane = item.source and item.source.tmux_pane
    local category ---@type eve.ux.widget.ai.ItemCategory

    if attached then
      category = "attached"
    elseif item.type == "new" then
      category = "new_agent"
    elseif pane then
      local same_session = pane.session_name == current_session
      local same_window = same_session and pane.window_name == current_window
      if same_window then
        category = "same_window"
      elseif same_session then
        category = "same_session"
      else
        category = "other_tmux"
      end
    else
      category = "new_agent"
    end

    local uuid = item.source and item.source.id or string.format("new:%s", item.agent)

    ---@type eve.ux.widget.ai.picker.IAttachItemInfo
    local info = {
      item = item,
      category = category,
      agent_label = agent_label,
      identifier = identifier,
      pane_cwd = pane_cwd,
      uuid = uuid,
    }

    if category == "attached" then
      attached_infos[#attached_infos + 1] = info
    elseif category == "same_window" then
      same_window_infos[#same_window_infos + 1] = info
    elseif category == "same_session" then
      same_session_infos[#same_session_infos + 1] = info
    elseif category == "other_tmux" then
      other_tmux_infos[#other_tmux_infos + 1] = info
    else
      new_agent_infos[#new_agent_infos + 1] = info
    end
  end

  table.sort(attached_infos, compare_by_session_window_pane)
  table.sort(same_window_infos, compare_by_pane_id)
  table.sort(same_session_infos, compare_by_session_window_pane)
  table.sort(other_tmux_infos, compare_by_session_window_pane)
  table.sort(new_agent_infos, compare_by_agent_name)

  local sorted_infos = {} ---@type eve.ux.widget.ai.picker.IAttachItemInfo[]
  vim.list_extend(sorted_infos, attached_infos)
  vim.list_extend(sorted_infos, same_window_infos)
  vim.list_extend(sorted_infos, same_session_infos)
  vim.list_extend(sorted_infos, other_tmux_infos)
  vim.list_extend(sorted_infos, new_agent_infos)

  local picker_items = {} ---@type eve.ux.widget.ai.picker.IItem[]

  for _, info in ipairs(sorted_infos) do
    local item = info.item

    local icon = info.category == "attached" and eve.icon.status.attached
      or (item.type == "running" and eve.icon.status.detached or " ")
    local text_agent = std.string.pad_end(info.agent_label, width_agent, " ")
    local text_identifier = info.identifier and ("  " .. std.string.pad_end(info.identifier, width_identifier, " "))
      or ""
    local text_pane_cwd = info.pane_cwd and ("  " .. info.pane_cwd) or ""
    local text = icon .. " " .. text_agent .. text_identifier .. text_pane_cwd

    local hlname = get_item_hlname(info)

    picker_items[#picker_items + 1] = {
      uuid = info.uuid,
      text = text,
      text_lower = text:lower(),
      highlights = { { coll = 0, colr = #text, hlname = hlname } },
      data = item,
    }
  end

  return picker_items, 2 + width_agent + width_identifier + 50
end

---@param attached                      eve.ux.widget.ai.IAttachedSource[]
---@return eve.ux.widget.ai.picker.IItem[], integer
local function build_attached_picker_items(attached)
  local action = require("eve.ux.widget.ai.action")

  local width_agent = 0 ---@type integer
  local width_identifier = 0 ---@type integer

  ---@class eve.ux.widget.ai.picker.IAttachedItemInfo
  ---@field public source               eve.ux.widget.ai.IAttachedSource
  ---@field public agent_label          string
  ---@field public identifier           string|nil
  ---@field public pane_cwd             string|nil

  local item_infos = {} ---@type eve.ux.widget.ai.picker.IAttachedItemInfo[]

  for _, source in ipairs(attached) do
    local agent_label = config.agent_labels[source.agent] or source.agent
    local identifier = action.get_source_identifier(source)
    local pane_cwd = std.path.shorten(source.cwd)

    width_agent = math.max(width_agent, #agent_label)
    if identifier then
      width_identifier = math.max(width_identifier, #identifier)
    end

    item_infos[#item_infos + 1] = {
      source = source,
      agent_label = agent_label,
      identifier = identifier,
      pane_cwd = pane_cwd,
    }
  end

  local picker_items = {} ---@type eve.ux.widget.ai.picker.IItem[]

  for _, info in ipairs(item_infos) do
    local source = info.source

    local text_agent = std.string.pad_end(info.agent_label, width_agent, " ")
    local text_identifier = info.identifier and ("  " .. std.string.pad_end(info.identifier, width_identifier, " "))
      or ""
    local text_pane_cwd = info.pane_cwd and ("  " .. info.pane_cwd) or ""
    local text = eve.icon.status.attached .. " " .. text_agent .. text_identifier .. text_pane_cwd

    picker_items[#picker_items + 1] = {
      uuid = source.id,
      text = text,
      text_lower = text:lower(),
      highlights = { { coll = 0, colr = #text, hlname = "f_us_ai_attached" } },
      data = source,
    }
  end

  return picker_items, 2 + width_agent + width_identifier + 50
end

----------------------------------------------------------------------------------------------------
--- Public picker functions
----------------------------------------------------------------------------------------------------

---@class eve.ux.widget.ai.picker.IShowAttachParams
---@field public on_select              fun(item: eve.ux.widget.ai.ISelectItem): nil
---@field public on_toggle              ?fun(item: eve.ux.widget.ai.ISelectItem): nil

---@param params                        eve.ux.widget.ai.picker.IShowAttachParams
---@return nil
function M.show_attach(params)
  local on_select = params.on_select
  local on_toggle = params.on_toggle

  local action = require("eve.ux.widget.ai.action")
  local items = action.collect_items()
  local picker_items, width = build_attach_picker_items(items)
  local winnr = vim.api.nvim_get_current_win()
  local search_pattern, flag_fuzzy, flag_regex, flag_case_sensitive = create_picker_flags()
  local picker_height, picker_width = calc_picker_dimensions(picker_items, width)

  ---@type eve.ux.picker.ListComposer|nil
  local picker = nil

  ---@return nil
  local function do_toggle()
    if not picker or not on_toggle then
      return
    end
    local lnum = picker.result.lnum_current:snapshot()
    local item = picker:retrieve(lnum)
    if item then
      ---@cast item eve.ux.widget.ai.picker.IItem
      on_toggle(item.data)
      local new_items = action.collect_items()
      local new_picker_items = build_attach_picker_items(new_items)
      picker:reset_data({ items = new_picker_items, uuid_current = item.uuid })
    end
  end

  picker = eve.ux.picker.ListComposer.new({
    name = __module_name__,
    permanent = false,
    title = " Select CLI tool ",
    height = picker_height,
    width = picker_width,
    search_pattern = search_pattern,
    flag_fuzzy = flag_fuzzy,
    flag_regex = flag_regex,
    flag_case_sensitive = flag_case_sensitive,
    keymaps_common = on_toggle and {
      { modes = { "i", "n", "x" }, key = "<C-l>", callback = do_toggle, desc = "Toggle attach/detach" },
      { modes = { "i", "n", "x" }, key = "<C-h>", callback = do_toggle, desc = "Toggle attach/detach" },
    } or nil,
    keymaps_result = on_toggle and {
      { modes = { "i", "n", "x" }, key = "<space>", callback = do_toggle, desc = "Toggle attach/detach" },
    } or nil,
    on_cancel = function()
      restore_window(winnr)
    end,
    on_confirm = function(composer, item)
      restore_window(winnr)
      composer:close()
      if item ~= nil then
        ---@cast item eve.ux.widget.ai.picker.IItem
        on_select(item.data)
      end
    end,
    on_disposed = function()
      dispose_picker_flags({ search_pattern, flag_fuzzy, flag_regex, flag_case_sensitive })
    end,
  })

  picker:reset_data({ items = picker_items })
  picker:focus()
end

---@param attached                      eve.ux.widget.ai.IAttachedSource[]
---@param on_select                     fun(item: eve.ux.widget.ai.IAttachedSource): nil
---@return nil
function M.show_detach(attached, on_select)
  local picker_items, width = build_attached_picker_items(attached)
  local winnr = vim.api.nvim_get_current_win()
  local search_pattern, flag_fuzzy, flag_regex, flag_case_sensitive = create_picker_flags()
  local picker_height, picker_width = calc_picker_dimensions(picker_items, width)

  ---@type eve.ux.picker.ListComposer
  local picker = eve.ux.picker.ListComposer.new({
    name = __module_name__,
    permanent = false,
    title = " Detach agent ",
    height = picker_height,
    width = picker_width,
    search_pattern = search_pattern,
    flag_fuzzy = flag_fuzzy,
    flag_regex = flag_regex,
    flag_case_sensitive = flag_case_sensitive,
    on_cancel = function()
      restore_window(winnr)
    end,
    on_confirm = function(composer, item)
      restore_window(winnr)
      composer:close()
      if item ~= nil then
        ---@cast item eve.ux.widget.ai.picker.IItem
        on_select(item.data)
      end
    end,
    on_disposed = function()
      dispose_picker_flags({ search_pattern, flag_fuzzy, flag_regex, flag_case_sensitive })
    end,
  })

  picker:reset_data({ items = picker_items })
  picker:focus()
end

---@param attached                      eve.ux.widget.ai.IAttachedSource[]
---@param on_select                     fun(items: eve.ux.widget.ai.IAttachedSource[]): nil
---@return nil
function M.show_send_target(attached, on_select)
  local picker_items, width = build_attached_picker_items(attached)
  local winnr = vim.api.nvim_get_current_win()
  local search_pattern, flag_fuzzy, flag_regex, flag_case_sensitive = create_picker_flags()

  local send_to_all_uuid = "__send_to_all__" ---@type string
  local has_multiple = #attached > 1 ---@type boolean

  if has_multiple then
    local send_to_all_text = eve.icon.status.broadcast .. " send to all (" .. #attached .. " agents)"
    table.insert(picker_items, 1, {
      uuid = send_to_all_uuid,
      text = send_to_all_text,
      text_lower = send_to_all_text:lower(),
      highlights = { { coll = 0, colr = #send_to_all_text, hlname = "f_us_ai_send_to_all" } },
      data = nil,
    })
  end

  local picker_height, picker_width = calc_picker_dimensions(picker_items, width)

  local selected_set = {} ---@type table<string, boolean>
  local source_map = {} ---@type table<string, eve.ux.widget.ai.IAttachedSource>

  for _, item in ipairs(picker_items) do
    if item.uuid ~= send_to_all_uuid then
      source_map[item.uuid] = item.data
    end
  end

  ---@type eve.ux.picker.ListComposer|nil
  local picker = nil

  ---@return nil
  local function toggle_current_selection()
    if not picker then
      return
    end
    local lnum = picker.result.lnum_current:snapshot()
    local item = picker:retrieve(lnum)
    if item and item.uuid ~= send_to_all_uuid then
      selected_set[item.uuid] = not selected_set[item.uuid] or nil
      picker.result:refresh_signs()
    end
  end

  ---@return nil
  local function confirm_selection()
    if not picker then
      return
    end

    local results = {} ---@type eve.ux.widget.ai.IAttachedSource[]
    local has_selection = next(selected_set) ~= nil

    if has_selection then
      for uuid, _ in pairs(selected_set) do
        if source_map[uuid] then
          results[#results + 1] = source_map[uuid]
        end
      end
    else
      local lnum = picker.result.lnum_current:snapshot()
      local item = picker:retrieve(lnum)
      if item then
        if item.uuid == send_to_all_uuid then
          for _, source in ipairs(attached) do
            results[#results + 1] = source
          end
        elseif source_map[item.uuid] then
          results[#results + 1] = source_map[item.uuid]
        end
      end
    end

    restore_window(winnr)
    picker:close()

    if #results > 0 then
      on_select(results)
    end
  end

  ---@param _                           integer
  ---@param lnum                        integer
  ---@return boolean
  local function isselected(_, lnum)
    if not picker then
      return false
    end
    local item = picker:retrieve(lnum)
    return item ~= nil and selected_set[item.uuid] == true
  end

  picker = eve.ux.picker.ListComposer.new({
    name = __module_name__,
    permanent = false,
    title = " Select target agents (Tab: toggle, Enter: confirm) ",
    height = picker_height,
    width = picker_width,
    search_pattern = search_pattern,
    flag_fuzzy = flag_fuzzy,
    flag_regex = flag_regex,
    flag_case_sensitive = flag_case_sensitive,
    result_is_selected = isselected,
    keymaps_result = {
      { modes = { "n" }, key = "<Tab>", callback = toggle_current_selection, desc = "Toggle selection" },
      { modes = { "n" }, key = "<S-Tab>", callback = toggle_current_selection, desc = "Toggle selection" },
    },
    on_cancel = function()
      restore_window(winnr)
    end,
    on_confirm = function()
      confirm_selection()
    end,
    on_disposed = function()
      dispose_picker_flags({ search_pattern, flag_fuzzy, flag_regex, flag_case_sensitive })
    end,
  })

  picker:reset_data({ items = picker_items })
  picker:focus()
end

---@param on_select                     fun(prompt: eve.ux.widget.ai.IPrompt, result: eve.ux.widget.ai.IPromptRenderResult): nil
---@return nil
function M.show_prompt(on_select)
  local prompt_mod = require("eve.ux.widget.ai.prompt")
  local ctx = prompt_mod.get_ctx()

  local picker_items = {} ---@type eve.ux.widget.ai.picker.IItem[]
  local itemmap = {} ---@type table<string, eve.ux.widget.ai.IPrompt>
  local result_map = {} ---@type table<string, eve.ux.widget.ai.IPromptRenderResult>

  for index, prompt in ipairs(prompt_mod.list) do
    local result = prompt.render(ctx)
    if result then
      local uuid = tostring(index)
      itemmap[uuid] = prompt
      result_map[uuid] = result
      picker_items[#picker_items + 1] = {
        uuid = uuid,
        text = prompt.name,
        text_lower = prompt.name:lower(),
        highlights = {},
        data = prompt,
      }
    end
  end

  local winnr = vim.api.nvim_get_current_win()
  local search_pattern, flag_fuzzy, flag_regex, flag_case_sensitive = create_picker_flags()
  local picker_height = math.min(#picker_items + 3, math.floor(vim.o.lines * 0.6))

  ---@type eve.ux.picker.ListComposer
  local picker = eve.ux.picker.ListComposer.new({
    name = __module_name__,
    permanent = false,
    title = " Select prompt ",
    height = picker_height,
    width = 40,
    preview_width = 80,
    search_pattern = search_pattern,
    flag_fuzzy = flag_fuzzy,
    flag_regex = flag_regex,
    flag_case_sensitive = flag_case_sensitive,
    render_preview = function(composer, bufnr, _)
      local lnum = composer.result.lnum_current:snapshot()
      local item = composer:retrieve(lnum)
      local prompt = item and itemmap[item.uuid] or nil
      local result = item and result_map[item.uuid] or nil

      if not prompt or not result then
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "(no preview)" })
        return { cursorline = false, number = false, title = "", wrap = true }
      end

      local text_lines = {} ---@type string[]
      for _, rich_line in ipairs(result.lines) do
        local parts = {} ---@type string[]
        for _, chunk in ipairs(rich_line) do
          parts[#parts + 1] = chunk[1]
        end
        text_lines[#text_lines + 1] = table.concat(parts)
      end
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, text_lines)

      vim.api.nvim_buf_clear_namespace(bufnr, eve.var.nsnr.ai_prompt_preview, 0, -1)
      for row, rich_line in ipairs(result.lines) do
        local col = 0
        for _, chunk in ipairs(rich_line) do
          local text = chunk[1]
          local hlname = chunk[2]
          if hlname and #text > 0 then
            vim.hl.range(bufnr, eve.var.nsnr.ai_prompt_preview, hlname, { row - 1, col }, { row - 1, col + #text })
          end
          col = col + #text
        end
      end

      return { cursorline = false, number = true, title = " " .. prompt.name .. " ", wrap = true }
    end,
    on_cancel = function()
      restore_window(winnr)
    end,
    on_confirm = function(composer, item)
      restore_window(winnr)
      composer:close()
      if item ~= nil then
        ---@cast item eve.ux.widget.ai.picker.IItem
        local result = result_map[item.uuid]
        if result then
          on_select(item.data, result)
        end
      end
    end,
    on_disposed = function()
      dispose_picker_flags({ search_pattern, flag_fuzzy, flag_regex, flag_case_sensitive })
    end,
  })

  picker:reset_data({ items = picker_items })
  picker:focus()
end

return M
