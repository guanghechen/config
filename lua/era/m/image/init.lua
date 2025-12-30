---@class era.m.image.__mods
local __mods = {
  Convert = "era.m.image.convert",
  doc = "era.m.image.doc",
  Image = "era.m.image.image",
  inline = "era.m.image.inline",
  Placement = "era.m.image.placement",
  state = "era.m.image.state",
  terminal = "era.m.image.terminal",
}

---@class era.m.image
---@field public __mods                 era.m.image.__mods
---@field public Convert                era.m.image.Convert
---@field public dressing               fun(): nil
---@field public doc                    era.m.image.doc
---@field public Image                  era.m.image.Image
---@field public inline                 era.m.image.inline
---@field public Placement              era.m.image.Placement
---@field public state                  era.m.image.state
---@field public terminal               era.m.image.terminal
local M = setmetatable({
  __mods = __mods,
}, {
  __index = function(t, k)
    local m = __mods[k] ---@type string|nil
    if m == nil then
      return rawget(t, k)
    end
    return require(m)
  end,
})

---@return nil
function M.dressing()
  if stl.env.IS_WIN then
    return
  end

  local state = require("era.m.image.state")
  if not state.is_support_terminal() then
    return
  end

  if state.did_setup then
    return
  end
  state.did_setup = true

  local group = stl.nvim.fn.augroup("era.image_dressing")
  vim.api.nvim_create_autocmd({ "BufWipeout", "BufDelete" }, {
    group = group,
    callback = function(e)
      vim.schedule(function()
        local Placement = require("era.m.image.placement")
        Placement.clean(e.buf)
      end)
    end,
  })
  vim.api.nvim_create_autocmd({ "ExitPre" }, {
    group = group,
    once = true,
    callback = function()
      local Placement = require("era.m.image.placement")
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
        local Placement = require("era.m.image.placement")
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
              require("era.m.image.doc").attach(e.buf)
            end
          end)
        end
      end,
    })
  end
end

return M
