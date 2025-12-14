---@param num                           integer
---@return string
local function encode_int(num)
  local text = string.format("%o", num) ---@type string
  return text
end

---@param text                          string
---@return integer|nil
local function decode_int(text)
  local num = tonumber(text, 8) ---@type integer|nil
  return num
end

---@class ark.nvim
local M = {}

---@param name                          string
---@return integer
function M.augroup(name)
  return vim.api.nvim_create_augroup("guanghechen_" .. name, { clear = true })
end

---@param text                          string
---@param callback                      string
---@param args                          ?integer|integer[]
function M.btn(text, callback, args)
  local args_str = args or "" ---@type integer|integer[]|string
  if type(args) == "table" then
    args_str = M.encode_btn_args(args)
  end
  return "%" .. args_str .. "@v:lua." .. callback .. "@" .. text .. "%T"
end

---@param text                          string
---@param hlname                        string
---@return string
function M.txt(text, hlname)
  return "%#" .. hlname .. "#" .. text:gsub("%%", "%%%%")
end

---@param args                          integer[]
---@return string
function M.encode_btn_args(args)
  local result = "" ---@type string
  for i, num in ipairs(args) do
    if i > 1 then
      result = result .. "9"
    end
    result = result .. encode_int(num)
  end
  return result
end

---@param text                          string
---@return integer[]
function M.decode_btn_args(text)
  local argv = vim.split(text, "9", { plain = true }) ---@type string[]
  local result = {} ---@type integer[]
  for _, arg in ipairs(argv) do
    local num = decode_int(arg)
    if num ~= nil then
      table.insert(result, num)
    end
  end
  return result
end

---@param keymaps                       ark.t.IKeymap[]
---@param keymap_override               ark.t.IKeymapOverridable
function M.bindkeys(keymaps, keymap_override)
  for _, keymap in ipairs(keymaps) do
    if not keymap.disabled then
      local bufnr = keymap_override.bufnr or keymap.bufnr ---@type integer|nil
      local nowait = keymap_override.nowait or keymap.nowait ---@type boolean|nil
      local noremap = keymap_override.noremap or keymap.noremap ---@type boolean|nil
      local silent = keymap_override.silent or keymap.silent ---@type boolean|nil
      local expr = keymap_override.expr or keymap.expr ---@type boolean|nil
      local replace_keycodes = keymap_override.replace_keycodes or keymap.replace_keycodes ---@type boolean|nil

      ---@type vim.keymap.set.Opts
      local opts = {
        buffer = bufnr,
        nowait = nowait,
        noremap = noremap,
        silent = silent,
        expr = expr,
        replace_keycodes = replace_keycodes,
        desc = keymap.desc,
      }
      vim.keymap.set(keymap.modes, keymap.key, keymap.callback, opts)

      if keymap.aliases ~= nil then
        for _, alias in ipairs(keymap.aliases) do
          vim.keymap.set(keymap.modes, alias, keymap.callback, opts)
        end
      end
    end
  end
end

---@param content                       string
---@return nil
function M.copy(content)
  vim.fn.setreg('"', content)
  vim.fn.setreg("+", content)
end

---@return table<string, integer>
function M.filepath2bufnr()
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

---@return boolean
function M.is_statusline_visible()
  local laststatus = vim.o.laststatus ---@type integer
  if laststatus >= 2 then
    return true
  end
  if laststatus == 1 then
    local tabpage = vim.api.nvim_get_current_tabpage()
    local wins = vim.api.nvim_tabpage_list_wins(tabpage) ---@type integer[]
    return #wins > 1
  end
  return false
end

---@return boolean
function M.is_tabline_visible()
  local showtabline = vim.o.showtabline ---@type integer
  if showtabline == 2 then
    return true
  end
  if showtabline == 1 then
    local tab_count = vim.fn.tabpagenr("$") ---@type integer
    return tab_count > 1
  end
  return false
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

---@param modes                         string[]
---@param keys                          string|string[]
---@param cmd                           string|fun(): string|nil
---@param desc                          ?string
---@param expr                          ?boolean
---@return nil
function M.make_keys(modes, keys, cmd, desc, expr)
  ---@type vim.keymap.set.Opts
  local opts = {
    noremap = true,
    silent = true,
    nowait = true,
    desc = desc,
    expr = expr,
  }

  if type(keys) == "string" then
    vim.keymap.set(modes, keys, cmd, opts)
  else
    for _, key in ipairs(keys) do
      vim.keymap.set(modes, key, cmd, opts)
    end
  end
end

return M
