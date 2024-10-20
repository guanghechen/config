local constants = require("eve.std.constants")
local BUF_UNTITLED = constants.BUF_UNTITLED ---@type string

---@class eve.std.nvim
local M = {}

---@param name                          string
---@return integer
function M.augroup(name)
  return vim.api.nvim_create_augroup("eve_" .. name, { clear = true })
end

---@param keymaps                       t.eve.IKeymap[]
---@param keymap_override               t.eve.IKeymapOverridable
function M.bindkeys(keymaps, keymap_override)
  for _, keymap in ipairs(keymaps) do
    local bufnr = keymap_override.bufnr ---@type integer|nil
    local nowait = keymap_override.nowait ---@type boolean|nil
    local noremap = keymap_override.noremap ---@type boolean|nil
    local silent = keymap_override.silent ---@type boolean|nil

    if bufnr == nil then
      bufnr = keymap.bufnr
    end

    if nowait == nil then
      nowait = keymap.nowait
    end

    if noremap == nil then
      noremap = keymap.noremap
    end

    if silent == nil then
      silent = keymap.silent
    end

    vim.keymap.set(keymap.modes, keymap.key, keymap.callback, {
      buffer = bufnr,
      nowait = nowait,
      noremap = noremap,
      silent = silent,
    })
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

    ---! set_hl could stuf the CursorHold trigger, so it should be executed with defer.
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
  vim.o.sessionoptions = constants.SESSION_SAVE_OPTION
  vim.cmd("mks! " .. vim.fn.fnameescape(filepath))
  vim.o.sessionoptions = tmp
end

return M
