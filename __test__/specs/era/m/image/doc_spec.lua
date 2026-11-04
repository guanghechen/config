local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")

local t = harness.new()

bootstrap.with_runtime(t, {
  dot = {
    path = {
      normalize = function(path)
        return path
      end,
    },
  },
})

t:patch_table(package.loaded, "era.m.image.state", { data = { img_dirs = {} } })

---@param lines                         string[]
---@return integer
local function markdown(lines)
  local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  t:defer(function()
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_set_option_value("filetype", "markdown", { buf = bufnr })
  return bufnr
end

---@param document                      era.m.image.doc
---@param bufnr                         integer
---@return string[]
local function sources(document, bufnr)
  local found = {} ---@type era.m.image.match[]
  document.find(bufnr, function(imgs)
    found = imgs
  end)
  table.sort(found, function(a, b)
    return a.pos[1] < b.pos[1]
  end)
  return vim.tbl_map(function(img)
    return img.src
  end, found)
end

t:test("a document without reference images never scans its link definitions", function()
  local document = assert(loadfile("lua/era/m/image/doc.lua"))()
  local scans = 0 ---@type integer
  t:patch_table(document, "get_link_definitions", function()
    scans = scans + 1
    return {}
  end)

  local bufnr = markdown({ "![alt](a.png)", "", "![](b.png)", "", '![alt](c.png "title")' })

  t.assert_same({ "a.png", "b.png", "c.png" }, sources(document, bufnr), "images")
  t.assert_eq(0, scans, "link definition scans")
end)

t:test("reference images resolve through the link definitions", function()
  local document = assert(loadfile("lua/era/m/image/doc.lua"))()
  local bufnr = markdown({ "![full][logo]", "", "![logo][]", "", "![logo]", "", "[logo]: images/logo.png" })

  t.assert_same({ "images/logo.png", "images/logo.png", "images/logo.png" }, sources(document, bufnr), "images")
end)

t:run()
