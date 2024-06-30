local last_bufnr_cur = 1 ---@type integer

---@class ghc.ui.tabline.component.IBufItem
---@field public bufnr                  integer
---@field public filepath               string
---@field public filename               string

local function build_buf_items()
  local bufs = {} ---@type ghc.ui.tabline.component.IBufItem[]

  for _, bufnr in ipairs(vim.t.bufs) do
    local filepath = vim.api.nvim_buf_get_name(bufnr)
    local filename = fml.path.basename(filepath)
    table.insert(bufs, { bufnr = bufnr, filepath = filepath, filename = filename })
  end

  return bufs
end

---@param buf                           ghc.ui.tabline.component.IBufItem
---@param bufid                         integer
---@param is_curbuf                     boolean
---@return string, integer
local function render_buf(buf, bufid, is_curbuf)
  local is_mod            = vim.api.nvim_get_option_value("mod", { buf = buf.bufnr }) ---@type boolean
  local filename          = (not buf.filename or buf.filename == "") and " No Name " or buf.filename
  local icon, fileicon_hl = fml.fn.calc_fileicon(filename)

  local left_pad          = " " ---@type string
  local text_icon         = icon .. " " ---@type string
  local text_title        = " " .. filename ---@type string
  local text_mod          = is_mod and "  " or "  " ---@type string

  local buf_hl            = is_curbuf and "f_tl_buf_item_cur" or "f_tl_buf_item" ---@type string
  local icon_hl           = fml.highlight.blend_color(fileicon_hl, buf_hl)
  local title_hl          = is_curbuf and "f_tl_buf_title_cur" or "f_tl_buf_title" ---@type string
  local mod_hl            = is_curbuf and "f_tl_buf_mod_cur" or "f_tl_buf_mod" ---@type string

  local hl_text_left_pad  = fml.nvimbar.txt(left_pad, title_hl)
  local hl_text_icon      = fml.nvimbar.txt(text_icon, icon_hl)
  local hl_text_title     = fml.nvimbar.txt(text_title, title_hl)
  local hl_text_mod       = is_mod and fml.nvimbar.txt(text_mod, mod_hl) or text_mod

  local hl_text           = hl_text_left_pad .. hl_text_icon .. hl_text_title .. hl_text_mod
  local width             = vim.fn.strwidth(hl_text_left_pad .. text_icon .. text_title .. text_mod) ---@type integer
  return fml.nvimbar.btn(hl_text, "fml.api.buf.goto_buf" .. bufid, buf_hl), width
end

--- @type fml.types.ui.nvimbar.IRawComponent
local M = {
  name = "bufs",
  render = function(context, remain_width)
    local bufs = build_buf_items()
    local bufnr_cur = vim.api.nvim_get_current_buf() ---@type integer

    ---@type integer|nil
    local bufid_cur = fml.table.find(bufs, function(item)
      return item.bufnr == bufnr_cur
    end)

    if bufid_cur ~= nil then
      last_bufnr_cur = bufnr_cur
    else
      bufid_cur = fml.table.find(bufs, function(item)
        return item.bufnr == last_bufnr_cur
      end) or 1
    end

    local text, width = render_buf(bufs[bufid_cur], bufid_cur, true)

    remain_width = remain_width - width
    for i = bufid_cur - 1, 1, -1 do
      local t, w = render_buf(bufs[i], i, false)
      remain_width = remain_width - w
      if remain_width >= 0 then
        text = t .. text
      end
    end
    for i = bufid_cur + 1, #bufs, 1 do
      local t, w = render_buf(bufs[i], i, false)
      remain_width = remain_width - w
      if remain_width >= 0 then
        text = text .. t
      end
    end
    return text, width
  end,
}

return M
