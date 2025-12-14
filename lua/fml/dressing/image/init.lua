if ark.env.IS_WIN then
  return
end

local state = require("fml.dressing.image.state")
if not state.is_support_terminal() then
  return
end

if state.did_setup then
  return
end
state.did_setup = true

local group = ark.nvim.augroup("fml.dressing.image")
vim.api.nvim_create_autocmd({ "BufWipeout", "BufDelete" }, {
  group = group,
  callback = function(e)
    vim.schedule(function()
      local Placement = require("fml.dressing.image.placement")
      Placement.clean(e.buf)
    end)
  end,
})
vim.api.nvim_create_autocmd({ "ExitPre" }, {
  group = group,
  once = true,
  callback = function()
    local Placement = require("fml.dressing.image.placement")
    Placement.clean()
  end,
})
vim.api.nvim_create_autocmd("BufReadCmd", {
  pattern = "*" .. table.concat(state.data.extnames, ",*"),
  group = group,
  callback = function(e)
    local bufnr = e.buf
    local filename = vim.api.nvim_buf_get_name(bufnr)
    if not state.is_support_file(filename) then
      local lines = {
        "# Image viewer",
        "- **file**: `" .. filename .. "`",
        "- unsupported image format",
      }
      vim.bo[bufnr].modifiable = true
      vim.bo[bufnr].filetype = "markdown"
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
      vim.bo[bufnr].modifiable = false
      vim.bo[bufnr].modified = false
    else
      local Placement = require("fml.dressing.image.placement")
      vim.bo[bufnr].filetype = "image"
      vim.bo[bufnr].modifiable = false
      vim.bo[bufnr].modified = false
      vim.bo[bufnr].swapfile = false
      Placement.new(bufnr, filename, { conceal = true, auto_resize = true })
    end
  end,
})
vim.api.nvim_create_autocmd("BufWriteCmd", {
  pattern = "*" .. table.concat(state.data.extnames, ",*"),
  group = group,
  callback = function(e)
    vim.bo[e.buf].modified = false
  end,
})

if state.data.doc.enabled then
  local queries = vim.api.nvim_get_runtime_file("queries/*/images.scm", true)
  local supported_langs = vim.tbl_map(function(q)
    return q:match("queries/(.-)/images%.scm")
  end, queries)

  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    callback = function(e)
      local filetype = vim.bo[e.buf].filetype
      local lang = vim.treesitter.language.get_lang(filetype)
      if vim.tbl_contains(supported_langs, lang) then
        vim.schedule(function()
          if vim.api.nvim_buf_is_valid(e.buf) then
            require("fml.dressing.image.doc").attach(e.buf)
          end
        end)
      end
    end,
  })
end
