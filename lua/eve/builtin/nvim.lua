local BLOCKING_MODES = { "ic", "ix", "c", "no", "r%?", "rm" } ---@type string[]

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

---@class eve.builtin.nvim
local M = {}

---@param name                          string
---@return integer
function M.augroup(name)
  return vim.api.nvim_create_augroup("eve_" .. name, { clear = true })
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

---@param fg_hlname                     string
---@param bg_hlname                     string
---@return string
function M.blend_color(fg_hlname, bg_hlname)
  if type(fg_hlname) == "string" and type(bg_hlname) == "string" then
    local fg = vim.api.nvim_get_hl(0, { name = fg_hlname }).fg
    local bg = vim.api.nvim_get_hl(0, { name = bg_hlname }).bg
    local new_hlname = fg_hlname .. "__" .. bg_hlname

    ---! set_hl could stuff the CursorHold trigger, so it should be executed with defer.
    vim.defer_fn(function()
      vim.api.nvim_set_hl(0, new_hlname, { fg = fg, bg = bg })
    end, 10)
    return new_hlname
  end
  return "Error"
end

---@param keymaps                       eve.t.IKeymap[]
---@param keymap_override               eve.t.IKeymapOverridable
function M.bindkeys(keymaps, keymap_override)
  for _, keymap in ipairs(keymaps) do
    if not keymap.disabled then
      local bufnr = keymap_override.bufnr or keymap.bufnr ---@type integer|nil
      local nowait = keymap_override.nowait or keymap.nowait ---@type boolean|nil
      local noremap = keymap_override.noremap or keymap.noremap ---@type boolean|nil
      local silent = keymap_override.silent or keymap.silent ---@type boolean|nil

      ---@type vim.keymap.set.Opts
      local opts = {
        buffer = bufnr,
        nowait = nowait,
        noremap = noremap,
        silent = silent,
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

---@return nil
function M.create_undo()
  local mode = vim.api.nvim_get_mode().mode ---@type string
  if mode == "i" then
    vim.api.nvim_feedkeys(eve.setting.feedkeys.UNDO, "n", false)
  end
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
function M.is_blocking()
  local mode = vim.api.nvim_get_mode()
  if mode.blocking then
    return true
  end

  for _, m in ipairs(BLOCKING_MODES) do
    if mode.mode:find(m) == 1 then
      return true
    end
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

---@param modes                         string[]
---@param keys                          string|string[]
---@param definition                    eve.builtin.command.IDefinition|eve.builtin.command.IDefinitionWithCandidates
---@return nil
function M.make_shortcut(modes, keys, definition)
  ---@return nil
  local function callback()
    vim.cmd(definition.uuid)
  end

  ---@type vim.keymap.set.Opts
  local opts = {
    noremap = true,
    silent = true,
    nowait = true,
    desc = definition.desc,
  }

  if type(keys) == "string" then
    vim.keymap.set(modes, keys, callback, opts)
  else
    for _, key in ipairs(keys) do
      vim.keymap.set(modes, key, callback, opts)
    end
  end
end

---@param hlgroups                      string[]
---@param field                         "fg"|"bg"|"sp"
---@return string|nil
function M.pick_color(hlgroups, field)
  for _, hlgroup in ipairs(hlgroups) do
    local hl = vim.api.nvim_get_hl(0, { name = hlgroup, link = false })
    if hl[field] then
      return string.format("#%06x", hl[field])
    end
  end
  return nil
end

return M
