local bufnr = vim.api.nvim_get_current_buf()
local K = era.command.definitions

vim.keymap.set("n", "K", function()
  era.command.execute(K.log.preview_json_normal.uuid, nil, true)
end, {
  buffer = bufnr,
  desc = "log: Preview JSON from current line",
  noremap = true,
  silent = true,
})

vim.keymap.set("v", "K", function()
  era.command.execute(K.log.preview_json_visual.uuid, nil, true)
end, {
  buffer = bufnr,
  desc = "log: Preview JSON from selection",
  noremap = true,
  silent = true,
})
