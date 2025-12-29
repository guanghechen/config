---@diagnostic disable: invisible
local name = "dot.fn.find_buffers" ---@type string
local title = "Find Buffers" ---@type string

---@class dot.fn.find_buffers.IItem : dot.module.picker.composer.list.IItem
---@field public data                   dot.fn.find_buffers.IItemData

---@class dot.fn.find_buffers.IItemData
---@field public bufnr                  integer
---@field public buftype                string
---@field public filetype               string
---@field public filepath               string
---@field public filename               string
---@field public icon                   string
---@field public icon_hl                string

local scopes = vim.list_slice(dot.context.select.find_buffer_scopes) ---@type dot.e.FindBufferScope[]
local o_scope = dot.context.select.find_buffer_scope ---@type stl.c.Observable
local o_search_pattern = dot.context.select.find_buffer.search_pattern ---@type stl.c.Observable
local o_flag_fuzzy = dot.context.select.find_buffer.flag_fuzzy ---@type stl.c.Observable
local o_flag_regex = dot.context.select.find_buffer.flag_regex ---@type stl.c.Observable
local o_flag_case_sensitive = dot.context.select.find_buffer.flag_case_sensitive ---@type stl.c.Observable

local IGNORED_FILETYPES = {
  stl.filetype.UX_PICKER_FINDER,
  stl.filetype.UX_PICKER_PREVIEW,
  stl.filetype.UX_PICKER_RESULT,
  stl.filetype.UX_SEARCHER_FINDER,
  stl.filetype.UX_SEARCHER_PREVIEW,
  stl.filetype.UX_SEARCHER_RESULT,
  stl.filetype.WINSEP,
}

---@param bufnr                         integer
---@param scope                         dot.e.FindBufferScope
---@param tabnr                         integer
---@return boolean
local function should_show_buffer(bufnr, scope, tabnr)
  if scope == "A" then
    return true
  end

  local buftype = vim.bo[bufnr].buftype ---@type string
  if scope == "T" then
    return buftype == "terminal"
  end

  local filetype = vim.bo[bufnr].filetype ---@type string
  if scope == "F" then
    return dot.tab.has_buf(tabnr, bufnr)
  end

  for _, excluded in ipairs(IGNORED_FILETYPES) do
    if filetype == excluded then
      return false
    end
  end

  return true
end

---@param bufnr                         integer
---@param cwd                           string
---@return dot.fn.find_buffers.IItem
local function create_buffer_item(bufnr, cwd)
  local buftype = vim.bo[bufnr].buftype ---@type string
  local filetype = vim.bo[bufnr].filetype ---@type string
  local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
  local relative_filepath = dot.path.relative(cwd, filepath, "/") ---@type string
  local filename = yoz.path.basename(filepath)
  local icon, icon_hl = stl.fileicon.get_file_icon(filename, filetype)

  ---@type dot.fn.find_buffers.IItemData
  local data = {
    bufnr = bufnr,
    buftype = buftype,
    filetype = filetype,
    filepath = relative_filepath,
    filename = filename,
    icon = icon,
    icon_hl = icon_hl,
  }

  local text = string.format(
    "%-5d %-10s %-15s %s %s",
    bufnr,
    buftype or vim.NIL,
    filetype,
    #filepath > 0 and icon or " ",
    relative_filepath
  )

  ---@type stl.t.IHighlightInline[]
  local highlights = {
    { coll = 0, colr = 5, hlname = "f_buf_nr" },
    { coll = 6, colr = 16, hlname = "f_buf_buftype" },
    { coll = 17, colr = 32, hlname = "f_buf_filetype" },
    { coll = 33, colr = 35, hlname = icon_hl },
    { coll = 35, colr = -1, hlname = "f_buf_filepath" },
  }

  ---@type dot.fn.find_buffers.IItem
  return {
    uuid = tostring(bufnr),
    text = text,
    text_lower = text:lower(),
    highlights = highlights,
    data = data,
  }
end

