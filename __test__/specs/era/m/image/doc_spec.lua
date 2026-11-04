local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")

local t = harness.new()

bootstrap.with_native(t)
bootstrap.with_runtime(t, {
  dot = {
    path = {
      -- As `dot.path.normalize` does.
      normalize = function(path)
        return yoz.path.normalize(path, true, "/")
      end,
    },
  },
})

t:patch_table(package.loaded, "era.m.image.state", { data = { img_dirs = {} } })

---@param dir                           string
---@param lines                         string[]
---@return integer
local function markdown(dir, lines)
  local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  t:defer(function()
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)
  vim.api.nvim_buf_set_name(bufnr, dir .. "/doc.md")
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
  local dir = t:tempdir() ---@type string

  local bufnr = markdown(dir, { "![alt](a.png)", "", "![](b.png)", "", '![alt](c.png "title")' })

  t.assert_same({ dir .. "/a.png", dir .. "/b.png", dir .. "/c.png" }, sources(document, bufnr), "images")
  t.assert_eq(0, scans, "link definition scans")
end)

t:test("reference images resolve through the link definitions", function()
  local document = assert(loadfile("lua/era/m/image/doc.lua"))()
  local dir = t:tempdir() ---@type string
  local bufnr = markdown(dir, { "![full][logo]", "", "![logo][]", "", "![logo]", "", "[logo]: images/logo.png" })

  local logo = dir .. "/images/logo.png" ---@type string
  t.assert_same({ logo, logo, logo }, sources(document, bufnr), "images")
end)

t:test("a relative image is looked up next to the document before the working directory", function()
  local document = assert(loadfile("lua/era/m/image/doc.lua"))()
  local cwd = t:tempdir() ---@type string
  local dir = cwd .. "/docs" ---@type string
  vim.fn.mkdir(dir, "p")
  for _, file in ipairs({ cwd .. "/logo.png", dir .. "/logo.png", dir .. "/my image.png" }) do
    vim.fn.writefile({ "png" }, file)
  end
  local previous = assert(vim.uv.cwd()) ---@type string
  vim.api.nvim_set_current_dir(cwd)
  t:defer(function()
    vim.api.nvim_set_current_dir(previous)
  end)
  local bufnr = markdown(dir, {})

  t.assert_eq(dir .. "/logo.png", document.resolve(bufnr, "logo.png"), "the document's directory first")
  t.assert_eq(dir .. "/my image.png", document.resolve(bufnr, "my%20image.png"), "escaped destination")
  t.assert_eq(dir .. "/later.png", document.resolve(bufnr, "later.png"), "a file that does not exist yet")
  t.assert_eq(dir .. "/logo.png#page=2", document.resolve(bufnr, "logo.png#page=2"), "page of a document")
end)

t:test("URLs and data URIs are no files and pass through unchanged", function()
  local document = assert(loadfile("lua/era/m/image/doc.lua"))()
  local bufnr = markdown(t:tempdir(), {})
  -- Base64 data often holds `//` or `/./`, which normalizing a path would fold.
  local data = "data:image/png;base64,iVBORw0KGgo//AAAA//8AAA/./x" ---@type string
  local url = "https://img.shields.io/badge/a-b-green.svg" ---@type string

  t.assert_eq(data, document.resolve(bufnr, data), "data URI")
  t.assert_eq(url, document.resolve(bufnr, url), "URL")
end)

t:run()
