local uuids = eve.commander.uuids ---@type eve.builtin.commander.uuids

eve.commander.register({
  uuid = uuids.buf_new,
  desc = "buf: new",
  action = function()
    local winnr = vim.api.nvim_get_current_win() ---@type integer
    local bufnr = vim.api.nvim_create_buf(true, true) ---@type integer

    vim.bo[bufnr].buflisted = true
    vim.bo[bufnr].buftype = ""
    vim.bo[bufnr].filetype = "text"
    vim.bo[bufnr].readonly = false
    vim.bo[bufnr].modifiable = true

    local cwd = eve.path.cwd() ---@type string
    local filepath = eve.buf.pick_filepath(cwd) ---@type string|nil
    if filepath ~= nil then
      vim.api.nvim_buf_set_name(bufnr, filepath)
    end

    vim.api.nvim_win_set_buf(winnr, bufnr)
  end,
})
