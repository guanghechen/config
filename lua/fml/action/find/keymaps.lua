---@diagnostic disable: invisible
local name = "fml.action.find.keymaps" ---@type string
local title = "Find Keymaps" ---@type string

---@class fml.action.find.keymaps.IItemData
---@field public mode                   string
---@field public lhs                    string
---@field public rhs                    string
---@field public desc                   string
---@field public source                 string

---@class fml.action.find.keymaps.IItem : ux.picker.composer.list.IItem
---@field public data                   fml.action.find.keymaps.IItemData

local WIDTH_LHS = 28 ---@type integer
local WIDTH_MODE = 4 ---@type integer
local OFFSET_LHS = 0 ---@type integer
local OFFSET_MODE = OFFSET_LHS + WIDTH_LHS ---@type integer
local OFFSET_DESC = OFFSET_MODE + WIDTH_MODE ---@type integer

local dirty_data = true ---@type boolean
local o_search_pattern = eve.context.select.find_keymap.search_pattern
local o_flag_fuzzy = eve.context.select.find_keymap.flag_fuzzy
local o_flag_regex = eve.context.select.find_keymap.flag_regex
local o_flag_case_sensitive = eve.context.select.find_keymap.flag_case_sensitive

---@param lhs                           string
---@return string
local function normalize_lhs(lhs)
  if string.sub(lhs, 1, 1) == " " then
    return "<leader>" .. lhs
  end
  return lhs
end

---@param lhs                           string
---@return integer, string
local function get_sort_key(lhs)
  if lhs:match("^<C%-a>") then
    local suffix = lhs:sub(6)
    return 1, suffix .. "\003"
  elseif lhs:match("^<C%-") then
    local suffix = lhs:sub(4)
    return 1, suffix .. "\001"
  elseif lhs:match("^<M%-") then
    local suffix = lhs:sub(4)
    return 1, suffix .. "\002"
  elseif lhs:match("^<D%-") then
    local suffix = lhs:sub(4)
    return 1, suffix .. "\002"
  elseif lhs:match("^<leader>") then
    return 2, lhs:sub(9)
  else
    return 3, lhs
  end
end

