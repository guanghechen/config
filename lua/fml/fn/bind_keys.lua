---@param keymaps                       fml.types.ui.IKeymap[]
---@param keymap_override               fml.types.ui.IKeymapOverridable
local function bind_keys(keymaps, keymap_override)
  for _, keymap in ipairs(keymaps) do
    vim.keymap.set(keymap.modes, keymap.key, keymap.callback, {
      buffer = keymap_override.bufnr or keymap.bufnr,
      nowait = keymap_override.nowait or keymap.nowait,
      noremap = keymap_override.noremap or keymap.noremap,
      silent = keymap_override.silent or keymap.silent,
    })
  end
end

return bind_keys
