---@param bufs                          integer[]
---@return integer[]
local function filter_listed_bufs(bufs)
  local listed_bufs = {} ---@type integer[]
  for _, val in ipairs(bufs) do
    if vim.bo[val].buflisted then
      table.insert(listed_bufs, val)
    end
  end
  return listed_bufs
end

-- store listed buffers in tab local var
vim.t.bufs = vim.t.bufs or vim.api.nvim_list_bufs()
vim.t.bufs = filter_listed_bufs(vim.t.bufs)

-- autocmds for tabufline -> store bufnrs on bufadd, bufenter events
-- thx to https://github.com/ii14 & stores buffer per tab -> table
vim.api.nvim_create_autocmd({ "BufAdd", "BufEnter", "tabnew" }, {
  callback = function(args)
    local bufs = vim.t.bufs
    local is_curbuf = vim.api.nvim_get_current_buf() == args.buf

    if bufs == nil then
      bufs = vim.api.nvim_get_current_buf() == args.buf and {} or { args.buf }
    else
      -- check for duplicates
      if
          not vim.tbl_contains(bufs, args.buf)
          and (args.event == "BufEnter" or not is_curbuf or vim.api.nvim_get_option_value("buflisted", { buf = args.buf }))
          and vim.api.nvim_buf_is_valid(args.buf)
          and vim.api.nvim_get_option_value("buflisted", { buf = args.buf })
      then
        table.insert(bufs, args.buf)
      end
    end

    -- remove unnamed buffer which isnt current buf & modified
    if args.event == "BufAdd" then
      if #vim.api.nvim_buf_get_name(bufs[1]) == 0 and not vim.api.nvim_get_option_value("modified", { buf = bufs[1] }) then
        table.remove(bufs, 1)
      end
    end

    vim.t.bufs = bufs

    -- used for knowing previous active buf for term module's runner func
    if args.event == "BufEnter" then
      local buf_history = vim.g.buf_history or {}
      table.insert(buf_history, args.buf)
      vim.g.buf_history = buf_history
    end
  end,
})

vim.api.nvim_create_autocmd("BufDelete", {
  callback = function(args)
    for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
      local bufs = vim.t[tab].bufs
      if bufs then
        for i, bufnr in ipairs(bufs) do
          if bufnr == args.buf then
            table.remove(bufs, i)
            vim.t[tab].bufs = bufs
            break
          end
        end
      end
    end
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = "qf",
  callback = function()
    vim.opt_local.buflisted = false
  end,
})
