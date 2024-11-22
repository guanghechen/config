vim.api.nvim_create_autocmd("FileType", {
  pattern = {
    eve.constants.FT_AERIAL,
    eve.constants.FT_NEOTREE,
    eve.constants.FT_SEARCH_INPUT,
    eve.constants.FT_SEARCH_MAIN,
    eve.constants.FT_SEARCH_PREVIEW,
    eve.constants.FT_TERM,
  },
  callback = function()
    local ok, cmp = pcall(require, "cmp")
    if ok then
      cmp.setup.buffer({ enabled = false })
    end
  end,
})
