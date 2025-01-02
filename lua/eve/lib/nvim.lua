local constant = require("eve.lib.constant")
local BUF_UNTITLED = constant.BUF_UNTITLED ---@type string

---@class eve.lib.nvim
local M = {}

---@param name                          string
---@return integer
function M.augroup(name)
  return vim.api.nvim_create_augroup("eve_" .. name, { clear = true })
end

---@param keymaps                       eve.t.IKeymap[]
---@param keymap_override               eve.t.IKeymapOverridable
function M.bindkeys(keymaps, keymap_override)
  for _, keymap in ipairs(keymaps) do
    if keymap.active ~= false then
      local bufnr = keymap_override.bufnr or keymap.bufnr ---@type integer|nil
      local nowait = keymap_override.nowait or keymap.nowait ---@type boolean|nil
      local noremap = keymap_override.noremap or keymap.noremap ---@type boolean|nil
      local silent = keymap_override.silent or keymap.silent ---@type boolean|nil

      vim.keymap.set(keymap.modes, keymap.key, keymap.callback, {
        buffer = bufnr,
        nowait = nowait,
        noremap = noremap,
        silent = silent,
        desc = keymap.desc,
      })
    end
  end
end

---@param fg_hlname                     string
---@param bg_hlname                     string
---@return string
function M.blend_color(fg_hlname, bg_hlname)
  if type(fg_hlname) == "string" and type(bg_hlname) == "string" then
    local fg = vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID(fg_hlname)), "fg#")
    local bg = vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID(bg_hlname)), "bg#")
    local new_hlname = fg_hlname .. "__" .. bg_hlname

    ---! set_hl could stuff the CursorHold trigger, so it should be executed with defer.
    vim.defer_fn(function()
      vim.api.nvim_set_hl(0, new_hlname, { fg = fg, bg = bg })
    end, 10)
    return new_hlname
  end
  return "Error"
end

---@param filename                      string
---@return string
---@return string
function M.calc_fileicon(filename)
  local name = (not filename or filename == "") and BUF_UNTITLED or filename
  local icons_present, icons = pcall(require, "mini.icons")
  if icons_present and name ~= BUF_UNTITLED then
    local icon, icon_hl, is_default = icons.get("file", filename)
    if not is_default then
      return icon, icon_hl
    end
  end
  return "󰈚", "MiniIconsRed"
end

---@param tabnr                         integer
---@return eve.e.state.tab.meta.TabType
function M.calc_tabtype(tabnr)
  local winnrs = vim.api.nvim_tabpage_list_wins(tabnr) ---@type integer[]

  ---! Check if the diffview tab
  for _, winnr in ipairs(winnrs) do
    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    local filetype = vim.bo[bufnr].filetype ---@type string
    if filetype == constant.FT_DIFFVIEW_FILES or filetype == constant.FT_DIFFVIEW_FILE_HISTORY then
      return constant.TT_DIFFVIEW
    end
  end

  return constant.TT_NORMAL ---@type string
end

---@param winnr                         integer|nil
---@param width                         integer|nil
---@return nil
function M.dressing_float_win(winnr, width)
  if winnr == nil or winnr < 1 or not vim.api.nvim_win_is_valid(winnr) then
    return
  end

  width = width or 100

  local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false) ---@type string[]
  local wrap_count = 0 ---@type integer
  for _, line in ipairs(lines) do
    wrap_count = wrap_count + math.ceil(#line / width)
  end

  local state = require("eve.state")
  local winblend = state.theme.transparency:snapshot() and 0 or 10 ---@type integer

  vim.wo[winnr].number = false
  vim.wo[winnr].relativenumber = false
  vim.wo[winnr].signcolumn = "yes"
  vim.wo[winnr].winblend = winblend
  vim.wo[winnr].wrap = true
  vim.api.nvim_win_set_width(winnr, width)
  vim.api.nvim_win_set_height(winnr, math.min(40, math.max(2, wrap_count)))
  vim.api.nvim_set_current_win(winnr)
end

---@return table<string, integer>
function M.gen_filepath2bufnr()
  local bufnrs = vim.api.nvim_list_bufs() ---@type integer[]
  local filepath2bufnr = {} ---@type table<string, integer>

  for _, bufnr in ipairs(bufnrs) do
    local filepath = vim.api.nvim_buf_get_name(bufnr)
    if filepath ~= nil and #filepath > 0 then
      filepath2bufnr[filepath] = bufnr
    end
  end
  return filepath2bufnr
end

---@return string
function M.get_selected_text()
  local saved_reg = vim.fn.getreg("v")
  vim.cmd([[noautocmd sil norm! "vy]])

  local selected_text = vim.fn.getreg("v")
  vim.fn.setreg("v", saved_reg)
  return selected_text or ""
end

---@param filepath                      string
---@return nil
function M.load_nvim_session(filepath)
  if vim.fn.filereadable(filepath) ~= 0 then
    vim.cmd("silent! source " .. vim.fn.fnameescape(filepath))
  end
end

---@param hlname                        string
---@return string
function M.make_bg_transparency(hlname)
  local fg = vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID(hlname)), "fg#")
  local new_hlname = "_t_" .. hlname
  vim.schedule(function()
    vim.api.nvim_set_hl(0, new_hlname, { fg = fg, bg = "none" })
  end)
  return new_hlname
end

---@param filepath                      string
---@return nil
function M.save_nvim_session(filepath)
  vim.fn.mkdir(vim.fn.fnamemodify(filepath, ":p:h"), "p")
  local tmp = vim.o.sessionoptions
  vim.o.sessionoptions = constant.SESSION_SAVE_OPTION
  vim.cmd("mks! " .. vim.fn.fnameescape(filepath))
  vim.o.sessionoptions = tmp
end

return M
