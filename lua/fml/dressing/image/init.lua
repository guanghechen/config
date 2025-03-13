--- https://github.com/folke/snacks.nvim/blob/70e7e081ee558eb3756aba02491f1bc84fb72ab0/lua/snacks/image/init.lua

local config = require("fml.dressing.image.config")

---@class fml.dressing.image
local M = {}

---@alias fml.dressing.image.Loc fml.dressing.image.Pos|fml.dressing.image.Size|{zindex?: number}
---@alias fml.dressing.image.Pos {[1]: number, [2]: number}
---@alias fml.dressing.image.Size {width: number, height: number}
---@alias fml.dressing.image.Type "image"|"math"|"chart"

---@class fml.dressing.image.Env
---@field name string
---@field env table<string, string|true>
---@field supported? boolean default: false
---@field placeholders? boolean default: false
---@field setup? fun(): boolean?
---@field transform? fun(data: string): string
---@field detected? boolean
---@field remote? boolean this is a remote client, so full transfer of the image data is required

vim.api.nvim_set_hl(0, "SnacksImageAnchor", { default = true, link = "Special" })
vim.api.nvim_set_hl(0, "SnacksImageSpecial", { default = true, link = "Special" })
vim.api.nvim_set_hl(0, "SnacksImageLoading", { default = true, link = "NonText" })
vim.api.nvim_set_hl(0, "SnacksImageMath", {
  default = true,
  fg = eve.std.vim.pick_color({ "@markup.math.latex", "Special", "Normal" }, "fg"),
})

---@class fml.dressing.image.Opts
---@field public pos                    ?fml.dressing.image.Pos (row, col) (1,0)-indexed. defaults to the top-left corner
---@field public auto_resize            ?boolean
---@field public conceal                ?boolean
---@field public inline                 ?boolean render the image inline in the buffer
---@field public range                  ?Range4
---@field public width                  ?number
---@field public min_width              ?number
---@field public max_width              ?number
---@field public height                 ?number
---@field public min_height             ?number
---@field public max_height             ?number
---@field public type                   ?fml.dressing.image.Type
---@field public on_update              ?fun(placement: fml.dressing.image.Placement)
---@field public on_update_pre          ?fun(placement: fml.dressing.image.Placement)

local did_setup = false

--- Show the image at the cursor in a floating window
function M.hover()
  local image_doc = require("fml.dressing.image.doc")
  image_doc.hover()
end

---@return string[]
function M.langs()
  local queries = vim.api.nvim_get_runtime_file("queries/*/images.scm", true)
  return vim.tbl_map(function(q)
    return q:match("queries/(.-)/images%.scm")
  end, queries)
end

---@param bufnr                         integer|nil
---@return nil
function M.setup(bufnr)
  if did_setup then
    return
  end
  did_setup = true

  local Placement = require("fml.dressing.image.placement")

  local group = eve.std.nvim.augroup("fml.dressing.image")
  vim.api.nvim_create_autocmd({ "BufWipeout", "BufDelete" }, {
    group = group,
    callback = function(e)
      vim.schedule(function()
        Placement.clean(e.buf)
      end)
    end,
  })
  vim.api.nvim_create_autocmd({ "ExitPre" }, {
    group = group,
    once = true,
    callback = function()
      Placement.clean()
    end,
  })
  vim.api.nvim_create_autocmd("BufReadCmd", {
    pattern = "*" .. table.concat(config.state.extnames, ",*"),
    group = group,
    callback = function(e)
      local image_buf = require("fml.dressing.image.buf")
      image_buf.attach(e.buf)
    end,
  })
  -- prevent altering the original image file
  vim.api.nvim_create_autocmd("BufWriteCmd", {
    pattern = "*" .. table.concat(config.state.extnames, ",*"),
    group = group,
    callback = function(e)
      vim.bo[e.buf].modified = false
    end,
  })

  if config.state.doc.enabled then
    local langs = M.langs()
    vim.api.nvim_create_autocmd("FileType", {
      group = group,
      callback = function(e)
        local filetype = vim.bo[e.buf].filetype
        local lang = vim.treesitter.language.get_lang(filetype)
        if vim.tbl_contains(langs, lang) then
          vim.schedule(function()
            if vim.api.nvim_buf_is_valid(e.buf) then
              local image_doc = require("fml.dressing.image.doc")
              image_doc.attach(e.buf)
            end
          end)
        end
      end,
    })
  end

  if bufnr ~= nil then
    local image_buf = require("fml.dressing.image.buf")
    image_buf.attach(bufnr)
  end
end

if config.is_support_terminal() then
  M.setup()
end

return M
