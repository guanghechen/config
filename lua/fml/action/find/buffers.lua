---@diagnostic disable: invisible
local name = "fml.action.find.buffers" ---@type string
local title = "Find Buffers" ---@type string

---@class fml.action.find.buffers.IItem : eve.ux.picker.composer.list.IItem
---@field public data                   fml.action.find.buffers.IItemData

---@class fml.action.find.buffers.IItemData
---@field public bufnr                  integer
---@field public buftype                string
---@field public filetype               string
---@field public filepath               string
---@field public filename               string
---@field public icon                   string
---@field public icon_hl                string

local scopes = vim.list_slice(eve.context.select.find_buffer_scopes) ---@type std.e.FindBufferScope[]
local o_scope = eve.context.select.find_buffer_scope ---@type std.collection.IObservable
local o_finder_input = eve.context.select.find_buffer.input ---@type std.collection.IObservable
local o_flag_fuzzy = eve.context.select.find_buffer.flag_fuzzy ---@type std.collection.IObservable
local o_flag_regex = eve.context.select.find_buffer.flag_regex ---@type std.collection.IObservable
local o_flag_sensitive = eve.context.select.find_buffer.flag_case_sensitive ---@type std.collection.IObservable

local IGNORED_FILETYPES = {
  eve.filetype.SEARCH_INPUT,
  eve.filetype.SEARCH_MAIN,
  eve.filetype.SEARCH_PREVIEW,
  eve.filetype.UX_PICKER_FINDER,
  eve.filetype.UX_PICKER_PREVIEW,
  eve.filetype.UX_PICKER_RESULT,
  eve.filetype.WINSEP,
}

---@param bufnr                         integer
---@param scope                         std.e.FindBufferScope
---@param tabnr                         integer
---@return boolean
local function should_show_buffer(bufnr, scope, tabnr)
  if scope == "A" then
    return true
  end

  local filetype = vim.bo[bufnr].filetype ---@type string

  if scope == "T" then
    return filetype == eve.filetype.TERM
  end

  if scope == "F" then
    return eve.tab.has_buf(tabnr, bufnr)
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
---@return fml.action.find.buffers.IItem
local function create_buffer_item(bufnr, cwd)
  local buftype = vim.bo[bufnr].buftype ---@type string
  local filetype = vim.bo[bufnr].filetype ---@type string
  local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
  local relative_filepath = std.path.relative(cwd, filepath, true) ---@type string
  local filename = std.path.basename(filepath)
  local icon, icon_hl = std.fileicon.get_file_icon(filename, filetype)

  ---@type fml.action.find.buffers.IItemData
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

  ---@type std.t.IHighlightInline[]
  local highlights = {
    { coll = 0, colr = 5, hlname = "f_buf_nr" },
    { coll = 6, colr = 16, hlname = "f_buf_buftype" },
    { coll = 17, colr = 32, hlname = "f_buf_filetype" },
    { coll = 33, colr = 35, hlname = icon_hl },
    { coll = 35, colr = -1, hlname = "f_buf_filepath" },
  }

  ---@type fml.action.find.buffers.IItem
  return {
    uuid = tostring(bufnr),
    text = text,
    text_lower = text:lower(),
    highlights = highlights,
    data = data,
  }
end

