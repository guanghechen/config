---@class eve.std.nvim
local M = {}

---@param name                          string
---@return integer
function M.augroup(name)
  return vim.api.nvim_create_augroup("eve_" .. name, { clear = true })
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

---@param bufnr                         integer
---@return boolean
function M.is_buf_valid(bufnr)
  return bufnr > 0 and vim.api.nvim_buf_is_valid(bufnr)
end

---@param tabnr                         integer
---@return boolean
function M.is_tab_valid(tabnr)
  return tabnr > 0 and vim.api.nvim_tabpage_is_valid(tabnr)
end

---@param winnr                         integer
---@return boolean
function M.is_win_floating(winnr)
  local config = vim.api.nvim_win_get_config(winnr) ---@type vim.api.keyset.win_config
  return config.relative ~= nil and config.relative ~= ""
end

---@param winnr                         integer
---@return boolean
function M.is_win_valid(winnr)
  return winnr > 0 and vim.api.nvim_win_is_valid(winnr)
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
---@param definition                    eve.command.IDefinition|eve.command.IDefinitionWithCandidates
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

return M