---@return dot.module.picker.composer.list.IResetData
local function fetch_data()
  local cwd = dot.path.cwd() ---@type string
  local scope = dot.context.select.find_buffer_scope:snapshot() ---@type dot.e.FindBufferScope
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer

  local items = {} ---@type dot.fn.find_buffers.IItem[]
  local bufnrs = vim.api.nvim_list_bufs() ---@type integer[]

  for _, bufnr in ipairs(bufnrs) do
    if should_show_buffer(bufnr, scope, tabnr) then
      items[#items + 1] = create_buffer_item(bufnr, cwd)
    end
  end

  table.sort(items, function(a, b)
    return a.data.bufnr < b.data.bufnr
  end)

  ---@type dot.module.picker.composer.list.IResetData
  return { items = items }
end

local picker ---@type dot.module.picker.ListComposer
picker = dot.picker.ListComposer.new({
  name = name,
  permanent = true,
  title = title,
  height = 0.8,
  width = 120,

  search_pattern = o_search_pattern,
  flag_fuzzy = o_flag_fuzzy,
  flag_regex = o_flag_regex,
  flag_case_sensitive = o_flag_case_sensitive,
  flag_start_index = 0,

  flags_prepend = {
    {
      desc = "find(buffer): toggle scope",
      callback = function()
        local scope = o_scope:snapshot() ---@type dot.e.FindBufferScope
        local idx = stl.table.find_index(scopes, scope) or 1 ---@type integer
        local idx_next = idx == #scopes and 1 or idx + 1 ---@type integer
        local next_scope = scopes[idx_next] ---@type dot.e.FindBufferScope
        dot.context.select.find_buffer_scope:next(next_scope)
        local data = fetch_data()
        picker:reset_data(data)
      end,
      snapshot = function()
        local scope = o_scope:snapshot() ---@type dot.e.FindBufferScope
        return scope, "picker_flag_purple"
      end,
    },
  },
  flags_start_index = 0,

  render_result = function(_, bufnr, itemmap, matches)
    ---@cast itemmap                    table<string, dot.fn.find_buffers.IItem>
    ---
    local lines = {} ---@type string[]
    local uuids = {} ---@type string[]
    for _, match in ipairs(matches) do
      local item = itemmap[match.uuid] ---@type dot.fn.find_buffers.IItem
      lines[#lines + 1] = item.text
      uuids[#uuids + 1] = item.uuid
    end

    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

    local nsnr_content = dot.var.nsnr.picker_result
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
        for _, m in ipairs(match.matches) do
          vim.hl.range(bufnr, nsnr_matches, "m_pk_matches", { row, m.l }, { row, m.r }, { priority = 30 })
        end
      end
    end

    local data = { uuids = uuids } ---@type dot.module.picker.composer.list.IRenderResultData
    return data
  end,

  keymaps_result = {
    {
      modes = { "i", "n", "x" },
      key = "<C-d>",
      desc = "buffer: close",
      callback = function()
        local lnum = picker._composer:get_result_lnum() ---@type integer
        local item = picker:retrieve(lnum) ---@type dot.module.picker.composer.list.IItem|nil
        ---@cast item                   dot.fn.find_buffers.IItem|nil
        if item == nil then
          return
        end

        local bufnr = item.data.bufnr ---@type integer
        if not stl.nvim.buf.is_valid(bufnr) then
          local data = fetch_data()
          picker:reset_data(data)
          return
        end

        if not vim.bo[bufnr].buflisted then
          vim.api.nvim_buf_delete(bufnr, { force = true })
          local data = fetch_data()
          picker:reset_data(data)
          return
        end

        local tabnrs = vim.api.nvim_list_tabpages() ---@type integer[]
        for _, tabnr in ipairs(tabnrs) do
          dot.tab.on_bufs_close(tabnr, { bufnr })
        end

        local bufnrs_unreferenced = dot.tab.retrieve_unreferenced_bufnrs() ---@type integer[]
        if #bufnrs_unreferenced > 0 then
          for _, unreferenced_bufnr in ipairs(bufnrs_unreferenced) do
            vim.api.nvim_buf_delete(unreferenced_bufnr, { force = true })
          end
          local data = fetch_data()
          picker:reset_data(data)
        end
      end,
    },
  },

  on_confirm = function(composer, item)
    if item ~= nil then
      ---@cast item dot.fn.find_buffers.IItem
      composer:close()

      local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
      local winnr_sourcefile = dot.tab.retrieve_winnr_sourcefile(tabnr) or dot.win.pick_sourcefile() ---@type integer|nil
      if winnr_sourcefile ~= nil then
        vim.api.nvim_win_set_buf(winnr_sourcefile, item.data.bufnr)
      end
    end
  end,
  on_refresh = function(composer)
    local data = fetch_data() ---@type dot.module.picker.composer.list.IResetData
    composer:reset_data(data)
  end,
})

stl.fn.observe({ o_scope }, function()
  local scope = o_scope:snapshot() ---@type dot.e.FindBufferScope
  if scope == "A" then
    picker.finder:set_title("find buffers")
  elseif scope == "F" then
    picker.finder:set_title("find buffers (files)")
  elseif scope == "L" then
    picker.finder:set_title("find buffers (except widgets)")
  elseif scope == "T" then
    picker.finder:set_title("find buffers (terms)")
  end
end, false)

---@param scope                         dot.e.FindBufferScope|nil
---@return nil
local function find_buffers(scope)
  if scope ~= nil then
    o_scope:next(scope)
  end
  o_search_pattern:next("")
  local data = fetch_data()
  picker:reset_data(data)
  picker:focus()
end

return find_buffers
