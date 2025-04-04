---@class eve.ux.fn.select_encoding.IItem : eve.ux.select.IItem
---@field public data                   { encoding: string }

---@class eve.ux.fn.select_encoding.IParams
---@field public present                string|nil
---@field public title                  string|nil
---@field public on_select              fun(encoding: string|nil): nil

---@class eve.ux.fn.select_encoding.fileencodings
local fileencodings = {
  { title = "UTF-8", encoding = "utf8" },
  { title = "UTF-16 LE", encoding = "utf16le" },
  { title = "UTF-16 BE", encoding = "utf16be" },
  { title = "Western (Windows 1252)", encoding = "windows1252" },
  { title = "Western (ISO 8859-1)", encoding = "iso88591" },
  { title = "Western (ISO 8859-3)", encoding = "iso88593" },
  { title = "Western (ISO 8859-15)", encoding = "iso885915" },
  { title = "Western (Mac Roman)", encoding = "macroman" },
  { title = "DOS (CP 437)", encoding = "cp437" },
  { title = "Arabic (Windows 1256)", encoding = "windows1256" },
  { title = "Arabic (ISO 8859-6)", encoding = "iso88596" },
  { title = "Baltic (Windows 1257)", encoding = "windows1257" },
  { title = "Baltic (ISO 8859-4)", encoding = "iso88594" },
  { title = "Celtic (ISO 8859-14)", encoding = "iso885914" },
  { title = "Central European (Windows 1250)", encoding = "windows1250" },
  { title = "Central European (ISO 8859-2)", encoding = "iso88592" },
  { title = "Central European (CP 852)", encoding = "cp852" },
  { title = "Cyrillic (Windows 1251)", encoding = "windows1251" },
  { title = "Cyrillic (CP 866)", encoding = "cp866" },
  { title = "Cyrillic (CP 1125)", encoding = "cp1125" },
  { title = "Cyrillic (ISO 8859-5)", encoding = "iso88595" },
  { title = "Cyrillic (KOI8-R)", encoding = "koi8r" },
  { title = "Cyrillic (KOI8-U)", encoding = "koi8u" },
  { title = "Estonian (ISO 8859-13)", encoding = "iso885913" },
  { title = "Greek (Windows 1253)", encoding = "windows1253" },
  { title = "Greek (ISO 8859-7)", encoding = "iso88597" },
  { title = "Hebrew (Windows 1255)", encoding = "windows1255" },
  { title = "Hebrew (ISO 8859-8)", encoding = "iso88598" },
  { title = "Nordic (ISO 8859-10)", encoding = "iso885910" },
  { title = "Romanian (ISO 8859-16)", encoding = "iso885916" },
  { title = "Turkish (Windows 1254)", encoding = "windows1254" },
  { title = "Turkish (ISO 8859-9)", encoding = "iso88599" },
  { title = "Vietnamese (Windows 1258)", encoding = "windows1258" },
  { title = "Simplified Chinese (GBK)", encoding = "gbk" },
  { title = "Simplified Chinese (GB18030)", encoding = "gb18030" },
  { title = "Traditional Chinese (Big5)", encoding = "cp950" },
  { title = "Traditional Chinese (Big5-HKSCS)", encoding = "big5hkscs" },
  { title = "Japanese (Shift JIS)", encoding = "shiftjis" },
  { title = "Japanese (EUC-JP)", encoding = "eucjp" },
  { title = "Korean (EUC-KR)", encoding = "euckr" },
  { title = "Thai (Windows 874)", encoding = "windows874" },
  { title = "Latin/Thai (ISO 8859-11)", encoding = "iso885911" },
  { title = "Cyrillic (KOI8-RU)", encoding = "koi8ru" },
  { title = "Tajik (KOI8-T)", encoding = "koi8t" },
  { title = "Simplified Chinese (GB 2312)", encoding = "gb2312" },
  { title = "Nordic DOS (CP 865)", encoding = "cp865" },
  { title = "Western European DOS (CP 850)", encoding = "cp850" },
}

local items = {} ---@type eve.ux.fn.select_encoding.IItem[]
for _, fileencoding in ipairs(fileencodings) do
  local text = string.format("%s     %s", eve.string.pad_end(fileencoding.title, 40, " "), fileencoding.encoding) ---@type string

  ---@type eve.ux.fn.select_encoding.IItem
  local item = {
    uuid = fileencoding.encoding,
    text = text,
    text_lower = text:lower(),
    data = fileencoding,
  }
  table.insert(items, item)
end

---@param item                          eve.ux.fn.select_encoding.IItem
---@param match                         eve.ux.select.IMatchedItem
---@return string
---@return eve.t.IHighlightInline[]
local function render_item(item, match)
  local highlights = {} ---@type eve.t.IHighlightInline[]
  for _, piece in ipairs(match.matches) do
    local highlight = { coll = piece.l, colr = piece.r, hlname = "f_us_main_match" } ---@type eve.t.IHighlightInline[]
    table.insert(highlights, highlight)
  end
  return item.text, highlights
end

---@param params                        eve.ux.fn.select_encoding.IParams
---@return eve.ux.ISelect
local function select_encoding(params)
  local present = params.present ---@type string|nil
  local title = params.title or "Select encoding" ---@type string
  local on_select = params.on_select ---@type fun(encoding: string|nil): nil

  ---@type eve.ux.select.IProvider
  local provider = {
    fetch_data = function()
      local data = { items = items, uuid_present = present } ---@type eve.ux.select.IData
      return data
    end,
    render_item = render_item,
  }

  local settled = false ---@type boolean

  ---@type eve.ux.ISelect
  local select = eve.ux.Select.new({
    dimension = {
      width = 80,
      height = math.max(math.floor(vim.o.lines * 0.8), #fileencodings),
      row = 3,
    },
    extend_preset_keymaps = true,
    flag_fuzzy = eve.std.Observable.from_value(true),
    flag_regex = eve.std.Observable.from_value(false),
    multiple = false,
    permanent = false,
    preview_enabled = false,
    preview_wrap = false,
    provider = provider,
    title = title,
    on_close = function()
      if not settled then
        settled = true
        on_select(nil)
      end
    end,
    on_confirm = function(widget, selected_items)
      ---@cast selected_items eve.ux.fn.select_encoding.IItem[]

      settled = true

      if #selected_items == 1 then
        local item = selected_items[1] ---@type eve.ux.fn.select_encoding.IItem
        on_select(item.data.encoding)
      else
        on_select(nil)
      end

      widget:close()
    end,
  })

  select:show()
  return select
end

return select_encoding
