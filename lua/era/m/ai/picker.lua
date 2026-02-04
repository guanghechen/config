---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.ai.picker" ---@type string

local S = era.m.ai

---@class era.m.ai.picker.IItem : era.m.picker.composer.list.IItem
---@field public data                   any

---@class era.m.ai.picker
local M = {}

---@type table<string, string>
M._args_cache = (function()
  local cache = {}
  for _, t in ipairs(stl.prompt.templates) do
    if t.args then
      for name, default in pairs(t.args) do
        cache[name] = default
      end
    end
  end
  return cache
end)()

----------------------------------------------------------------------------------------------------
--- Picker utilities
----------------------------------------------------------------------------------------------------

---@return stl.c.Observable, stl.c.Observable, stl.c.Observable, stl.c.Observable
local function create_picker_flags()
  return stl.c.Observable.from_value(""),
    stl.c.Observable.from_value(true),
    stl.c.Observable.from_value(false),
    stl.c.Observable.from_value(false)
end

---@param flags                         stl.c.Observable[]
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

---@param items                         era.m.picker.composer.list.IItem[]
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

---@class era.m.ai.picker.IAttachItemInfo
---@field public item                   era.m.ai.ISelectItem
---@field public category               era.m.ai.ItemCategory
---@field public agent_label            string
---@field public identifier             string|nil
---@field public pane_cwd               string|nil
---@field public uuid                   string

---@param info                          era.m.ai.picker.IAttachItemInfo
---@return string
local function get_item_hlname(info)
  local category = info.category
  if category == "attached" then
    return "m_ai_attached"
  elseif category == "same_window" then
    return "m_ai_running_same_window"
  elseif category == "agent_session" then
    return "m_ai_running_agent_session"
  elseif category == "new_agent" then
    return "m_ai_new"
  elseif category == "same_session" then
    return "m_ai_running_same_session"
  elseif category == "other_tmux" then
    return "m_ai_running_other_session"
  else
    return "m_ai_new"
  end
end

---@param a                             era.m.ai.picker.IAttachItemInfo
---@param b                             era.m.ai.picker.IAttachItemInfo
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

---@param a                             era.m.ai.picker.IAttachItemInfo
---@param b                             era.m.ai.picker.IAttachItemInfo
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

---@param a                             era.m.ai.picker.IAttachItemInfo
---@param b                             era.m.ai.picker.IAttachItemInfo
---@return boolean
local function compare_by_agent_name(a, b)
  return a.item.agent < b.item.agent
end