---@return eve.ux.picker.composer.list.IResetData
local function fetch_data()
  local cwd = std.path.cwd() ---@type string
  local scope = eve.context.select.find_buffer_scope:snapshot() ---@type std.e.FindBufferScope
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer

  local items = {} ---@type fml.action.find.buffers.IItem[]
  local bufnrs = vim.api.nvim_list_bufs() ---@type integer[]

  for _, bufnr in ipairs(bufnrs) do
    if should_show_buffer(bufnr, scope, tabnr) then
      items[#items + 1] = create_buffer_item(bufnr, cwd)
    end
  end

  table.sort(items, function(a, b)
    return a.data.bufnr < b.data.bufnr
  end)

  ---@type eve.ux.picker.composer.list.IResetData
  return { items = items }
end

local picker ---@type eve.ux.picker.ListComposer
picker = eve.ux.picker.ListComposer.new({
  name = name,
  permanent = true,
  title = title,
  height = 0.8,
  width = 120,

  finder_input = o_finder_input,
  flag_fuzzy = o_flag_fuzzy,
  flag_regex = o_flag_regex,
  flag_sensitive = o_flag_sensitive,
  flag_start_index = 0,

  flags_prepend = {
    {
      desc = "find(buffer): toggle scope",
      callback = function()
        local scope = o_scope:snapshot() ---@type std.e.FindBufferScope
        local idx = std.table.find_index(scopes, scope) or 1 ---@type integer
        local idx_next = idx == #scopes and 1 or idx + 1 ---@type integer
        local next_scope = scopes[idx_next] ---@type std.e.FindBufferScope
        eve.context.select.find_buffer_scope:next(next_scope)
        local data = fetch_data()
        picker:reset_data(data)
      end,
      snapshot = function()
        local scope = o_scope:snapshot() ---@type std.e.FindBufferScope
        return scope, "picker_flag_purple"
      end,
    },
  },
  flags_start_index = 0,

  result_render = function(composer, bufnr, itemmap, matches)
    ---@cast itemmap                    table<string, fml.action.find.buffers.IItem>
    ---
    local lines = {} ---@type string[]
    local uuids = {} ---@type string[]
    for _, match in ipairs(matches) do
      local item = itemmap[match.uuid] ---@type fml.action.find.buffers.IItem
      lines[#lines + 1] = item.text
      uuids[#uuids + 1] = item.uuid
    end

    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    composer._retriever:attach(bufnr, uuids)

    local nsnr_content = eve.var.nsnr.picker_result
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
        for _, m in ipairs(match.matches) do
          vim.hl.range(bufnr, nsnr_matches, "f_pk_matches", { row, m.l }, { row, m.r }, { priority = 30 })
        end
      end
    end

    local data = { uuids = uuids } ---@type eve.ux.picker.composer.list.IResultRenderData
    return data
  end,

  keymaps_result = {
    {
      modes = { "i", "n", "v" },
      key = "<C-d>",
      desc = "buffer: close",
      callback = function()
        local lnum = picker._composer:get_result_lnum() ---@type integer
        local uuid = picker._retriever:retrieve_uuid(lnum) ---@type string|nil
        local item = uuid and picker._itemmap[uuid] or nil ---@type eve.ux.picker.composer.list.IItem|nil
        ---@cast item                   fml.action.find.buffers.IItem|nil
        if item == nil then
          return
        end

        local bufnr = item.data.bufnr ---@type integer
        if not eve.buf.is_valid(bufnr) then
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
          eve.tab.on_bufs_close(tabnr, { bufnr })
        end

        local bufnrs_unreferenced = eve.tab.retrieve_unreferenced_bufnrs() ---@type integer[]
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
      ---@cast item fml.action.find.buffers.IItem
      composer:close()

      local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
      local winnr_sourcefile = eve.tab.retrieve_winnr_sourcefile(tabnr) or eve.win.pick_sourcefile() ---@type integer|nil
      if winnr_sourcefile ~= nil then
        vim.api.nvim_win_set_buf(winnr_sourcefile, item.data.bufnr)
      end
    end
  end,
  on_refresh = function(composer)
    local data = fetch_data() ---@type eve.ux.picker.composer.list.IResetData
    composer:reset_data(data)
  end,
})

std.fn.observe({ o_scope }, function()
  local scope = o_scope:snapshot() ---@type std.e.FindBufferScope
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

---@class fml.action.find
local M = {}

---@return nil
function M.find_bufs()
  o_finder_input:next("")
  local data = fetch_data()
  picker:reset_data(data)
  picker:focus()
end

---@return nil
function M.find_bufs_file()
  o_scope:next("F")
  o_finder_input:next("")
  local data = fetch_data()
  picker:reset_data(data)
  picker:focus()
end

---@return nil
function M.find_bufs_term()
  o_scope:next("T")
  o_finder_input:next("")
  local data = fetch_data()
  picker:reset_data(data)
  picker:focus()
end

return M