---@return ux.picker.composer.list.IResetData
local function fetch_data()
  dirty_data = false

  local items = {} ---@type fml.action.find.keymaps.IItem[]
  local seen = {} ---@type table<string, boolean>
  local modes = { "n", "i", "x", "t", "o", "s" }

  for _, mode in ipairs(modes) do
    local keymaps = vim.api.nvim_get_keymap(mode)
    for _, km in ipairs(keymaps) do
      local lhs = normalize_lhs(km.lhs or "")
      local key = mode .. ":" .. lhs
      if not seen[key] and lhs ~= "" then
        seen[key] = true

        local desc = km.desc or ""
        local rhs = km.rhs or (km.callback and "[callback]" or "")

        local text_lhs = ark.string.pad_end(lhs, WIDTH_LHS, " ")
        local text_mode = ark.string.pad_end(mode, WIDTH_MODE, " ")
        local text_desc = desc
        local text = text_lhs .. text_mode .. text_desc

        ---@type ark.t.IHighlightInline[]
        local highlights = {
          { coll = OFFSET_LHS, colr = OFFSET_LHS + #lhs, hlname = "f_us_km_lhs" },
          { coll = OFFSET_MODE, colr = OFFSET_MODE + #mode, hlname = "f_us_km_mode" },
          { coll = OFFSET_DESC, colr = -1, hlname = "f_us_km_desc" },
        }

        ---@type fml.action.find.keymaps.IItemData
        local data = {
          mode = mode,
          lhs = lhs,
          rhs = rhs,
          desc = desc,
          source = km.buffer and "buffer" or "global",
        }

        ---@type fml.action.find.keymaps.IItem
        local item = {
          uuid = key,
          text = text,
          text_lower = text:lower(),
          highlights = highlights,
          data = data,
        }
        table.insert(items, item)
      end
    end

    local buf_keymaps = vim.api.nvim_buf_get_keymap(0, mode)
    for _, km in ipairs(buf_keymaps) do
      local lhs = normalize_lhs(km.lhs or "")
      local key = mode .. ":buf:" .. lhs
      if not seen[key] and lhs ~= "" then
        seen[key] = true

        local desc = km.desc or ""
        local rhs = km.rhs or (km.callback and "[callback]" or "")

        local text_lhs = ark.string.pad_end(lhs, WIDTH_LHS, " ")
        local text_mode = ark.string.pad_end(mode, WIDTH_MODE, " ")
        local text_desc = desc
        local text = text_lhs .. text_mode .. text_desc

        ---@type ark.t.IHighlightInline[]
        local highlights = {
          { coll = OFFSET_LHS, colr = OFFSET_LHS + #lhs, hlname = "f_us_km_lhs" },
          { coll = OFFSET_MODE, colr = OFFSET_MODE + #mode, hlname = "f_us_km_mode" },
          { coll = OFFSET_DESC, colr = -1, hlname = "f_us_km_desc" },
        }

        ---@type fml.action.find.keymaps.IItemData
        local data = {
          mode = mode,
          lhs = lhs,
          rhs = rhs,
          desc = desc,
          source = "buffer",
        }

        ---@type fml.action.find.keymaps.IItem
        local item = {
          uuid = key,
          text = text,
          text_lower = text:lower(),
          highlights = highlights,
          data = data,
        }
        table.insert(items, item)
      end
    end
  end

  table.sort(items, function(a, b)
    local order_a, key_a = get_sort_key(a.data.lhs)
    local order_b, key_b = get_sort_key(b.data.lhs)
    if order_a ~= order_b then
      return order_a < order_b
    end
    if key_a ~= key_b then
      return key_a < key_b
    end
    return a.data.mode < b.data.mode
  end)

  ---@type ux.picker.composer.list.IResetData
  return { items = items }
end

local picker = ux.picker.ListComposer.new({
  name = name,
  permanent = true,
  title = title,
  height = 0.9,
  width = 0.9,

  search_pattern = o_search_pattern,
  flag_fuzzy = o_flag_fuzzy,
  flag_regex = o_flag_regex,
  flag_case_sensitive = o_flag_case_sensitive,

  render_result = function(composer, bufnr, itemmap, matches)
    ---@cast itemmap                    table<string, fml.action.find.keymaps.IItem>
    local lines = {} ---@type string[]
    local uuids = {} ---@type string[]
    for _, match in ipairs(matches) do
      local item = itemmap[match.uuid] ---@type fml.action.find.keymaps.IItem
      lines[#lines + 1] = item.text
      uuids[#uuids + 1] = item.uuid
    end

    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    composer._retriever:attach(bufnr, uuids)

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
          vim.hl.range(bufnr, nsnr_matches, "f_pk_matches", { row, m.l }, { row, m.r }, { priority = 30 })
        end
      end
    end

    local data = { uuids = uuids } ---@type ux.picker.composer.list.IRenderResultData
    return data
  end,

  ---@diagnostic disable-next-line: unused-local
  render_preview = function(composer, bufnr, force)
    local lnum_current = composer.result.lnum_current:snapshot() ---@type integer

    if lnum_current < 1 then
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "No keymap selected" })

      ---@type ux.picker.preview.IDrawResult
      local result = {
        cursorline = false,
        number = false,
        title = "Keymap Details",
        wrap = true,
      }
      return result
    end

    local item = composer:retrieve(lnum_current) ---@type ux.picker.composer.list.IItem|nil
    ---@cast item fml.action.find.keymaps.IItem|nil

    if item == nil then
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "No keymap selected" })

      ---@type ux.picker.preview.IDrawResult
      local result = {
        cursorline = false,
        number = false,
        title = "Keymap Details",
        wrap = true,
      }
      return result
    end

    local data = item.data
    local lines = {
      "Key:         " .. data.lhs,
      "Mode:        " .. data.mode,
      "Description: " .. data.desc,
      "Source:      " .. data.source,
      "",
      "RHS:",
      data.rhs,
    }

    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

    local nsnr_content = dot.var.nsnr.picker_preview
    local LABEL_WIDTH = 13
    vim.hl.range(bufnr, nsnr_content, "f_us_km_label", { 0, 0 }, { 0, LABEL_WIDTH }, { priority = 10 })
    vim.hl.range(bufnr, nsnr_content, "f_us_km_lhs", { 0, LABEL_WIDTH }, { 0, LABEL_WIDTH + #data.lhs }, { priority = 10 })
    vim.hl.range(bufnr, nsnr_content, "f_us_km_label", { 1, 0 }, { 1, LABEL_WIDTH }, { priority = 10 })
    vim.hl.range(bufnr, nsnr_content, "f_us_km_mode", { 1, LABEL_WIDTH }, { 1, LABEL_WIDTH + #data.mode }, { priority = 10 })
    vim.hl.range(bufnr, nsnr_content, "f_us_km_label", { 2, 0 }, { 2, LABEL_WIDTH }, { priority = 10 })
    vim.hl.range(bufnr, nsnr_content, "f_us_km_desc", { 2, LABEL_WIDTH }, { 2, LABEL_WIDTH + #data.desc }, { priority = 10 })
    vim.hl.range(bufnr, nsnr_content, "f_us_km_label", { 3, 0 }, { 3, LABEL_WIDTH }, { priority = 10 })
    vim.hl.range(bufnr, nsnr_content, "f_us_km_source", { 3, LABEL_WIDTH }, { 3, LABEL_WIDTH + #data.source }, { priority = 10 })
    vim.hl.range(bufnr, nsnr_content, "f_us_km_label", { 5, 0 }, { 5, 4 }, { priority = 10 })
    vim.hl.range(bufnr, nsnr_content, "f_us_km_rhs", { 6, 0 }, { 6, #data.rhs }, { priority = 10 })

    ---@type ux.picker.preview.IDrawResult
    local result = {
      cursorline = false,
      number = false,
      title = "Keymap Details",
      wrap = true,
    }
    return result
  end,

  on_confirm = function(composer, item)
    if item == nil then
      return
    end

    ---@cast item fml.action.find.keymaps.IItem
    composer:close()

    local data = item.data
    if data.rhs and data.rhs ~= "" and data.rhs ~= "[callback]" then
      vim.fn.setreg("+", data.lhs)
      ark.reporter.info({
        from = name,
        subject = "Keymap copied",
        message = string.format("Copied '%s' to clipboard", data.lhs),
      })
    end
  end,

  on_refresh = function(composer)
    dirty_data = true
    local data = fetch_data() ---@type ux.picker.composer.list.IResetData
    composer:reset_data(data)
  end,
})

---@class fml.action.find
local M = {}

---@return nil
function M.find_keymaps()
  if dirty_data then
    local data = fetch_data()
    picker:reset_data(data)
  end
  picker:focus()
end

return M