---@param items                         era.m.ai.ISelectItem[]
---@return era.m.ai.picker.IItem[], integer
local function build_attach_picker_items(items)
  local current_info = S.tmux.get_current_info()
  local current_session = current_info and current_info.session_name or ""
  local current_window = current_info and current_info.window_name or ""

  local width_agent = 0 ---@type integer
  local width_identifier = 0 ---@type integer

  local attached_infos = {} ---@type era.m.ai.picker.IAttachItemInfo[]
  local same_window_infos = {} ---@type era.m.ai.picker.IAttachItemInfo[]
  local agent_session_infos = {} ---@type era.m.ai.picker.IAttachItemInfo[]
  local new_agent_infos = {} ---@type era.m.ai.picker.IAttachItemInfo[]
  local same_session_infos = {} ---@type era.m.ai.picker.IAttachItemInfo[]
  local other_tmux_infos = {} ---@type era.m.ai.picker.IAttachItemInfo[]

  for _, item in ipairs(items) do
    local agent_label = S.config.agent_labels[item.agent] or item.agent
    local attached = item.source ~= nil and S.state.is_attached(item.source)
    local identifier = item.source and S.action.get_source_identifier(item.source) or nil
    local pane_cwd = item.source and dot.path.shorten(item.source.cwd) or nil

    width_agent = math.max(width_agent, #agent_label)
    if identifier then
      width_identifier = math.max(width_identifier, #identifier)
    end

    local pane = item.source and item.source.tmux_pane
    local category ---@type era.m.ai.ItemCategory

    if attached then
      category = "attached"
    elseif item.type == "new" then
      category = "new_agent"
    elseif pane then
      local same_session = pane.session_name == current_session
      local same_window = same_session and pane.window_name == current_window
      local is_agent_session = S.tmux.is_agent_session(pane.session_name)
      if same_window then
        category = "same_window"
      elseif is_agent_session and not same_session then
        category = "agent_session"
      elseif same_session then
        category = "same_session"
      else
        category = "other_tmux"
      end
    else
      category = "new_agent"
    end

    local uuid = item.source and item.source.id or string.format("new:%s", item.agent)

    ---@type era.m.ai.picker.IAttachItemInfo
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
    elseif category == "agent_session" then
      agent_session_infos[#agent_session_infos + 1] = info
    elseif category == "new_agent" then
      new_agent_infos[#new_agent_infos + 1] = info
    elseif category == "same_session" then
      same_session_infos[#same_session_infos + 1] = info
    else
      other_tmux_infos[#other_tmux_infos + 1] = info
    end
  end

  table.sort(attached_infos, compare_by_session_window_pane)
  table.sort(same_window_infos, compare_by_pane_id)
  table.sort(agent_session_infos, compare_by_session_window_pane)
  table.sort(new_agent_infos, compare_by_agent_name)
  table.sort(same_session_infos, compare_by_session_window_pane)
  table.sort(other_tmux_infos, compare_by_session_window_pane)

  local sorted_infos = {} ---@type era.m.ai.picker.IAttachItemInfo[]
  vim.list_extend(sorted_infos, attached_infos)
  vim.list_extend(sorted_infos, same_window_infos)
  vim.list_extend(sorted_infos, agent_session_infos)
  vim.list_extend(sorted_infos, new_agent_infos)
  vim.list_extend(sorted_infos, same_session_infos)
  vim.list_extend(sorted_infos, other_tmux_infos)

  local picker_items = {} ---@type era.m.ai.picker.IItem[]

  for _, info in ipairs(sorted_infos) do
    local item = info.item

    local icon = info.category == "attached" and stl.icon.status.attached
      or (item.type == "running" and stl.icon.status.detached or " ")
    local text_agent = stl.string.pad_end(info.agent_label, width_agent, " ")
    local text_identifier = info.identifier and ("  " .. stl.string.pad_end(info.identifier, width_identifier, " "))
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

---@param attached                      era.m.ai.IAttachedSource[]
---@return era.m.ai.picker.IItem[], integer
local function build_attached_picker_items(attached)
  local width_agent = 0 ---@type integer
  local width_identifier = 0 ---@type integer

  ---@class era.m.ai.picker.IAttachedItemInfo
  ---@field public source               era.m.ai.IAttachedSource
  ---@field public agent_label          string
  ---@field public identifier           string|nil
  ---@field public pane_cwd             string|nil

  local item_infos = {} ---@type era.m.ai.picker.IAttachedItemInfo[]

  for _, source in ipairs(attached) do
    local agent_label = S.config.agent_labels[source.agent] or source.agent
    local identifier = S.action.get_source_identifier(source)
    local pane_cwd = dot.path.shorten(source.cwd)

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

  local picker_items = {} ---@type era.m.ai.picker.IItem[]

  for _, info in ipairs(item_infos) do
    local source = info.source

    local text_agent = stl.string.pad_end(info.agent_label, width_agent, " ")
    local text_identifier = info.identifier and ("  " .. stl.string.pad_end(info.identifier, width_identifier, " "))
      or ""
    local text_pane_cwd = info.pane_cwd and ("  " .. info.pane_cwd) or ""
    local text = stl.icon.status.attached .. " " .. text_agent .. text_identifier .. text_pane_cwd

    picker_items[#picker_items + 1] = {
      uuid = source.id,
      text = text,
      text_lower = text:lower(),
      highlights = { { coll = 0, colr = #text, hlname = "m_ai_attached" } },
      data = source,
    }
  end

  return picker_items, 2 + width_agent + width_identifier + 50
end

----------------------------------------------------------------------------------------------------
--- Public picker functions
----------------------------------------------------------------------------------------------------

---@class era.m.ai.picker.IShowAttachParams
---@field public on_select              fun(item: era.m.ai.ISelectItem): nil
---@field public on_toggle              ?fun(item: era.m.ai.ISelectItem): nil

---@param params                        era.m.ai.picker.IShowAttachParams
---@return nil
function M.show_attach(params)
  local on_select = params.on_select
  local on_toggle = params.on_toggle

  local items = S.action.collect_items()
  local picker_items, width = build_attach_picker_items(items)
  local winnr = vim.api.nvim_get_current_win()
  local search_pattern, flag_fuzzy, flag_regex, flag_case_sensitive = create_picker_flags()
  local picker_height, picker_width = calc_picker_dimensions(picker_items, width)

  ---@type era.m.picker.ListComposer|nil
  local picker = nil

  ---@return nil
  local function do_toggle()
    if not picker or not on_toggle then
      return
    end
    local lnum = picker.result.lnum_current:snapshot()
    local item = picker:retrieve(lnum)
    if item then
      ---@cast item era.m.ai.picker.IItem
      on_toggle(item.data)
      local new_items = S.action.collect_items()
      local new_picker_items = build_attach_picker_items(new_items)
      picker:reset_data({ items = new_picker_items, uuid_current = item.uuid })
    end
  end

  ---@return nil
  local function do_toggle_tmux()
    if not picker or not on_toggle then
      return
    end
    local lnum = picker.result.lnum_current:snapshot()
    local item = picker:retrieve(lnum)
    if item then
      ---@cast item era.m.ai.picker.IItem
      local select_item = item.data ---@type era.m.ai.ISelectItem
      if select_item.source and select_item.source.type == "tmux" then
        on_toggle(select_item)
        local new_items = S.action.collect_items()
        local new_picker_items = build_attach_picker_items(new_items)
        picker:reset_data({ items = new_picker_items, uuid_current = item.uuid })
      end
    end
  end

  picker = era.m.picker.ListComposer.new({
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
      { modes = { "i", "n", "x" }, key = "<Tab>", callback = do_toggle_tmux, desc = "Toggle attach/detach (tmux only)" },
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
        ---@cast item era.m.ai.picker.IItem
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

---@param attached                      era.m.ai.IAttachedSource[]
---@param on_select                     fun(item: era.m.ai.IAttachedSource): nil
---@return nil
function M.show_detach(attached, on_select)
  local picker_items, width = build_attached_picker_items(attached)
  local winnr = vim.api.nvim_get_current_win()
  local search_pattern, flag_fuzzy, flag_regex, flag_case_sensitive = create_picker_flags()
  local picker_height, picker_width = calc_picker_dimensions(picker_items, width)

  ---@type era.m.picker.ListComposer
  local picker = era.m.picker.ListComposer.new({
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
        ---@cast item era.m.ai.picker.IItem
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

---@param attached                      era.m.ai.IAttachedSource[]
---@param on_select                     fun(items: era.m.ai.IAttachedSource[]): nil
---@return nil
function M.show_send_target(attached, on_select)
  local picker_items, width = build_attached_picker_items(attached)
  local winnr = vim.api.nvim_get_current_win()
  local search_pattern, flag_fuzzy, flag_regex, flag_case_sensitive = create_picker_flags()

  local send_to_all_uuid = "__send_to_all__" ---@type string
  local has_multiple = #attached > 1 ---@type boolean

  if has_multiple then
    local send_to_all_text = stl.icon.status.broadcast .. " send to all (" .. #attached .. " agents)"
    table.insert(picker_items, 1, {
      uuid = send_to_all_uuid,
      text = send_to_all_text,
      text_lower = send_to_all_text:lower(),
      highlights = { { coll = 0, colr = #send_to_all_text, hlname = "m_ai_send_to_all" } },
      data = nil,
    })
  end

  local picker_height, picker_width = calc_picker_dimensions(picker_items, width)

  local selected_set = {} ---@type table<string, boolean>
  local source_map = {} ---@type table<string, era.m.ai.IAttachedSource>

  for _, item in ipairs(picker_items) do
    if item.uuid ~= send_to_all_uuid then
      source_map[item.uuid] = item.data
    end
  end

  ---@type era.m.picker.ListComposer|nil
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

    local results = {} ---@type era.m.ai.IAttachedSource[]
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

  picker = era.m.picker.ListComposer.new({
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

---@param on_select                     fun(sources: era.m.ai.ISource[]): nil
---@return nil
function M.show_submit_to(on_select)
  local items = S.action.collect_items()

  local running_items = {} ---@type era.m.ai.ISelectItem[]
  for _, item in ipairs(items) do
    if item.type == "running" and item.source then
      running_items[#running_items + 1] = item
    end
  end

  if #running_items == 0 then
    stl.reporter.info({
      from = __module_name__,
      group = "ai",
      subject = "show_send_to",
      message = "No running agents found.",
    })
    return
  end

  local picker_items, width = build_attach_picker_items(running_items)
  local winnr = vim.api.nvim_get_current_win()
  local search_pattern, flag_fuzzy, flag_regex, flag_case_sensitive = create_picker_flags()
  local picker_height, picker_width = calc_picker_dimensions(picker_items, width)

  local selected_set = {} ---@type table<string, boolean>
  local source_map = {} ---@type table<string, era.m.ai.ISource>

  for _, picker_item in ipairs(picker_items) do
    ---@cast picker_item era.m.ai.picker.IItem
    local select_item = picker_item.data ---@type era.m.ai.ISelectItem
    if select_item.source then
      source_map[picker_item.uuid] = select_item.source
    end
  end

  ---@type era.m.picker.ListComposer|nil
  local picker = nil

  ---@return nil
  local function toggle_current_selection()
    if not picker then
      return
    end
    local lnum = picker.result.lnum_current:snapshot()
    local item = picker:retrieve(lnum)
    if item then
      selected_set[item.uuid] = not selected_set[item.uuid] or nil
      picker.result:refresh_signs()
    end
  end

  ---@return nil
  local function confirm_selection()
    if not picker then
      return
    end

    local results = {} ---@type era.m.ai.ISource[]
    local has_selection = next(selected_set) ~= nil

    if has_selection then
      for uuid, _ in pairs(selected_set) do
        if source_map[uuid] then
          results[#results + 1] = source_map[uuid]
        end
      end
    else
      local lnum = picker.result.lnum_current:snapshot()
      local picker_item = picker:retrieve(lnum)
      if picker_item and source_map[picker_item.uuid] then
        results[#results + 1] = source_map[picker_item.uuid]
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

  picker = era.m.picker.ListComposer.new({
    name = __module_name__,
    permanent = false,
    title = " Submit to (Tab: toggle, Enter: confirm) ",
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

---@param on_select                     fun(prompt: era.m.ai.IPrompt, result: era.m.ai.IPromptRenderResult): nil
---@return nil
function M.show_prompt(on_select)
  local ctx = S.prompt.get_ctx()

  local picker_items = {} ---@type era.m.ai.picker.IItem[]
  local itemmap = {} ---@type table<string, era.m.ai.IPrompt>
  local result_map = {} ---@type table<string, era.m.ai.IPromptRenderResult>
  local args_tag_map = {} ---@type table<string, string>

  for index, prompt in ipairs(S.prompt.list) do
    local result = prompt.render(ctx)
    if result then
      local uuid = tostring(index)
      itemmap[uuid] = prompt
      result_map[uuid] = result

      -- Build args tag for display (e.g., "#3")
      local args_tag = ""
      if prompt.args then
        local values = {} ---@type string[]
        for name in pairs(prompt.args) do
          values[#values + 1] = M._args_cache[name]
        end
        if #values > 0 then
          table.sort(values)
          args_tag = table.concat(values, " ")
        end
      end
      args_tag_map[uuid] = args_tag

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

  ---@type era.m.picker.ListComposer|nil
  local picker = nil

  ---Rebuild args_tag_map with updated cache values.
  local function rebuild_args_tags()
    for uuid, prompt in pairs(itemmap) do
      if prompt.args then
        local values = {} ---@type string[]
        for name in pairs(prompt.args) do
          values[#values + 1] = M._args_cache[name]
        end
        table.sort(values)
        args_tag_map[uuid] = #values > 0 and table.concat(values, " ") or ""
      end
    end
  end

  ---Edit args for current prompt.
  local function edit_current_args()
    if not picker then
      return
    end
    local lnum = picker.result.lnum_current:snapshot()
    local item = picker:retrieve(lnum)
    if not item then
      return
    end
    local prompt = item.data ---@type era.m.ai.IPrompt
    if not prompt.args or not next(prompt.args) then
      return
    end

    local names = vim.tbl_keys(prompt.args)
    table.sort(names)

    local function show_arg_picker()
      local items = {} ---@type string[]
      for _, name in ipairs(names) do
        local display = name:gsub("^_+", ""):gsub("_+$", "")
        items[#items + 1] = display .. " = " .. M._args_cache[name]
      end

      vim.ui.select(items, { prompt = "Edit arg (Esc to close):" }, function(_, idx)
        if not idx then
          rebuild_args_tags()
          picker:reset_data({ items = picker_items, uuid_current = item.uuid })
          return
        end
        local name = names[idx]
        local display = name:gsub("^_+", ""):gsub("_+$", "")
        vim.ui.input({ prompt = display .. ": ", default = M._args_cache[name] }, function(input)
          if input then
            M._args_cache[name] = input
          end
          rebuild_args_tags()
          picker:reset_data({ items = picker_items, uuid_current = item.uuid })
        end)
      end)
    end

    show_arg_picker()
  end

  local nsnr_args_tag = vim.api.nvim_create_namespace("era.m.ai.picker.args_tag")

  picker = era.m.picker.ListComposer.new({
    name = __module_name__,
    permanent = false,
    title = " Select prompt ",
    height = picker_height,
    width = 40,
    search_pattern = search_pattern,
    flag_fuzzy = flag_fuzzy,
    flag_regex = flag_regex,
    flag_case_sensitive = flag_case_sensitive,
    keymaps_result = {
      { modes = { "n" }, key = "oe", callback = edit_current_args, desc = "Edit args" },
    },
    render_result = function(composer, bufnr, local_itemmap, matches)
      local lines = {} ---@type string[]
      local uuids = {} ---@type string[]

      for _, match in ipairs(matches) do
        local item = local_itemmap[match.uuid] ---@type era.m.picker.composer.list.IItem
        lines[#lines + 1] = item.text
        uuids[#uuids + 1] = item.uuid
      end

      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

      local nsnr_matches = dot.var.nsnr.picker_matches ---@type integer
      vim.api.nvim_buf_clear_namespace(bufnr, nsnr_args_tag, 0, -1)

      for lnum, match in ipairs(matches) do
        local row = lnum - 1 ---@type integer

        if match.matches then
          for _, m in ipairs(match.matches) do
            vim.hl.range(bufnr, nsnr_matches, "m_pk_matches", { row, m.l }, { row, m.r }, { priority = 30 })
          end
        end

        -- Add right-aligned args tag overlay
        local tag = args_tag_map[match.uuid]
        if tag and #tag > 0 then
          vim.api.nvim_buf_set_extmark(bufnr, nsnr_args_tag, row, 0, {
            virt_text = {
              { stl.icon.symbols.sep_left, "m_ai_args_tag_sep" },
              { tag, "m_ai_args_tag" },
              { stl.icon.symbols.sep_right, "m_ai_args_tag_sep" },
            },
            virt_text_pos = "right_align",
            priority = 50,
          })
        end
      end

      return { uuids = uuids }
    end,
    render_preview = function(composer, bufnr, _)
      local lnum = composer.result.lnum_current:snapshot()
      local item = composer:retrieve(lnum)
      local prompt = item and itemmap[item.uuid] or nil
      local result = item and result_map[item.uuid] or nil

      if not prompt or not result then
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "(no preview)" })
        return { cursorline = false, number = false, title = "", wrap = true }
      end

      local text_lines = vim.split(result.text, "\n", { plain = true })
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, text_lines)

      return { cursorline = false, number = true, title = " " .. prompt.name .. " ", wrap = true }
    end,
    on_cancel = function()
      restore_window(winnr)
    end,
    on_confirm = function(composer, item)
      restore_window(winnr)
      composer:close()
      if item == nil then
        return
      end
      ---@cast item era.m.ai.picker.IItem
      local prompt = item.data ---@type era.m.ai.IPrompt
      local result = result_map[item.uuid]
      if not result then
        return
      end

      if not prompt.args or not next(prompt.args) then
        on_select(prompt, result)
        return
      end

      -- Substitute args using cached values
      local text = result.text
      for name in pairs(prompt.args) do
        local pattern = "%${" .. vim.pesc(name) .. "}"
        text = text:gsub(pattern, function()
          return M._args_cache[name]
        end)
      end
      local new_lines = {} ---@type era.m.ai.IText
      for line in vim.gsplit(text, "\n", { plain = true }) do
        new_lines[#new_lines + 1] = { { line, nil } }
      end
      on_select(prompt, { text = text, lines = new_lines })
    end,
    on_disposed = function()
      dispose_picker_flags({ search_pattern, flag_fuzzy, flag_regex, flag_case_sensitive })
    end,
  })

  picker:reset_data({ items = picker_items })
  picker:focus()
end

return M
