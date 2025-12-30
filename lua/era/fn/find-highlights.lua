---@diagnostic disable: invisible
local name = "era.fn.find_highlights" ---@type string
local title = "Find Highlights" ---@type string

---@class era.fn.find_highlights.IItem : era.m.picker.composer.list.IItem
---@field public data                   era.fn.find_highlights.IItemData

---@class era.fn.find_highlights.IItemData
---@field public lnum                   integer
---@field public hlid                   integer

local _hlnames = nil ---@type string[]?
local _hlgroups = nil ---@type table<string, vim.api.keyset.get_hl_info>?
local _last_preview_bufnr = -1 ---@type integer

---@return era.m.picker.composer.list.IResetData
local function fetch_data()
  local hlgroups = vim.api.nvim_get_hl(0, { create = false }) ---@type table<string, vim.api.keyset.get_hl_info>
  local hlnames = {} ---@type string[]
  for hlname in pairs(hlgroups) do
    table.insert(hlnames, hlname)
  end
  table.sort(hlnames)

  _hlnames = hlnames
  _hlgroups = hlgroups

  local items = {} ---@type era.fn.find_highlights.IItem[]
  for lnum, hlname in ipairs(hlnames) do
    local hlid_str = stl.string.pad_end(tostring(vim.fn.hlID(hlname)), 5, " ")
    local text = string.format("%s xxx   %s", hlid_str, hlname) ---@type string
    local highlights = { { coll = 6, colr = 9, hlname = hlname } } ---@type stl.t.IHighlightInline[]

    ---@type era.fn.find_highlights.IItemData
    local data = {
      lnum = lnum,
      hlid = vim.fn.hlID(hlname),
    }

    ---@type era.fn.find_highlights.IItem
    local item = {
      uuid = hlname,
      text = text,
      text_lower = text:lower(),
      highlights = highlights,
      data = data,
    }
    items[#items + 1] = item
  end

  ---@type era.m.picker.composer.list.IResetData
  return { items = items }
end

local search_pattern = stl.c.Observable.from_value("") ---@type stl.c.Observable
local flag_fuzzy = stl.c.Observable.from_value(true) ---@type stl.c.Observable
local flag_regex = stl.c.Observable.from_value(false) ---@type stl.c.Observable
local flag_case_sensitive = stl.c.Observable.from_value(false) ---@type stl.c.Observable

---@type era.m.picker.ListComposer
local picker = era.m.picker.ListComposer.new({
  name = name,
  permanent = true,
  title = title,
  height = 0.9,
  width = 0.9,

  search_pattern = search_pattern,
  flag_fuzzy = flag_fuzzy,
  flag_regex = flag_regex,
  flag_case_sensitive = flag_case_sensitive,

  render_result = function(_, bufnr, itemmap, matches)
    ---@cast itemmap                         table<string, era.fn.find_highlights.IItem>

    local lines = {} ---@type string[]
    local uuids = {} ---@type string[]
    for _, match in ipairs(matches) do
      local item = itemmap[match.uuid] ---@type era.fn.find_highlights.IItem
      lines[#lines + 1] = item.text
      uuids[#uuids + 1] = item.uuid
    end

    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

    local nsnr_content = dot.var.nsnr.picker_result ---@type integer
    local nsnr_matches = dot.var.nsnr.picker_matches

    for lnum, match in ipairs(matches) do
      local row = lnum - 1 ---@type integer
      local item = itemmap[match.uuid]

      if item and item.highlights then
        for _, hl in ipairs(item.highlights) do
          vim.hl.range(bufnr, nsnr_content, hl.hlname, { row, hl.coll }, { row, hl.colr }, { priority = 10 })
        end
      end

      if match.matches then
        local hlname_start_offset = 12 ---@type integer
        for _, m in ipairs(match.matches) do
          if m.l >= hlname_start_offset then
            vim.hl.range(bufnr, nsnr_matches, "m_pk_matches", { row, m.l }, { row, m.r }, { priority = 30 })
          end
        end
      end
    end

    local data = { uuids = uuids } ---@type era.m.picker.composer.list.IRenderResultData
    return data
  end,
  render_preview = function(composer, bufnr, force)
    local lnum_current = composer.result.lnum_current:snapshot() ---@type integer

    if lnum_current < 1 then
      -- Render empty buffer
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "No highlight selected" })

      ---@type era.m.picker.preview.IDrawResult
      local result = {
        cursorline = false,
        number = true,
        title = "No valid lnum retrieved",
        wrap = false,
      }
      return result
    end

    if force or _last_preview_bufnr ~= bufnr then
      local hlnames = _hlnames or {} ---@type string[]
      local hlgroups = _hlgroups or {} ---@type table<string, vim.api.keyset.get_hl_info>

      local lines = {} ---@type string[]
      local nsnr_content = dot.var.nsnr.picker_preview ---@type integer

      local max_hlname_width = 0 ---@type integer
      for _, hlname in ipairs(hlnames) do
        max_hlname_width = math.max(max_hlname_width, vim.api.nvim_strwidth(hlname))
      end

      for _, hlname in ipairs(hlnames) do
        local line = "xxx   " .. stl.string.pad_end(hlname, max_hlname_width, " ") ---@type string
        local hlgroup = hlgroups[hlname] or {} ---@type vim.api.keyset.get_hl_info
        if hlgroup.fg ~= nil then
          local color_name = stl.color.int2hex(hlgroup.fg) ---@type string
          line = line .. " fg=" .. color_name
        end
        if hlgroup.bg ~= nil then
          local color_name = stl.color.int2hex(hlgroup.bg) ---@type string
          line = line .. " bg=" .. color_name
        end
        if hlgroup.link ~= nil then
          line = line .. " link=" .. hlgroup.link
        end
        if hlgroup.cterm ~= nil then
          local flags = {} ---@type string[]
          for flag in pairs(hlgroup.cterm) do
            table.insert(flags, flag)
          end
          line = line .. " cterm=" .. table.concat(flags, ",")
        end

        for key, val in pairs(hlgroup) do
          if key ~= "fg" and key ~= "bg" and key ~= "link" and key ~= "cterm" then
            if type(val) ~= "string" then
              val = vim.inspect(val)
            end
            line = line .. " " .. key .. "=" .. val
          end
        end
        table.insert(lines, line)
      end

      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
      for lnum, hlname in ipairs(hlnames) do
        local row = lnum - 1
        vim.hl.range(bufnr, nsnr_content, hlname, { row, 0 }, { row, 3 }, { priority = 10 })
      end

      _last_preview_bufnr = bufnr
    end

    local item = composer:retrieve(lnum_current) ---@type era.m.picker.composer.list.IItem|nil
    ---@cast item                       era.fn.find_highlights.IItem|nil

    local lnum_target = item and item.data.lnum or lnum_current ---@type integer

    ---@type era.m.picker.preview.IDrawResult
    local result = {
      cursorline = true,
      number = true,
      title = "Highlights Preview",
      wrap = false,
      whitespaces = false,
      lnum = lnum_target,
      col = 0,
    }
    return result
  end,

  on_confirm = function(composer, item)
    if item ~= nil then
      ---@cast item era.fn.find_highlights.IItem
      composer:close()
      stl.nvim.fn.copy(item.uuid)
    end
  end,
  on_refresh = function(composer)
    local data = fetch_data() ---@type era.m.picker.composer.list.IResetData
    composer:reset_data(data)
  end,
})

---@return nil
local function find_highlights()
  if _hlnames == nil or _hlgroups == nil then
    local data = fetch_data()
    picker:reset_data(data)
  end
  picker:focus()
end

return find_highlights
