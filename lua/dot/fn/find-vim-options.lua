local name = "dot.fn.find_vim_options" ---@type string
local title = "Find Vim Options" ---@type string

---@class dot.fn.find_vim_options.IItemData
---@field public name                   string
---@field public type                   string
---@field public scope                  string
---@field public value                  string|number|boolean
---@field public text                   string

---@class dot.fn.find_vim_options.IItem : dot.module.picker.composer.list.IItem
---@field public data                   dot.fn.find_vim_options.IItemData

local WIDTH_NAME = 25 ---@type integer
local WIDTH_TYPE = 12 ---@type integer
local WIDTH_SCOPE = 11 ---@type integer
local OFFSET_NAME = 0 ---@type integer
local OFFSET_TYPE = OFFSET_NAME + WIDTH_NAME ---@type integer
local OFFSET_SCOPE = OFFSET_TYPE + WIDTH_TYPE ---@type integer
local OFFSET_VALUE = OFFSET_SCOPE + WIDTH_SCOPE ---@type integer

local dirty_data = true ---@type boolean
local o_search_pattern = stl.c.Observable.from_value("") ---@type stl.c.Observable
local o_flag_fuzzy = stl.c.Observable.from_value(true) ---@type stl.c.Observable
local o_flag_regex = stl.c.Observable.from_value(false) ---@type stl.c.Observable
local o_flag_case_sensitive = stl.c.Observable.from_value(false) ---@type stl.c.Observable

---@return dot.module.picker.composer.list.IResetData
local function fetch_data()
  dirty_data = false

  local items = {} ---@type dot.fn.find_vim_options.IItem[]

  for option_name, info in pairs(vim.api.nvim_get_all_options_info()) do
    local ok, value = pcall(vim.api.nvim_get_option_value, option_name, {})
    if not ok or value == nil then
      value = info.default
    end

    local text_name = ark.string.pad_end(info.name, WIDTH_NAME, " ") ---@type string
    local text_type = ark.string.pad_end(info.type, WIDTH_TYPE, " ") ---@type string
    local text_scope = ark.string.pad_end(info.scope, WIDTH_SCOPE, " ") ---@type string
    local text_value = tostring(value):gsub(string.char(9), "<TAB>"):gsub("", "<C-f>"):gsub(" ", "<Space>") ---@type string
    local text = text_name .. text_type .. text_scope .. text_value ---@type string
    local text_for_search = text_name .. string.rep(" ", WIDTH_TYPE + WIDTH_SCOPE) .. text_value ---@type string

    ---@type stl.t.IHighlightInline[]
    local highlights = {
      { coll = OFFSET_NAME, colr = OFFSET_NAME + #info.name, hlname = "m_fvo_name" },
      { coll = OFFSET_TYPE, colr = OFFSET_TYPE + #info.type, hlname = "m_fvo_type" },
      { coll = OFFSET_SCOPE, colr = OFFSET_SCOPE + #info.scope, hlname = "m_fvo_scope" },
      { coll = OFFSET_VALUE, colr = -1, hlname = "m_fvo_value" },
    }

    ---@type dot.fn.find_vim_options.IItemData
    local data = {
      name = option_name,
      scope = info.scope,
      type = info.type,
      value = value,
      text = text,
    }

    ---@type dot.fn.find_vim_options.IItem
    local item = {
      uuid = option_name,
      text = text_for_search,
      text_lower = text_for_search:lower(),
      highlights = highlights,
      data = data,
    }
    table.insert(items, item)
  end

  table.sort(items, function(a, b)
    return a.data.name < b.data.name
  end)

  ---@type dot.module.picker.composer.list.IResetData
  return { items = items }
end

local picker = dot.picker.ListComposer.new({
  name = name,
  permanent = true,
  title = title,
  height = 0.9,
  width = 120,

  search_pattern = o_search_pattern,
  flag_fuzzy = o_flag_fuzzy,
  flag_regex = o_flag_regex,
  flag_case_sensitive = o_flag_case_sensitive,

  render_result = function(_, bufnr, itemmap, matches)
    ---@cast itemmap                    table<string, dot.fn.find_vim_options.IItem>
    local lines = {} ---@type string[]
    local uuids = {} ---@type string[]
    for _, match in ipairs(matches) do
      local item = itemmap[match.uuid] ---@type dot.fn.find_vim_options.IItem
      lines[#lines + 1] = item.data.text
      uuids[#uuids + 1] = item.uuid
    end

    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

    local nsnr_content = ark.var.nsnr.picker_result
    local nsnr_matches = ark.var.nsnr.picker_matches

    for lnum, match in ipairs(matches) do
      local row = lnum - 1 ---@type integer
      local item = itemmap[match.uuid]

      if item and item.highlights then
        for _, hl in ipairs(item.highlights) do
          vim.hl.range(bufnr, nsnr_content, hl.hlname, { row, hl.coll }, { row, hl.colr }, { priority = 10 })
        end
      end

      if match.matches then
        for _, m in ipairs(match.matches) do
          local offset_l, offset_r = m.l, m.r
          if m.l >= WIDTH_NAME then
            offset_l = m.l + (WIDTH_TYPE + WIDTH_SCOPE)
            offset_r = m.r + (WIDTH_TYPE + WIDTH_SCOPE)
          end
          vim.hl.range(bufnr, nsnr_matches, "m_pk_matches", { row, offset_l }, { row, offset_r }, { priority = 30 })
        end
      end
    end

    local data = { uuids = uuids } ---@type dot.module.picker.composer.list.IRenderResultData
    return data
  end,

  on_confirm = function(composer, item)
    if item == nil then
      return
    end

    ---@cast item dot.fn.find_vim_options.IItem
    composer:close()

    dirty_data = false

    local data = item.data ---@type dot.fn.find_vim_options.IItemData
    local esc = vim.fn.mode() == "i" and vim.api.nvim_replace_termcodes("<esc>", true, false, true) or "" ---@type string
    vim.api.nvim_feedkeys(string.format("%s:set %s=%s", esc, data.name, data.value), "m", true)
  end,

  on_refresh = function(composer)
    local data = fetch_data() ---@type dot.module.picker.composer.list.IResetData
    composer:reset_data(data)
  end,
})

---@return nil
local function find_vim_options()
  if dirty_data then
    local data = fetch_data()
    picker:reset_data(data)
  end
  picker:focus()
end

return find_vim_options
