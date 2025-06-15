---@diagnostic disable: invisible
local __module_name__ = "fml.action.find.highlights" ---@type string

---@class fml.action.find.highlights.IItem : eve.ux.picker.composer.list.IItem
---@field public data                        fml.action.find.highlights.IItemData

---@class fml.action.find.highlights.IItemData
---@field public lnum                        integer
---@field public hlid                        integer

local _hlnames = nil ---@type string[]?
local _hlgroups = nil ---@type table<string, vim.api.keyset.get_hl_info>?
local _last_preview_bufnr = -1 ---@type integer

---@return eve.ux.picker.composer.list.IResetData
local function fetch_data()
  local hlgroups = vim.api.nvim_get_hl(0, { create = false }) ---@type table<string, vim.api.keyset.get_hl_info>
  local hlnames = {} ---@type string[]
  for hlname in pairs(hlgroups) do
    table.insert(hlnames, hlname)
  end
  table.sort(hlnames)

  _hlnames = hlnames
  _hlgroups = hlgroups

  local items = {} ---@type fml.action.find.highlights.IItem[]
  for lnum, hlname in ipairs(hlnames) do
    local hlid_str = std.string.pad_end(tostring(vim.fn.hlID(hlname)), 5, " ")
    local text = string.format("%s xxx   %s", hlid_str, hlname) ---@type string
    local highlights = { { coll = 6, colr = 9, hlname = hlname } } ---@type std.t.IHighlightInline[]

    ---@type fml.action.find.highlights.IItemData
    local data = {
      lnum = lnum,
      hlid = vim.fn.hlID(hlname),
    }

    ---@type fml.action.find.highlights.IItem
    local item = {
      uuid = hlname,
      text = text,
      text_lower = text:lower(),
      highlights = highlights,
      data = data,
    }
    items[#items + 1] = item
  end

  ---@type eve.ux.picker.composer.list.IResetData
  return { items = items }
end

local finder_input = std.Observable.from_value("") ---@type std.collection.IObservable
local flag_fuzzy = std.Observable.from_value(true) ---@type std.collection.IObservable
local flag_regex = std.Observable.from_value(false) ---@type std.collection.IObservable
local flag_sensitive = std.Observable.from_value(false) ---@type std.collection.IObservable

---@type eve.ux.picker.ListComposer
local picker = eve.ux.picker.ListComposer.new({
  name = __module_name__,
  permanent = true,
  title = "Find Highlights",
  height = 25,
  width = 80,

  finder_input = finder_input,
  flag_fuzzy = flag_fuzzy,
  flag_regex = flag_regex,
  flag_sensitive = flag_sensitive,

  result_render = function(composer, bufnr, itemmap, matches)
    ---@cast itemmap                         table<string, fml.action.find.highlights.IItem>

    local lines = {} ---@type string[]
    local uuids = {} ---@type string[]
    for _, match in ipairs(matches) do
      local item = itemmap[match.uuid] ---@type fml.action.find.highlights.IItem
      lines[#lines + 1] = item.text
      uuids[#uuids + 1] = item.uuid
    end

    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    composer._retriever:attach(bufnr, uuids)

    local nsnr_content = eve.var.nsnr.picker_result ---@type integer
    local nsnr_matches = eve.var.nsnr.picker_matches

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
            vim.hl.range(bufnr, nsnr_matches, "f_pk_matches", { row, m.l }, { row, m.r }, { priority = 30 })
          end
        end
      end
    end

    local data = { uuids = uuids } ---@type eve.ux.picker.composer.list.IResultRenderData
    return data
  end,
  preview_render = function(composer, bufnr, force)
    local lnum_current = composer.result.lnum_current:snapshot() ---@type integer

    if lnum_current < 1 then
      -- Render empty buffer
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "No highlight selected" })

      ---@type eve.ux.picker.preview.IDrawResult
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
      local nsnr_content = eve.var.nsnr.picker_preview ---@type integer

      local max_hlname_width = 0 ---@type integer
      for _, hlname in ipairs(hlnames) do
        max_hlname_width = math.max(max_hlname_width, vim.api.nvim_strwidth(hlname))
      end

      for _, hlname in ipairs(hlnames) do
        local line = "xxx   " .. std.string.pad_end(hlname, max_hlname_width, " ") ---@type string
        local hlgroup = hlgroups[hlname] or {} ---@type vim.api.keyset.get_hl_info
        if hlgroup.fg ~= nil then
          local color_name = std.color.int2hex(hlgroup.fg) ---@type string
          line = line .. " fg=" .. color_name
        end
        if hlgroup.bg ~= nil then
          local color_name = std.color.int2hex(hlgroup.bg) ---@type string
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

    local item = composer:retrieve(lnum_current) ---@type eve.ux.picker.composer.list.IItem|nil
    ---@cast item                       fml.action.find.highlights.IItem|nil

    local lnum_target = item and item.data.lnum or lnum_current ---@type integer

    ---@type eve.ux.picker.preview.IDrawResult
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
      ---@cast item fml.action.find.highlights.IItem
      composer:close()
      vim.fn.setreg("+", item.uuid)
    end
  end,
  on_refresh = function(composer)
    local data = fetch_data() ---@type eve.ux.picker.composer.list.IResetData
    composer:reset_data(data)
  end,
})

---@class fml.action.find
local M = {}

---@return nil
function M.find_highlights()
  if _hlnames == nil or _hlgroups == nil then
    local data = fetch_data()
    picker:reset_data(data)
  end
  picker:focus()
end

return M
