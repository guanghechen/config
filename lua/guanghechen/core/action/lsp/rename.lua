-- https://gist.github.com/MunifTanjim/8d9498c096719bdf4234321230fe3dc7?permalink_comment_id=3904930#gistcomment-3904930

local function rename()
  vim.lsp.buf.rename()
  vim.schedule(function()
    vim.cmd("stopinsert")
  end)
end

return rename
